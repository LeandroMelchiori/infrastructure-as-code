import importlib.util
import unittest
from pathlib import Path

from checkov.common.models.enums import CheckResult


CHECK_PATH = (
    Path(__file__).parents[1]
    / "checkov"
    / "warnings"
    / "oci_required_tags.py"
)
SPEC = importlib.util.spec_from_file_location("oci_required_tags", CHECK_PATH)
POLICY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POLICY)


class OCIRequiredTagsTests(unittest.TestCase):
    def test_dynamic_module_tags_are_configured(self):
        result = POLICY.check.scan_resource_conf(
            {"freeform_tags": ["${var.common_tags}"]}
        )
        self.assertEqual(result, CheckResult.PASSED)

    def test_literal_tags_are_configured(self):
        result = POLICY.check.scan_resource_conf(
            {"freeform_tags": [{"Project": "example"}]}
        )
        self.assertEqual(result, CheckResult.PASSED)

    def test_missing_tags_are_rejected(self):
        self.assertEqual(POLICY.check.scan_resource_conf({}), CheckResult.FAILED)

    def test_empty_tags_are_rejected(self):
        result = POLICY.check.scan_resource_conf({"freeform_tags": [{}]})
        self.assertEqual(result, CheckResult.FAILED)


if __name__ == "__main__":
    unittest.main()
