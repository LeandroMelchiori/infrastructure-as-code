from typing import Any, Iterable

from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


PUBLIC_CIDRS = {"0.0.0.0/0", "::/0"}


def _first(value: Any) -> Any:
    if isinstance(value, list) and len(value) == 1:
        return value[0]
    return value


def _rules(conf: dict[str, Any]) -> Iterable[dict[str, Any]]:
    if "direction" in conf:
        yield conf

    for rule in conf.get("egress_security_rules", []):
        if isinstance(rule, dict):
            yield rule


class OCIBroadEgress(BaseResourceCheck):
    def __init__(self) -> None:
        super().__init__(
            name="OCI unrestricted outbound traffic should be reviewed",
            id="CKV2_IAC_OCI_102",
            categories=(CheckCategories.NETWORKING,),
            supported_resources=(
                "oci_core_network_security_group_security_rule",
                "oci_core_security_list",
            ),
        )

    def scan_resource_conf(self, conf: dict[str, Any]) -> CheckResult:
        for rule in _rules(conf):
            direction = str(_first(rule.get("direction", "EGRESS"))).upper()
            destination = str(_first(rule.get("destination", "")))
            protocol = str(_first(rule.get("protocol", ""))).lower()

            if (
                direction == "EGRESS"
                and destination in PUBLIC_CIDRS
                and protocol == "all"
            ):
                return CheckResult.FAILED

        return CheckResult.PASSED

    def get_evaluated_keys(self) -> list[str]:
        return ["direction", "destination", "protocol", "egress_security_rules"]


check = OCIBroadEgress()

