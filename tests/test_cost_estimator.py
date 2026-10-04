import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from estimate_cost import estimate_monthly_cost


def test_paid_a1_estimate_uses_list_prices():
    result = estimate_monthly_cost(
        provider="oci",
        shape="VM.Standard.A1.Flex",
        ocpus=1,
        memory_gb=6,
        boot_volume_gb=50,
    )

    assert result["conditional_free"] is False
    assert result["estimated_monthly_usd"] == 15.995


def test_always_free_profile_zeroes_eligible_modeled_resources():
    result = estimate_monthly_cost(
        provider="oci",
        shape="VM.Standard.A1.Flex",
        ocpus=2,
        memory_gb=12,
        boot_volume_gb=50,
        profile_id="always-free",
    )

    assert result["conditional_free"] is True
    assert result["estimated_monthly_usd"] == 0.0
    assert result["gross_list_price_monthly_usd"] > 0


def test_always_free_profile_does_not_hide_out_of_profile_cost():
    result = estimate_monthly_cost(
        provider="oci",
        shape="VM.Standard.A1.Flex",
        ocpus=4,
        memory_gb=24,
        boot_volume_gb=50,
        profile_id="always-free",
    )

    assert result["conditional_free"] is False
    assert result["estimated_monthly_usd"] > 0
