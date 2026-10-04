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
    assert result["cost_estimate"]["estimated_monthly_usd"] > 0


def test_resolves_always_free_defaults():
    result = resolve(
        "oci-single-vm-multi-app",
        [],
        profile_id="always-free",
    )
    assert result["compute"]["shape"] == "VM.Standard.A1.Flex"
    assert result["compute"]["ocpus_per_instance"] == 2
    assert result["compute"]["memory_gb_per_instance"] == 12
    assert result["terraform_inputs"]["ocpus"] == 2
    assert result["terraform_inputs"]["memory_in_gbs"] == 12
    assert result["cost_estimate"]["estimated_monthly_usd"] == 0.0
    assert result["cost_estimate"]["conditional_free"] is True


def test_resolves_custom_sizing_inside_always_free():
    result = resolve(
        "oci-single-vm-multi-app",
        [],
        profile_id="always-free",
        ocpus=1,
        memory_gb=6,
    )
    assert result["compute"]["ocpus_per_instance"] == 1
    assert result["compute"]["memory_gb_per_instance"] == 6


def test_rejects_sizing_above_always_free_profile():
    try:
        resolve(
            "oci-single-vm-multi-app",
            [],
            profile_id="always-free",
            ocpus=4,
            memory_gb=24,
        )
    except ValueError as exc:
        assert "exceeds profile" in str(exc)
    else:
        raise AssertionError("Expected Always Free constraint violation")


def test_custom_sizing_without_profile_is_not_claimed_free():
    result = resolve(
        "oci-single-vm-multi-app",
        [],
        ocpus=4,
        memory_gb=24,
    )
    assert result["valid"] is True
    assert any("not guaranteed to be free" in item for item in result["warnings"])


def test_budget_accepts_modeled_cost_within_limit():
    result = resolve(
        "oci-single-vm-multi-app",
        [],
        ocpus=1,
        memory_gb=6,
        max_monthly_usd=20,
    )
    assert result["budget"]["status"] == "within_modeled_scope"
    assert result["budget"]["modeled_estimated_monthly_usd"] == 15.995


def test_budget_rejects_modeled_cost_above_limit():
    try:
        resolve(
            "oci-single-vm-multi-app",
            [],
            ocpus=1,
            memory_gb=6,
            max_monthly_usd=10,
        )
    except ValueError as exc:
        assert "exceeds budget" in str(exc)
    else:
        raise AssertionError("Expected budget constraint violation")


def test_zero_budget_passes_with_conditional_always_free_profile():
    result = resolve(
        "oci-single-vm-multi-app",
        [],
        profile_id="always-free",
        max_monthly_usd=0,
    )
    assert result["budget"]["modeled_estimated_monthly_usd"] == 0.0


def test_single_vm_architecture_rejects_multiple_instances():
    try:
        resolve("oci-single-vm-multi-app", [], instances=2)
    except ValueError as exc:
        assert "at most 1 instance" in str(exc)
    else:
        raise AssertionError("Expected single-VM architecture to reject two instances")


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
