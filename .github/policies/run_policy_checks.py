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
            except (OSError, ValueError):
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


def publish_summary(findings: list[Finding], unused: list[ExceptionEntry]) -> int:
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
    parser.add_argument("--exceptions", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path.cwd().resolve()
    target = args.directory
    exceptions_path = (repo_root / args.exceptions).resolve()

    blocking = run_checkov(
        repo_root,
        target,
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
    secrets = run_checkov(
        repo_root,
        target,
        "error",
        ["--framework", "secrets"],
    )
    warning_baseline = run_checkov(
        repo_root,
        target,
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
    images = scan_images(repo_root, target)
    entries, exception_errors = load_exceptions(exceptions_path, repo_root)

    findings = blocking + secrets + warning_baseline + images + exception_errors
    findings, unused = apply_exceptions(findings, entries)
    return publish_summary(findings, unused)


if __name__ == "__main__":
    sys.exit(main())

