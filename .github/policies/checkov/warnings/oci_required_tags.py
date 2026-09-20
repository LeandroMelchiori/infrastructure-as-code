from typing import Any

from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


TAGGABLE_RESOURCES = (
    "oci_artifacts_container_repository",
    "oci_core_instance",
    "oci_core_internet_gateway",
    "oci_core_network_security_group",
    "oci_core_public_ip",
    "oci_core_route_table",
    "oci_core_security_list",
    "oci_core_subnet",
    "oci_core_vcn",
    "oci_core_volume_backup_policy",
    "oci_kms_key",
    "oci_kms_vault",
    "oci_logging_log",
    "oci_logging_log_group",
    "oci_logging_unified_agent_configuration",
    "oci_monitoring_alarm",
    "oci_objectstorage_bucket",
    "oci_ons_notification_topic",
    "oci_ons_subscription",
)


def _configured(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, list):
        return any(_configured(item) for item in value)
    if isinstance(value, dict):
        return bool(value)
    if isinstance(value, str):
        return bool(value.strip())
    return True


class OCIRequiredTags(BaseResourceCheck):
    def __init__(self) -> None:
        super().__init__(
            name="Principal OCI resources should define freeform_tags or defined_tags",
            id="CKV2_IAC_OCI_101",
            categories=(CheckCategories.CONVENTION,),
            supported_resources=TAGGABLE_RESOURCES,
        )

    def scan_resource_conf(self, conf: dict[str, Any]) -> CheckResult:
        if _configured(conf.get("freeform_tags")) or _configured(conf.get("defined_tags")):
            return CheckResult.PASSED
        return CheckResult.FAILED

    def get_evaluated_keys(self) -> list[str]:
        return ["freeform_tags", "defined_tags"]


check = OCIRequiredTags()

