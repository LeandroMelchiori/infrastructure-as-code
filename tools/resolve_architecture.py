#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def load_catalog() -> dict:
    with (ROOT / "catalog.yaml").open(encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def resolve(architecture_id: str, requested: list[str]) -> dict:
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

    warnings = []
    if "application-storage" in resolved:
        warnings.append(
            "application-storage owns its bucket in a separate Terraform state; "
            "the Docker platform must only consume it as an external resource"
        )

    return {
        "valid": True,
        "architecture": architecture_id,
        "provider": architecture["provider"],
        "reference_path": architecture["path"],
        "implementation_path": architecture.get("implementation"),
        "capabilities": resolved,
        "capability_paths": paths,
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
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    try:
        result = resolve(args.architecture, args.capability)
    except (ValueError, KeyError) as exc:
        result = {"valid": False, "error": str(exc)}
        print(json.dumps(result, indent=2) if args.json else f"INVALID: {exc}")
        raise SystemExit(1)

    print(json.dumps(result, indent=2) if args.json else result)


if __name__ == "__main__":
    main()
