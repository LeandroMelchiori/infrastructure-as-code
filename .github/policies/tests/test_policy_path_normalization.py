import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


RUNNER_PATH = Path(__file__).parents[1] / "run_policy_checks.py"
SPEC = importlib.util.spec_from_file_location("run_policy_checks", RUNNER_PATH)
RUNNER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = RUNNER
SPEC.loader.exec_module(RUNNER)


class PolicyPathNormalizationTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.repo_root = Path(self.temporary_directory.name).resolve()
        self.target = Path("oci/docker-platform")
        self.module_file = self.repo_root / "oci/modules/network/main.tf"
        self.module_file.parent.mkdir(parents=True)
        self.module_file.touch()

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_checkov_repo_path_is_repository_relative(self):
        result = RUNNER.normalize_path(
            "/oci/modules/network/main.tf",
            self.target,
            self.repo_root,
        )

        self.assertEqual(result, "oci/modules/network/main.tf")

    def test_checkov_windows_module_path_resolves_from_target(self):
        result = RUNNER.normalize_path(
            "\\\\..\\\\modules\\\\network\\\\main.tf",
            self.target,
            self.repo_root,
        )

        self.assertEqual(result, "oci/modules/network/main.tf")

    def test_absolute_repository_path_is_repository_relative(self):
        result = RUNNER.normalize_path(
            self.module_file,
            self.target,
            self.repo_root,
        )

        self.assertEqual(result, "oci/modules/network/main.tf")

    def test_unknown_path_fails_closed_to_scan_target(self):
        result = RUNNER.normalize_path(
            "../../outside.tf",
            self.target,
            self.repo_root,
        )

        self.assertEqual(result, "oci/docker-platform")


if __name__ == "__main__":
    unittest.main()
