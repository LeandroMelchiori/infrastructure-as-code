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

    for rule in conf.get("ingress_security_rules", []):
        if isinstance(rule, dict):
            yield rule


def _exposes_ssh(rule: dict[str, Any]) -> bool:
    tcp_options = _first(rule.get("tcp_options", {}))
    if not isinstance(tcp_options, dict):
        return False

    port_range = _first(tcp_options.get("destination_port_range", {}))
    if not isinstance(port_range, dict):
        return False

    try:
        minimum = int(_first(port_range.get("min")))
        maximum = int(_first(port_range.get("max")))
    except (TypeError, ValueError):
        return False
    return minimum <= 22 <= maximum


class OCIUnrestrictedIngress(BaseResourceCheck):
    def __init__(self) -> None:
        super().__init__(
            name="OCI network rules must not expose SSH or all protocols to the Internet",
            id="CKV2_IAC_OCI_2",
            categories=(CheckCategories.NETWORKING,),
            supported_resources=(
                "oci_core_network_security_group_security_rule",
                "oci_core_security_list",
            ),
        )

    def scan_resource_conf(self, conf: dict[str, Any]) -> CheckResult:
        for rule in _rules(conf):
            direction = str(_first(rule.get("direction", "INGRESS"))).upper()
            source = str(_first(rule.get("source", "")))
            protocol = str(_first(rule.get("protocol", ""))).lower()

            if direction != "INGRESS" or source not in PUBLIC_CIDRS:
                continue
            if protocol == "all" or (protocol == "6" and _exposes_ssh(rule)):
                return CheckResult.FAILED

        return CheckResult.PASSED

    def get_evaluated_keys(self) -> list[str]:
        return [
            "direction", "source", "protocol", "tcp_options", "ingress_security_rules"
        ]


check = OCIUnrestrictedIngress()

