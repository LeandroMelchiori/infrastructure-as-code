import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from resolve_architecture import resolve


def test_resolves_existing_oci_architecture():
    result = resolve("oci-single-vm-multi-app", ["observability", "backup"])
    assert result["valid"] is True
    assert result["provider"] == "oci"
    assert result["capabilities"] == ["observability", "backup"]
    assert result["requires_human_approval"]["apply"] is True


def test_storage_preserves_separate_ownership():
    result = resolve("oci-single-vm-multi-app", ["application-storage"])
    assert any("separate Terraform state" in item for item in result["warnings"])


def test_rejects_unknown_capability():
    try:
        resolve("oci-single-vm-multi-app", ["made-up-service"])
    except ValueError as exc:
        assert "Unknown capability" in str(exc)
    else:
        raise AssertionError("Expected unknown capability to fail")
