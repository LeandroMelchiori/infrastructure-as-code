import copy
import importlib.util
import sys
import types
import unittest
from datetime import date, timedelta
from pathlib import Path


if sys.platform == "win32":
    sys.modules.setdefault("fcntl", types.SimpleNamespace())

WRAPPER_PATH = Path(__file__).parents[2] / "cloud-init" / "deploy-compose-app.py"
SPEC = importlib.util.spec_from_file_location("deploy_compose_app", WRAPPER_PATH)
WRAPPER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(WRAPPER)

IMAGE = (
    "ocir.sa-saopaulo-1.oci.oraclecloud.com/namespace/platform/service@"
    "sha256:" + ("a" * 64)
)


def baseline():
    rendered = {
        "name": "example",
        "networks": {"proxy": {"external": True, "name": "proxy"}},
        "services": {
            "app": {
                "image": IMAGE,
                "user": "10001:10001",
                "read_only": True,
                "cap_drop": ["ALL"],
                "security_opt": ["no-new-privileges:true"],
                "cpus": 0.5,
                "mem_limit": 536870912,
                "pids_limit": 256,
                "tmpfs": ["/tmp:rw,noexec,nosuid,nodev,size=67108864"],
                "healthcheck": {"test": ["CMD", "true"], "retries": 3},
                "networks": {"proxy": {}},
                "volumes": [],
            }
        },
        "volumes": {},
    }
    config = {
        "allowed_images": [],
        "compose_file": "compose.yaml",
        "health_url": "https://example.invalid/health",
        "repository": "ocir.sa-saopaulo-1.oci.oraclecloud.com/namespace/platform/service",
        "service": "app",
    }
    policy = {"profile": "strict", "exceptions": []}
    return rendered, config, policy


def exception(control, service="app", target=None):
    value = {
        "control": control,
        "service": service,
        "reason": "Required temporarily while the image is remediated.",
        "expires_on": (date.today() + timedelta(days=30)).isoformat(),
    }
    if target is not None:
        value["target"] = target
    return value


class ContainerHardeningTests(unittest.TestCase):
    def validate(self, rendered, config, policy):
        WRAPPER.validate_compose(rendered, "example")
        WRAPPER.validate_deployment(rendered, config, IMAGE, policy)

    def test_secure_baseline_passes(self):
        self.validate(*baseline())

    def test_no_new_privileges_is_critical(self):
        rendered, config, policy = baseline()
        rendered["services"]["app"]["security_opt"] = []
        with self.assertRaisesRegex(WRAPPER.DeploymentError, "no-new-privileges"):
            self.validate(rendered, config, policy)

    def test_resource_limits_are_required(self):
        rendered, config, policy = baseline()
        del rendered["services"]["app"]["mem_limit"]
        with self.assertRaisesRegex(WRAPPER.DeploymentError, "memory limit"):
            self.validate(rendered, config, policy)

    def test_deployable_service_requires_healthcheck(self):
        rendered, config, policy = baseline()
        del rendered["services"]["app"]["healthcheck"]
        with self.assertRaisesRegex(WRAPPER.DeploymentError, "active healthcheck"):
            self.validate(rendered, config, policy)

    def test_non_root_exception_must_be_explicit(self):
        rendered, config, policy = baseline()
        rendered["services"]["app"]["user"] = "0:0"
        with self.assertRaisesRegex(WRAPPER.DeploymentError, "numeric non-root"):
            self.validate(rendered, config, policy)

        policy = {
            "profile": "dev",
            "exceptions": [exception("non_root_user")],
        }
        WRAPPER.validate_hardening_policy(policy)
        self.validate(rendered, config, policy)

    def test_writable_volume_exception_is_target_scoped(self):
        rendered, config, policy = baseline()
        rendered["volumes"] = {"data": {}}
        rendered["services"]["app"]["volumes"] = [
            {
                "type": "volume",
                "source": "data",
                "target": "/var/lib/example",
                "read_only": False,
                "volume": {},
            }
        ]
        with self.assertRaisesRegex(WRAPPER.DeploymentError, "writable named volume"):
            self.validate(rendered, config, policy)

        policy = {
            "profile": "prod",
            "exceptions": [
                exception("writable_volume", target="/var/lib/example")
            ],
        }
        WRAPPER.validate_hardening_policy(policy)
        self.validate(rendered, config, policy)

    def test_unused_exception_fails_closed(self):
        rendered, config, policy = baseline()
        policy = {
            "profile": "dev",
            "exceptions": [exception("non_root_user")],
        }
        WRAPPER.validate_hardening_policy(policy)
        with self.assertRaisesRegex(WRAPPER.DeploymentError, "unused exception"):
            self.validate(rendered, config, policy)

    def test_critical_controls_are_not_valid_exception_types(self):
        policy = {
            "profile": "dev",
            "exceptions": [exception("no_new_privileges")],
        }
        with self.assertRaisesRegex(WRAPPER.DeploymentError, "control is invalid"):
            WRAPPER.validate_hardening_policy(policy)


if __name__ == "__main__":
    unittest.main()
