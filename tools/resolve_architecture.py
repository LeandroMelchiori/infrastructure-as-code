#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

import yaml

from estimate_cost import estimate_monthly_cost

ROOT = Path(__file__).resolve().parents[1]


def load_yaml(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def load_catalog() -> dict:
    return load_yaml(ROOT / "catalog.yaml")


def load_profile(profile_id: str, catalog: dict) -> dict:
    profiles = catalog.get("constraint_profiles", {})
    ref = profiles.get(profile_id)
    if not ref:
        raise ValueError(f"Unknown constraint profile: {profile_id}")
    return load_yaml(ROOT / ref["path"])


def positive_number(name: str, value: float) -> None:
    if value <= 0:
        raise ValueError(f"{name} must be greater than zero")


def nonnegative_number(name: str, value: float) -> None:
    if value < 0:
        raise ValueError(f"{name} must be zero or greater")


def resolve(
    architecture_id: str,
    requested: list[str],
    *,
    profile_id: str | None = None,
    ocpus: float | None = None,
    memory_gb: float | None = None,
    boot_volume_gb: float | None = None,
    instances: int = 1,
    boot_vpus_per_gb: int | None = None,
    max_monthly_usd: float | None = None,
) -> dict:
    catalog = load_catalog()
    architectures = catalog.get("architectures", {})
    if architecture_id not in architectures:
        raise ValueError(f"Unknown architecture: {architecture_id}")

    architecture = architectures[architecture_id]
    compatible = set(architecture.get("compatible", []))
    capabilities = catalog.get("capabilities", {})

    resolved = []
    paths = {}
    for capability_id in requested:
        if capability_id not in capabilities:
            raise ValueError(f"Unknown capability: {capability_id}")
        if capability_id not in compatible:
            raise ValueError(
                f"Capability '{capability_id}' is not compatible with '{architecture_id}'"
            )
        if capability_id not in resolved:
            resolved.append(capability_id)
            paths[capability_id] = capabilities[capability_id]["path"]

    compute = architecture.get("compute", {})
    max_instances = compute.get("max_instances")
    if instances < 1:
        raise ValueError("instances must be at least 1")
    if max_instances is not None and instances > max_instances:
        raise ValueError(
            f"Architecture '{architecture_id}' supports at most {max_instances} instance(s)"
        )

    shape = compute.get("shape")
    selected_ocpus = ocpus if ocpus is not None else compute.get("default_ocpus")
    selected_memory = (
        memory_gb if memory_gb is not None else compute.get("default_memory_gb")
    )
    selected_boot = (
        boot_volume_gb
        if boot_volume_gb is not None
        else compute.get("default_boot_volume_gb")
    )

    positive_number("ocpus", selected_ocpus)
    positive_number("memory_gb", selected_memory)
    positive_number("boot_volume_gb", selected_boot)
    if max_monthly_usd is not None:
        nonnegative_number("max_monthly_usd", max_monthly_usd)

    warnings = []
    profile_summary = None

    if profile_id:
        if profile_id not in architecture.get("constraint_profiles", []):
            raise ValueError(
                f"Constraint profile '{profile_id}' is not supported by '{architecture_id}'"
            )

        profile = load_profile(profile_id, catalog)
        if profile.get("provider") != architecture.get("provider"):
            raise ValueError(
                f"Constraint profile '{profile_id}' does not match provider "
                f"'{architecture.get('provider')}'"
            )

        allowed_shapes = profile.get("compute", {}).get("allowed_shapes", {})
        shape_limits = allowed_shapes.get(shape)
        if not shape_limits:
            raise ValueError(
                f"Shape '{shape}' is not allowed by constraint profile '{profile_id}'"
            )

        if ocpus is None:
            selected_ocpus = shape_limits.get("default_ocpus", selected_ocpus)
        if memory_gb is None:
            selected_memory = shape_limits.get("default_memory_gb", selected_memory)
        if boot_volume_gb is None:
            selected_boot = profile.get("storage", {}).get(
                "default_boot_volume_gb", selected_boot
            )

        total_ocpus = selected_ocpus * instances
        total_memory = selected_memory * instances
        total_block = selected_boot * instances

        max_ocpus = shape_limits.get("max_total_ocpus")
        max_memory = shape_limits.get("max_total_memory_gb")
        min_boot = profile.get("storage", {}).get("min_boot_volume_gb_per_instance")
        max_block = profile.get("storage", {}).get("max_total_block_volume_gb")

        if max_ocpus is not None and total_ocpus > max_ocpus:
            raise ValueError(
                f"Requested {total_ocpus} total OCPU exceeds profile "
                f"'{profile_id}' limit of {max_ocpus}"
            )
        if max_memory is not None and total_memory > max_memory:
            raise ValueError(
                f"Requested {total_memory} GB total memory exceeds profile "
                f"'{profile_id}' limit of {max_memory} GB"
            )
        if min_boot is not None and selected_boot < min_boot:
            raise ValueError(
                f"Requested boot volume {selected_boot} GB is below profile "
                f"'{profile_id}' minimum of {min_boot} GB"
            )
        if max_block is not None and total_block > max_block:
            raise ValueError(
                f"Requested {total_block} GB total block storage exceeds profile "
                f"'{profile_id}' limit of {max_block} GB"
            )

        verification = profile.get("verification", {})
        if verification.get("account_entitlement_required"):
            warnings.append(
                "Always Free eligibility depends on the OCI account entitlement; "
                "verify it before apply"
            )
        if verification.get("home_region_required"):
            warnings.append(
                "Always Free compute must be provisioned in the tenancy home region"
            )
        if verification.get("capacity_not_guaranteed"):
            warnings.append(
                "A valid Always Free configuration does not guarantee regional host capacity"
            )

        profile_summary = {
            "id": profile_id,
            "last_reviewed": profile.get("last_reviewed"),
            "source_of_truth": profile.get("source_of_truth", []),
            "recheck_before_apply": verification.get("recheck_before_apply", True),
        }
    else:
        warnings.append(
            "No cost/entitlement profile selected; sizing is not guaranteed to be free"
        )

    if "application-storage" in resolved:
        warnings.append(
            "application-storage owns its bucket in a separate Terraform state; "
            "the Docker platform must only consume it as an external resource"
        )

    cost = estimate_monthly_cost(
        provider=architecture["provider"],
        shape=shape,
        ocpus=selected_ocpus,
        memory_gb=selected_memory,
        boot_volume_gb=selected_boot,
        instances=instances,
        boot_vpus_per_gb=boot_vpus_per_gb,
        profile_id=profile_id,
    )

    budget = None
    if max_monthly_usd is not None:
        estimated = cost["estimated_monthly_usd"]
        if estimated > max_monthly_usd:
            raise ValueError(
                f"Modeled monthly cost USD {estimated:.2f} exceeds budget "
                f"USD {max_monthly_usd:.2f}"
            )

        budget = {
            "max_monthly_usd": max_monthly_usd,
            "modeled_estimated_monthly_usd": estimated,
            "modeled_remaining_usd": round(max_monthly_usd - estimated, 4),
            "status": "within_modeled_scope",
        }

        excluded = cost.get("modeled_scope", {}).get("excluded", [])
        if excluded:
            warnings.append(
                "Budget validation covers modeled resources only; excluded services "
                "or usage can add cost"
            )

    input_names = compute.get("terraform_inputs", {})
    terraform_inputs = {
        input_names.get("shape", "shape"): shape,
        input_names.get("ocpus", "ocpus"): selected_ocpus,
        input_names.get("memory_gb", "memory_in_gbs"): selected_memory,
        input_names.get("boot_volume_gb", "boot_volume_size_in_gbs"): selected_boot,
    }

    return {
        "valid": True,
        "architecture": architecture_id,
        "provider": architecture["provider"],
        "reference_path": architecture["path"],
        "implementation_path": architecture.get("implementation"),
        "capabilities": resolved,
        "capability_paths": paths,
        "constraint_profile": profile_summary,
        "compute": {
            "shape": shape,
            "architecture": compute.get("architecture"),
            "instances": instances,
            "ocpus_per_instance": selected_ocpus,
            "memory_gb_per_instance": selected_memory,
            "boot_volume_gb_per_instance": selected_boot,
            "boot_vpus_per_gb": cost["boot_vpus_per_gb"],
        },
        "cost_estimate": cost,
        "budget": budget,
        "terraform_inputs": terraform_inputs,
        "warnings": warnings,
        "requires_human_approval": {
            "apply": True,
            "destroy": True,
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Resolve an IaC architecture composition")
    parser.add_argument("--architecture", required=True)
    parser.add_argument("--capability", action="append", default=[])
    parser.add_argument("--profile")
    parser.add_argument("--ocpus", type=float)
    parser.add_argument("--memory-gb", type=float)
    parser.add_argument("--boot-volume-gb", type=float)
    parser.add_argument("--boot-vpus-per-gb", type=int)
    parser.add_argument("--instances", type=int, default=1)
    parser.add_argument("--max-monthly-usd", type=float)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    try:
        result = resolve(
            args.architecture,
            args.capability,
            profile_id=args.profile,
            ocpus=args.ocpus,
            memory_gb=args.memory_gb,
            boot_volume_gb=args.boot_volume_gb,
            instances=args.instances,
            boot_vpus_per_gb=args.boot_vpus_per_gb,
            max_monthly_usd=args.max_monthly_usd,
        )
    except (ValueError, KeyError) as exc:
        result = {"valid": False, "error": str(exc)}
        print(json.dumps(result, indent=2) if args.json else f"INVALID: {exc}")
        raise SystemExit(1)

    print(json.dumps(result, indent=2) if args.json else result)


if __name__ == "__main__":
    main()
