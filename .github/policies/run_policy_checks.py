#!/usr/bin/env python3
"""Run Checkov and repository policies without exposing source snippets or values."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, replace
from datetime import date
from pathlib import Path, PurePosixPath
from typing import Any, Iterable

import hcl2
import yaml
from lark.exceptions import LarkError


BLOCKING_CHECKS = (
    "CKV_OCI_1",
    "CKV_OCI_10",
    "CKV2_IAC_OCI_1",
    "CKV2_IAC_OCI_2",
)
WARNING_SKIP_CHECKS = (*BLOCKING_CHECKS, "CKV_OCI_19", "CKV_OCI_22", "CKV2_OCI_2")
IMAGE_RULE = "IAC_DOCKER_001"
POLICY_ERROR_RULE = "IAC_POLICY_001"
POLICY_WARNING_RULE = "IAC_POLICY_101"
ENVIRONMENT_CONFIG_RULE = "IAC_ENV_001"
ENVIRONMENT_NETWORK_RULE = "IAC_ENV_002"
ENVIRONMENT_PROD_RULE = "IAC_ENV_003"
ENVIRONMENT_STAGING_RULE = "IAC_ENV_101"
ENVIRONMENT_DEV_RULE = "IAC_ENV_102"
CONTAINER_CRITICAL_RULE = "IAC_CONTAINER_001"
CONTAINER_BASELINE_RULE = "IAC_CONTAINER_002"
CONTAINER_DEV_RULE = "IAC_CONTAINER_101"
SAFE_IDENTIFIER = re.compile(r"^[A-Za-z0-9_.:-]+$")
IMAGE_LINE = re.compile(r"^\s*image\s*:\s*['\"]?([^\s#'\"]+)")
VARIABLE_START = re.compile(r'^\s*variable\s+"([^"]+)"\s*\{')
DEFAULT_STRING = re.compile(r'^\s*default\s*=\s*"([^"]+)"')


@dataclass(frozen=True)
class Finding:
    severity: str
    rule_id: str
    name: str
    path: str
    resource: str = ""
    line: int | None = None
    waived: bool = False


@dataclass(frozen=True)
class ExceptionEntry:
    rule_id: str
    path: str
    resource: str
    owner: str
    reason: str
    expires_on: date


def clean_text(value: Any, limit: int = 180) -> str:
    text = " ".join(str(value or "").replace("|", "\\|").split())
    return text[:limit]


def normalize_path(raw_path: Any, target: Path, repo_root: Path) -> str:
    value = str(raw_path or "").replace("\\", "/")
    target_posix = target.as_posix().strip("/")

    if target_posix in value:
        value = value[value.index(target_posix) :]
    else:
        candidate = Path(value)
        if candidate.is_absolute():
            try:
                value = candidate.resolve().relative_to(repo_root).as_posix()
            except (OSError, ValueError, LarkError):
                value = candidate.name
        else:
            value = f"{target_posix}/{value.lstrip('/')}"

    normalized = PurePosixPath(value)
    if normalized.is_absolute() or ".." in normalized.parts:
        return target_posix
    return normalized.as_posix()


def load_json(stdout: str) -> Any:
    payload = stdout.strip()
    if not payload:
        raise ValueError("empty Checkov output")
    return json.loads(payload)


def reports(payload: Any) -> Iterable[dict[str, Any]]:
    if isinstance(payload, dict):
        yield payload
    elif isinstance(payload, list):
        for item in payload:
            if isinstance(item, dict):
                yield item


def run_checkov(
    repo_root: Path,
    target: Path,
    severity: str,
    arguments: list[str],
) -> list[Finding]:
    command = [
        sys.executable,
        "-c",
        (
            "from checkov.main import Checkov; import sys; "
            "sys.exit(Checkov().run())"
        ),
        "--directory",
        target.as_posix(),
        "--output",
        "json",
        "--compact",
        "--quiet",
        "--skip-download",
        *arguments,
    ]
    process = subprocess.run(
        command,
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
        env={**os.environ, "LOG_LEVEL": "ERROR"},
    )

    try:
        payload = load_json(process.stdout)
    except (ValueError, json.JSONDecodeError):
        return [
            Finding(
                severity="error",
                rule_id=POLICY_ERROR_RULE,
                name="Checkov did not produce a valid machine-readable result",
                path=target.as_posix(),
            )
        ]

    findings: list[Finding] = []
    parse_errors = 0
    for report in reports(payload):
        summary = report.get("summary", {})
        parse_errors += int(summary.get("parsing_errors") or 0)

        for check in report.get("results", {}).get("failed_checks", []):
            if not isinstance(check, dict):
                continue
            line_range = check.get("file_line_range") or []
            line = line_range[0] if line_range and isinstance(line_range[0], int) else None
            findings.append(
                Finding(
                    severity=severity,
                    rule_id=clean_text(check.get("check_id"), 80),
                    name=clean_text(check.get("check_name")),
                    path=normalize_path(check.get("file_path"), target, repo_root),
                    resource=clean_text(check.get("resource"), 160),
                    line=line,
                )
            )

    if parse_errors:
        findings.append(
            Finding(
                severity="error",
                rule_id=POLICY_ERROR_RULE,
                name=f"Checkov reported {parse_errors} parsing error(s)",
                path=target.as_posix(),
            )
        )
    elif process.returncode not in (0, 1):
        findings.append(
            Finding(
                severity="error",
                rule_id=POLICY_ERROR_RULE,
                name="Checkov terminated unexpectedly",
                path=target.as_posix(),
            )
        )

    return findings


def run_checkov_for_targets(
    repo_root: Path,
    targets: list[Path],
    severity: str,
    arguments: list[str],
) -> list[Finding]:
    findings: list[Finding] = []
    for target in targets:
        findings.extend(run_checkov(repo_root, target, severity, arguments))
    return findings


def image_uses_latest(reference: str) -> bool:
    value = reference.strip().strip("'\"")
    if not value or "${" in value or "{{" in value:
        return False
    if "@sha256:" in value:
        return False
    image_name = value.rsplit("/", 1)[-1]
    return ":" not in image_name or image_name.endswith(":latest")


def scan_images(repo_root: Path, target: Path) -> list[Finding]:
    findings: list[Finding] = []
    target_root = repo_root / target

    for path in sorted(target_root.rglob("*")):
        if not path.is_file() or ".terraform" in path.parts:
            continue
        if path.suffix not in {".tf", ".tftpl", ".yaml", ".yml"}:
            continue

        relative = path.relative_to(repo_root).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        current_image_variable = ""
        variable_depth = 0

        for line_number, line in enumerate(lines, start=1):
            image_match = IMAGE_LINE.match(line)
            if image_match and image_uses_latest(image_match.group(1)):
                findings.append(
                    Finding(
                        severity="error",
                        rule_id=IMAGE_RULE,
                        name="Docker images must use an explicit non-latest tag or digest",
                        path=relative,
                        line=line_number,
                    )
                )

            variable_match = VARIABLE_START.match(line)
            if variable_match:
                name = variable_match.group(1)
                current_image_variable = name if name.endswith("_image") else ""
                variable_depth = line.count("{") - line.count("}")
                continue

            if variable_depth > 0:
                if current_image_variable:
                    default_match = DEFAULT_STRING.match(line)
                    if default_match and image_uses_latest(default_match.group(1)):
                        findings.append(
                            Finding(
                                severity="error",
                                rule_id=IMAGE_RULE,
                                name="Docker image variable defaults must be pinned",
                                path=relative,
                                resource=f"variable.{current_image_variable}",
                                line=line_number,
                            )
                        )
                variable_depth += line.count("{") - line.count("}")
                if variable_depth <= 0:
                    current_image_variable = ""

    return findings


def scan_container_hardening(
    repo_root: Path, target: Path, environment: str
) -> list[Finding]:
    compose_path = repo_root / target / "deployment" / "compose.example.yml"
    config_path = repo_root / target / "deployment" / "app-config.example.json"
    findings: list[Finding] = []

    def add(severity: str, rule_id: str, name: str, resource: str = "") -> None:
        findings.append(
            Finding(
                severity=severity,
                rule_id=rule_id,
                name=name,
                path=compose_path.relative_to(repo_root).as_posix(),
                resource=resource,
            )
        )

    def critical(name: str, resource: str = "") -> None:
        add("error", CONTAINER_CRITICAL_RULE, name, resource)

    def baseline(name: str, resource: str = "") -> None:
        add(
            "warning" if environment == "dev" else "error",
            CONTAINER_DEV_RULE if environment == "dev" else CONTAINER_BASELINE_RULE,
            name,
            resource,
        )

    try:
        compose = yaml.safe_load(compose_path.read_text(encoding="utf-8"))
        app_config = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, ValueError, yaml.YAMLError):
        critical("Container hardening examples are missing or invalid")
        return findings

    if not isinstance(compose, dict) or not isinstance(compose.get("services"), dict):
        critical("Compose hardening example must define services")
        return findings
    target_service = app_config.get("service") if isinstance(app_config, dict) else None
    services = compose["services"]
    networks = compose.get("networks", {})
    if target_service not in services:
        critical("Deployment service must exist in the Compose hardening example")

    proxy_networks = set()
    if not isinstance(networks, dict):
        critical("Compose networks must use object syntax")
        networks = {}
    for network_name, network in networks.items():
        network = network or {}
        if not isinstance(network, dict):
            critical("Network definitions must use object syntax", f"network.{network_name}")
            continue
        if network.get("external"):
            if network.get("name") != "proxy":
                critical("Only the root-managed proxy network may be external", f"network.{network_name}")
            proxy_networks.add(network_name)

    forbidden_keys = {
        "build",
        "cap_add",
        "devices",
        "ipc",
        "network_mode",
        "pid",
        "ports",
        "privileged",
        "runtime",
        "userns_mode",
    }
    for service_name, service in services.items():
        resource = f"service.{service_name}"
        if not isinstance(service, dict):
            critical("Service definition must use object syntax", resource)
            continue

        if set(service) & forbidden_keys:
            critical("Service contains a forbidden host-level capability", resource)

        image = service.get("image")
        if not isinstance(image, str) or (
            "${DEPLOY_IMAGE" not in image and "@sha256:" not in image
        ):
            critical("Service image must be server-resolved or pinned by digest", resource)

        security_options = service.get("security_opt", [])
        if not isinstance(security_options, list) or not set(security_options).intersection(
            {"no-new-privileges", "no-new-privileges:true"}
        ):
            critical("Service must enable no-new-privileges", resource)

        cap_drop = service.get("cap_drop", [])
        if not isinstance(cap_drop, list) or set(cap_drop) != {"ALL"}:
            critical("Service must drop all Linux capabilities", resource)

        healthcheck = service.get("healthcheck")
        if service_name == target_service and (
            not isinstance(healthcheck, dict)
            or healthcheck.get("disable") is True
            or not healthcheck.get("test")
        ):
            critical("Deployable service must define an active healthcheck", resource)

        user = service.get("user")
        if not isinstance(user, str) or not re.fullmatch(r"[1-9][0-9]*(?::[0-9]+)?", user):
            baseline("Service should declare a numeric non-root user", resource)
        if service.get("read_only") is not True:
            baseline("Service root filesystem should be read-only", resource)

        secure_tmpfs = False
        tmpfs = service.get("tmpfs", [])
        if isinstance(tmpfs, list):
            for entry in tmpfs:
                if not isinstance(entry, str):
                    continue
                tmpfs_target, separator, options = entry.partition(":")
                option_names = {
                    option.split("=", 1)[0] for option in options.split(",")
                }
                if (
                    tmpfs_target == "/tmp"
                    and separator
                    and {"rw", "noexec", "nosuid", "nodev"}.issubset(option_names)
                ):
                    secure_tmpfs = True
        if not secure_tmpfs:
            baseline("Service should use a restricted /tmp tmpfs", resource)

        if not service.get("cpus") or not service.get("mem_limit"):
            critical("Service must define CPU and memory limits", resource)

        mounts = service.get("volumes", [])
        if not isinstance(mounts, list):
            critical("Service volumes must use list syntax", resource)
        else:
            for mount in mounts:
                if not isinstance(mount, dict) or mount.get("type") != "volume":
                    critical("Bind mounts and short mount syntax are forbidden", resource)
                    continue
                target_path = mount.get("target")
                if target_path in {"/", "/run/docker.sock", "/var/run/docker.sock"}:
                    critical("Sensitive mount target is forbidden", resource)
                if mount.get("read_only") is not True:
                    baseline("Writable volume requires a documented runtime exception", resource)

        service_networks = service.get("networks", [])
        if isinstance(service_networks, dict):
            service_networks = list(service_networks)
        if not isinstance(service_networks, list):
            critical("Service networks must use list or object syntax", resource)
            service_networks = []
        if service_name != target_service and set(service_networks) & proxy_networks:
            baseline("Auxiliary service should not join the shared proxy network", resource)

    return findings

def load_hcl_file(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        payload = hcl2.load(handle)
    if not isinstance(payload, dict):
        return {}

    # bc-python-hcl2 wraps top-level assignments in a single-item list.
    return {
        key: value[0] if isinstance(value, list) and len(value) == 1 else value
        for key, value in payload.items()
    }


def environment_profile_findings(
    repo_root: Path, target: Path, environment: str
) -> list[Finding]:
    environment_root = repo_root / target / "environments" / environment
    tfvars_path = environment_root / "terraform.tfvars.example"
    backend_path = environment_root / "backend.oci.tfbackend.example"
    findings: list[Finding] = []

    def add(
        severity: str,
        rule_id: str,
        name: str,
        path: Path,
        resource: str = "",
    ) -> None:
        findings.append(
            Finding(
                severity=severity,
                rule_id=rule_id,
                name=name,
                path=path.relative_to(repo_root).as_posix(),
                resource=resource,
            )
        )

    try:
        variables = load_hcl_file(tfvars_path)
    except (OSError, ValueError, LarkError):
        add(
            "error",
            ENVIRONMENT_CONFIG_RULE,
            "Environment variable example is missing or invalid HCL",
            tfvars_path,
        )
        return findings

    try:
        backend = load_hcl_file(backend_path)
    except (OSError, ValueError, LarkError):
        add(
            "error",
            ENVIRONMENT_CONFIG_RULE,
            "Environment backend example is missing or invalid HCL",
            backend_path,
        )
        return findings

    if variables.get("environment_name") != environment:
        add(
            "error",
            ENVIRONMENT_CONFIG_RULE,
            "environment_name must match the selected environment",
            tfvars_path,
            "var.environment_name",
        )

    expected_key = f"docker-platform/{environment}/terraform.tfstate"
    if backend.get("key") != expected_key:
        add(
            "error",
            ENVIRONMENT_CONFIG_RULE,
            "Remote state key must be unique and match the selected environment",
            backend_path,
            "backend.key",
        )

    if variables.get("object_storage_access_type") != "NoPublicAccess":
        add(
            "error",
            ENVIRONMENT_CONFIG_RULE,
            "Object Storage must remain private in every environment",
            tfvars_path,
            "var.object_storage_access_type",
        )

    if variables.get("registry_visibility", "PRIVATE") != "PRIVATE":
        add(
            "error",
            ENVIRONMENT_CONFIG_RULE,
            "OCIR repositories must remain private",
            tfvars_path,
            "var.registry_visibility",
        )

    if variables.get("object_storage_delete_previous_versions_after_days") is not None:
        add(
            "warning",
            POLICY_WARNING_RULE,
            "Destructive Object Storage lifecycle requires explicit review",
            tfvars_path,
            "var.object_storage_delete_previous_versions_after_days",
        )

    public_ssh = variables.get("ssh_source_cidr") in ("0.0.0.0/0", "::/0")
    if public_ssh:
        add(
            "warning" if environment == "dev" else "error",
            ENVIRONMENT_DEV_RULE if environment == "dev" else ENVIRONMENT_NETWORK_RULE,
            (
                "Public SSH is accepted only as a documented dev warning"
                if environment == "dev"
                else "Public SSH is forbidden in staging and prod"
            ),
            tfvars_path,
            "var.ssh_source_cidr",
        )

    required_controls = {
        "monitoring_enabled": variables.get("monitoring_enabled") is True,
        "logging_enabled": variables.get("logging_enabled") is True,
        "backup_enabled": variables.get("backup_enabled") is True,
        "registry_enabled": variables.get("registry_enabled") is True,
        "registry_immutable": variables.get("registry_immutable") is True,
        "object_storage_versioning": variables.get("object_storage_versioning") is True,
    }
    if environment in {"staging", "prod"}:
        for control, enabled in required_controls.items():
            if enabled:
                continue
            add(
                "error" if environment == "prod" else "warning",
                ENVIRONMENT_PROD_RULE if environment == "prod" else ENVIRONMENT_STAGING_RULE,
                (
                    "Production control must be enabled"
                    if environment == "prod"
                    else "Staging should approximate production controls"
                ),
                tfvars_path,
                f"var.{control}",
            )

    return findings


def load_exceptions(path: Path, repo_root: Path) -> tuple[list[ExceptionEntry], list[Finding]]:
    errors: list[Finding] = []
    relative_path = path.relative_to(repo_root).as_posix()
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return [], [
            Finding(
                severity="error",
                rule_id=POLICY_ERROR_RULE,
                name="Policy exceptions file is missing or invalid JSON",
                path=relative_path,
            )
        ]

    raw_entries = payload.get("exceptions", []) if isinstance(payload, dict) else []
    if not isinstance(raw_entries, list):
        raw_entries = []
        errors.append(
            Finding(
                severity="error",
                rule_id=POLICY_ERROR_RULE,
                name="Policy exceptions must be a JSON array",
                path=relative_path,
            )
        )

    entries: list[ExceptionEntry] = []
    seen: set[tuple[str, str, str]] = set()
    for index, item in enumerate(raw_entries, start=1):
        try:
            if not isinstance(item, dict):
                raise ValueError
            rule_id = str(item["rule_id"])
            item_path = PurePosixPath(str(item["path"]))
            resource = str(item.get("resource", ""))
            owner = str(item["owner"]).strip()
            reason = str(item["reason"]).strip()
            expires_on = date.fromisoformat(str(item["expires_on"]))
            if (
                not SAFE_IDENTIFIER.fullmatch(rule_id)
                or item_path.is_absolute()
                or ".." in item_path.parts
                or not owner
                or len(reason) < 20
                or expires_on < date.today()
            ):
                raise ValueError
            key = (rule_id, item_path.as_posix(), resource)
            if key in seen:
                raise ValueError
            seen.add(key)
            entries.append(
                ExceptionEntry(
                    rule_id=rule_id,
                    path=item_path.as_posix(),
                    resource=resource,
                    owner=owner,
                    reason=reason,
                    expires_on=expires_on,
                )
            )
        except (KeyError, TypeError, ValueError):
            errors.append(
                Finding(
                    severity="error",
                    rule_id=POLICY_ERROR_RULE,
                    name=f"Policy exception {index} is invalid or expired",
                    path=relative_path,
                )
            )

    return entries, errors


def apply_exceptions(
    findings: list[Finding], entries: list[ExceptionEntry]
) -> tuple[list[Finding], list[ExceptionEntry]]:
    used: set[ExceptionEntry] = set()
    updated: list[Finding] = []

    for finding in findings:
        matched = next(
            (
                entry
                for entry in entries
                if entry.rule_id == finding.rule_id
                and entry.path == finding.path
                and (not entry.resource or entry.resource == finding.resource)
            ),
            None,
        )
        if matched:
            used.add(matched)
            updated.append(replace(finding, waived=True))
        else:
            updated.append(finding)

    return updated, [entry for entry in entries if entry not in used]


def markdown_row(finding: Finding) -> str:
    location = f"`{clean_text(finding.path, 160)}`"
    if finding.line:
        location += f":{finding.line}"
    return f"| `{finding.rule_id}` | {finding.name} | {location} |"


def unique_findings(findings: list[Finding]) -> list[Finding]:
    unique: list[Finding] = []
    seen: set[tuple[Any, ...]] = set()
    for finding in findings:
        key = (
            finding.severity, finding.rule_id, finding.name,
            finding.path, finding.line, finding.waived,
        )
        if key not in seen:
            seen.add(key)
            unique.append(finding)
    return unique


def publish_summary(
    findings: list[Finding], unused: list[ExceptionEntry], environment: str
) -> int:
    findings = unique_findings(findings)
    active_errors = [item for item in findings if item.severity == "error" and not item.waived]
    warnings = [item for item in findings if item.severity == "warning" and not item.waived]
    waived = [item for item in findings if item.waived]

    for entry in unused:
        warnings.append(
            Finding(
                severity="warning",
                rule_id=POLICY_WARNING_RULE,
                name="Documented exception did not match a current finding",
                path=entry.path,
            )
        )

    result = "FAIL" if active_errors else "PASS"
    lines = [
        "## Terraform Policy as Code",
        "",
        f"Environment: `{environment}`",
        "",
        "| Result | Blocking findings | Warnings | Accepted exceptions |",
        "| --- | ---: | ---: | ---: |",
        f"| {result} | {len(active_errors)} | {len(warnings)} | {len(waived)} |",
        "",
        "Checkov scanned Terraform source and repository policies scanned Docker image references. No plan, state, variable values, source snippets or detected secret values are published.",
    ]

    sections = (
        ("Blocking findings", active_errors),
        ("Warnings", warnings),
        ("Accepted exceptions", waived),
    )
    for title, items in sections:
        if not items:
            continue
        lines.extend(["", f"### {title}", "", "| Rule | Policy | Location |", "| --- | --- | --- |"])
        lines.extend(markdown_row(item) for item in items[:100])
        if len(items) > 100:
            lines.append(f"| ... | {len(items) - 100} additional finding(s) omitted | - |")

    summary = "\n".join(lines) + "\n"
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as handle:
            handle.write(summary)
    else:
        print(summary)

    for finding in active_errors:
        line = f",line={finding.line}" if finding.line else ""
        print(
            f"::error file={finding.path}{line},title={finding.rule_id}::{finding.name}"
            if os.environ.get("GITHUB_ACTIONS")
            else f"ERROR {finding.rule_id} {finding.path}: {finding.name}"
        )
    for finding in warnings:
        line = f",line={finding.line}" if finding.line else ""
        print(
            f"::warning file={finding.path}{line},title={finding.rule_id}::{finding.name}"
            if os.environ.get("GITHUB_ACTIONS")
            else f"WARN {finding.rule_id} {finding.path}: {finding.name}"
        )

    return 1 if active_errors else 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument(
        "--module-directory",
        action="append",
        default=[],
        type=Path,
        help="Additional local module directory included in static policy scans",
    )
    parser.add_argument("--exceptions", required=True, type=Path)
    parser.add_argument(
        "--environment",
        required=True,
        choices=("dev", "staging", "prod"),
        help="Environment profile whose examples and controls are validated",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path.cwd().resolve()
    target = args.directory
    scan_targets = [target, *args.module_directory]
    exceptions_path = (repo_root / args.exceptions).resolve()
    environment = args.environment

    blocking = run_checkov_for_targets(
        repo_root,
        scan_targets,
        "error",
        [
            "--framework",
            "terraform",
            "--external-checks-dir",
            ".github/policies/checkov/blocking",
            "--check",
            ",".join(BLOCKING_CHECKS),
        ],
    )
    secrets = run_checkov_for_targets(
        repo_root,
        scan_targets,
        "error",
        ["--framework", "secrets"],
    )
    warning_baseline = run_checkov_for_targets(
        repo_root,
        scan_targets,
        "warning",
        [
            "--framework",
            "terraform",
            "--external-checks-dir",
            ".github/policies/checkov/warnings",
            "--skip-check",
            ",".join(WARNING_SKIP_CHECKS),
            "--soft-fail",
        ],
    )
    images = [
        finding
        for scan_target in scan_targets
        for finding in scan_images(repo_root, scan_target)
    ]
    container_findings = scan_container_hardening(repo_root, target, environment)
    environment_findings = environment_profile_findings(
        repo_root, target, environment
    )
    entries, exception_errors = load_exceptions(exceptions_path, repo_root)

    findings = (
        blocking
        + secrets
        + warning_baseline
        + images
        + container_findings
        + environment_findings
        + exception_errors
    )
    findings, unused = apply_exceptions(findings, entries)
    return publish_summary(findings, unused, environment)


if __name__ == "__main__":
    sys.exit(main())
