#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def load_yaml(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def load_pricing(provider: str) -> dict:
    path = ROOT / "pricing" / provider / "current.yaml"
    if not path.exists():
        raise ValueError(f"No pricing catalog for provider: {provider}")
    return load_yaml(path)


def load_constraint_profile(profile_id: str | None) -> dict | None:
    if not profile_id:
        return None

    catalog = load_yaml(ROOT / "catalog.yaml")
    ref = catalog.get("constraint_profiles", {}).get(profile_id)
    if not ref:
        raise ValueError(f"Unknown constraint profile: {profile_id}")
    return load_yaml(ROOT / ref["path"])


def _round(value: float) -> float:
    return round(value + 1e-12, 4)


def estimate_monthly_cost(
    *,
    provider: str,
    shape: str,
    ocpus: float,
    memory_gb: float,
    boot_volume_gb: float,
    instances: int = 1,
    boot_vpus_per_gb: int | None = None,
    profile_id: str | None = None,
) -> dict:
    if provider != "oci":
        raise ValueError(f"Cost estimation not implemented for provider: {provider}")
    if instances < 1:
        raise ValueError("instances must be at least 1")

    pricing = load_pricing(provider)
    shape_price = pricing.get("compute", {}).get("shapes", {}).get(shape)
    if not shape_price:
        raise ValueError(f"No pricing data for shape: {shape}")

    hours = pricing.get("hours_per_month", 730)
    volume_price = pricing.get("block_volume", {})
    vpus = (
        boot_vpus_per_gb
        if boot_vpus_per_gb is not None
        else volume_price.get("default_boot_vpus_per_gb", 10)
    )

    total_ocpu_hours = ocpus * instances * hours
    total_memory_hours = memory_gb * instances * hours
    total_boot_gb = boot_volume_gb * instances

    breakdown = {
        "compute_ocpu": _round(total_ocpu_hours * shape_price["ocpu_hour_usd"]),
        "compute_memory": _round(
            total_memory_hours * shape_price["memory_gb_hour_usd"]
        ),
        "boot_volume_capacity": _round(
            total_boot_gb * volume_price["storage_gb_month_usd"]
        ),
        "boot_volume_performance": _round(
            total_boot_gb * vpus * volume_price["vpu_gb_month_usd"]
        ),
    }
    gross = _round(sum(breakdown.values()))

    conditional_free = False
    conditions: list[str] = []
    profile = load_constraint_profile(profile_id)

    if profile_id == "always-free" and profile:
        allowed = profile.get("compute", {}).get("allowed_shapes", {}).get(shape)
        storage = profile.get("storage", {})
        if allowed:
            within_compute = (
                ocpus * instances <= allowed.get("max_total_ocpus", float("inf"))
                and memory_gb * instances
                <= allowed.get("max_total_memory_gb", float("inf"))
            )
            within_storage = (
                boot_volume_gb * instances
                <= storage.get("max_total_block_volume_gb", float("inf"))
            )
            if within_compute and within_storage:
                conditional_free = True
                conditions = [
                    "OCI account is eligible for the Always Free entitlement",
                    "resources are provisioned in the tenancy home region when required",
                    "eligible capacity is available",
                    "usage remains within all Always Free tenancy-wide limits",
                ]

    estimated = 0.0 if conditional_free else gross

    return {
        "provider": provider,
        "currency": pricing.get("currency", "USD"),
        "pricing_last_reviewed": pricing.get("last_reviewed"),
        "hours_per_month": hours,
        "shape": shape,
        "instances": instances,
        "boot_vpus_per_gb": vpus,
        "gross_list_price_monthly_usd": gross,
        "estimated_monthly_usd": estimated,
        "conditional_free": conditional_free,
        "conditions": conditions,
        "breakdown_monthly_usd": breakdown,
        "modeled_scope": pricing.get("model_scope", {}),
        "sources": pricing.get("sources", {}),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Estimate modeled monthly cloud cost")
    parser.add_argument("--provider", default="oci")
    parser.add_argument("--shape", required=True)
    parser.add_argument("--ocpus", type=float, required=True)
    parser.add_argument("--memory-gb", type=float, required=True)
    parser.add_argument("--boot-volume-gb", type=float, required=True)
    parser.add_argument("--instances", type=int, default=1)
    parser.add_argument("--boot-vpus-per-gb", type=int)
    parser.add_argument("--profile")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    try:
        result = estimate_monthly_cost(
            provider=args.provider,
            shape=args.shape,
            ocpus=args.ocpus,
            memory_gb=args.memory_gb,
            boot_volume_gb=args.boot_volume_gb,
            instances=args.instances,
            boot_vpus_per_gb=args.boot_vpus_per_gb,
            profile_id=args.profile,
        )
    except (ValueError, KeyError) as exc:
        result = {"valid": False, "error": str(exc)}
        print(json.dumps(result, indent=2) if args.json else f"INVALID: {exc}")
        raise SystemExit(1)

    result["valid"] = True
    print(json.dumps(result, indent=2) if args.json else result)


if __name__ == "__main__":
    main()
