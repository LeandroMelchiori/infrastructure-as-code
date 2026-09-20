import re
from typing import Any, Iterable

from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


def _strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from _strings(item)
    elif isinstance(value, (list, tuple, set)):
        for item in value:
            yield from _strings(item)


class OCIIdentityPolicyLeastPrivilege(BaseResourceCheck):
    def __init__(self) -> None:
        super().__init__(
            name="OCI IAM policies must not grant unrestricted administrative access",
            id="CKV2_IAC_OCI_1",
            categories=(CheckCategories.IAM,),
            supported_resources=("oci_identity_policy",),
        )

    def scan_resource_conf(self, conf: dict[str, Any]) -> CheckResult:
        for statement in _strings(conf.get("statements", [])):
            normalized = " ".join(statement.lower().split())

            if re.match(r"^allow\s+any-user\s+", normalized):
                return CheckResult.FAILED

            if re.search(r"\bto\s+(?:manage|use)\s+all-resources\b", normalized):
                return CheckResult.FAILED

            manages_tenancy = re.search(
                r"\bto\s+manage\s+[a-z0-9-]+\s+in\s+tenancy\b", normalized
            )
            if manages_tenancy and " where " not in normalized:
                return CheckResult.FAILED

        return CheckResult.PASSED

    def get_evaluated_keys(self) -> list[str]:
        return ["statements"]


check = OCIIdentityPolicyLeastPrivilege()

