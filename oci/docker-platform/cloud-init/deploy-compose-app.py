#!/usr/bin/python3
"""Deploy one allowlisted Compose application using an immutable image digest."""

import fcntl
import json
import logging
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path


CONFIG_ROOT = Path("/etc/docker-platform/apps")
WORK_ROOT = Path("/opt/apps/apps")
APP_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}$")
SHA_PATTERN = re.compile(r"^[0-9a-f]{40}$")
OCIR_REPOSITORY_PATTERN = re.compile(
    r"^ocir\.[a-z0-9-]+\.oci\.oraclecloud\.com/[a-z0-9]+/"
    r"[a-z0-9]+(?:[._/-][a-z0-9]+)*$"
)
DIGEST_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")

CONFIG_KEYS = {
    "allowed_images",
    "compose_file",
    "health_url",
    "repository",
    "service",
}
TOP_LEVEL_KEYS = {"name", "networks", "services", "volumes"}
SERVICE_KEYS = {
    "cap_drop",
    "command",
    "depends_on",
    "entrypoint",
    "environment",
    "expose",
    "healthcheck",
    "hostname",
    "image",
    "init",
    "labels",
    "logging",
    "networks",
    "platform",
    "read_only",
    "restart",
    "security_opt",
    "stop_grace_period",
    "stop_signal",
    "tmpfs",
    "user",
    "volumes",
    "working_dir",
}
FORBIDDEN_SERVICE_KEYS = {
    "build",
    "cap_add",
    "cgroup",
    "cgroup_parent",
    "configs",
    "container_name",
    "devices",
    "device_cgroup_rules",
    "env_file",
    "ipc",
    "network_mode",
    "pid",
    "ports",
    "privileged",
    "runtime",
    "secrets",
    "sysctls",
    "ulimits",
    "userns_mode",
    "uts",
}
NETWORK_KEYS = {
    "attachable",
    "driver",
    "enable_ipv4",
    "enable_ipv6",
    "external",
    "internal",
    "labels",
    "name",
}
SERVICE_NETWORK_KEYS = {
    "aliases",
    "gw_priority",
    "ipv4_address",
    "ipv6_address",
    "link_local_ips",
    "mac_address",
    "priority",
}
VOLUME_KEYS = {"external", "labels", "name"}
MOUNT_KEYS = {"read_only", "source", "target", "type", "volume"}
MOUNT_VOLUME_KEYS = {"nocopy", "subpath"}
DEPENDENCY_KEYS = {"condition", "required", "restart"}
HEALTHCHECK_KEYS = {
    "disable",
    "interval",
    "retries",
    "start_interval",
    "start_period",
    "test",
    "timeout",
}
LOGGING_KEYS = {"driver", "options"}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)sZ level=%(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
    stream=sys.stdout,
)
LOGGER = logging.getLogger("deploy-compose-app")


class DeploymentError(Exception):
    pass


def require_exact_arguments():
    if len(sys.argv) != 3:
        raise DeploymentError("expected exactly: deploy-compose-app <app> <commit-sha>")

    app_name, commit_sha = sys.argv[1], sys.argv[2]
    if not APP_PATTERN.fullmatch(app_name):
        raise DeploymentError("invalid application name")
    if not SHA_PATTERN.fullmatch(commit_sha):
        raise DeploymentError("commit SHA must contain exactly 40 lowercase hexadecimal characters")
    return app_name, commit_sha


def assert_secure_path(path, expected_type):
    path = Path(path)
    if not path.is_absolute():
        raise DeploymentError("security check failed for a non-absolute path")

    current = Path(path.anchor)
    for component in path.parts[1:]:
        current = current / component
        try:
            metadata = os.lstat(current)
        except FileNotFoundError as error:
            raise DeploymentError("required root-owned path does not exist") from error

        if stat.S_ISLNK(metadata.st_mode):
            raise DeploymentError("symbolic links are not allowed")
        if metadata.st_uid != 0:
            raise DeploymentError("configuration paths must be owned by root")
        if metadata.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
            raise DeploymentError("configuration paths must not be group/world writable")

    metadata = os.lstat(path)
    if expected_type == "file" and not stat.S_ISREG(metadata.st_mode):
        raise DeploymentError("expected a regular file")
    if expected_type == "directory" and not stat.S_ISDIR(metadata.st_mode):
        raise DeploymentError("expected a directory")


def read_secure_text(path):
    assert_secure_path(path, "file")
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(path, flags)
    with os.fdopen(descriptor, "r", encoding="utf-8") as handle:
        return handle.read()


def write_secure_text(path, content):
    path = Path(path)
    assert_secure_path(path.parent, "directory")
    try:
        destination_metadata = os.lstat(path)
    except FileNotFoundError:
        destination_metadata = None
    if destination_metadata is not None and stat.S_ISLNK(destination_metadata.st_mode):
        raise DeploymentError("symbolic links are not allowed for deployment state")

    descriptor, temporary_name = tempfile.mkstemp(prefix=".deploy-", dir=path.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, path)
        os.chown(path, 0, 0)
        os.chmod(path, 0o600)
    except Exception:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def copy_secure_file(source, destination, mode):
    content = read_secure_text(source)
    write_secure_text(destination, content)
    os.chmod(destination, mode)


def load_application(app_name):
    assert_secure_path(CONFIG_ROOT, "directory")
    app_directory = CONFIG_ROOT / app_name
    assert_secure_path(app_directory, "directory")

    config_path = app_directory / "deployment.json"
    try:
        config = json.loads(read_secure_text(config_path))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise DeploymentError("deployment.json is not valid JSON") from error

    if not isinstance(config, dict) or set(config) != CONFIG_KEYS:
        raise DeploymentError("deployment.json does not match the closed schema")

    for key in ("compose_file", "health_url", "repository", "service"):
        if not isinstance(config[key], str) or not config[key]:
            raise DeploymentError("deployment.json contains an invalid string field")

    if not isinstance(config["allowed_images"], list) or not all(
        isinstance(image, str) for image in config["allowed_images"]
    ):
        raise DeploymentError("allowed_images must be a JSON string array")

    compose_name = config["compose_file"]
    if Path(compose_name).name != compose_name or not re.fullmatch(
        r"[A-Za-z0-9][A-Za-z0-9._-]*\.ya?ml", compose_name
    ):
        raise DeploymentError("compose_file must be a simple YAML file name")

    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,62}", config["service"]):
        raise DeploymentError("service name is invalid")

    if not OCIR_REPOSITORY_PATTERN.fullmatch(config["repository"]):
        raise DeploymentError("repository is not a valid allowlisted OCIR repository")

    for image in config["allowed_images"]:
        if "@" not in image:
            raise DeploymentError("every auxiliary image must be pinned by digest")
        image_repository, digest = image.rsplit("@", 1)
        if not OCIR_REPOSITORY_PATTERN.fullmatch(image_repository) or not DIGEST_PATTERN.fullmatch(digest):
            raise DeploymentError("an auxiliary image is outside OCIR or has an invalid digest")

    health = urllib.parse.urlsplit(config["health_url"])
    if (
        health.scheme not in {"http", "https"}
        or not health.hostname
        or health.username
        or health.password
        or health.query
        or health.fragment
    ):
        raise DeploymentError("health_url must be a non-secret HTTP(S) URL without credentials or query data")

    compose_path = app_directory / compose_name
    assert_secure_path(compose_path, "file")
    return config, compose_path


def command_environment(image_uri=None):
    environment = {
        "DOCKER_CONFIG": "/root/.docker",
        "HOME": "/root",
        "LANG": "C.UTF-8",
        "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    }
    if image_uri is not None:
        environment["DEPLOY_IMAGE"] = image_uri
    return environment


def run_command(command, environment=None, timeout=300):
    try:
        result = subprocess.run(
            command,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            env=environment or command_environment(),
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise DeploymentError("an approved local operation could not be executed") from error

    if result.returncode != 0:
        raise DeploymentError("an approved local operation returned a non-zero status")
    return result.stdout


def render_compose(app_name, compose_path, env_path):
    output = run_command(
        [
            "docker",
            "compose",
            "--project-name",
            app_name,
            "--env-file",
            str(env_path),
            "-f",
            str(compose_path),
            "config",
            "--format",
            "json",
        ],
        timeout=60,
    )
    try:
        rendered = json.loads(output)
    except json.JSONDecodeError as error:
        raise DeploymentError("Docker Compose returned invalid normalized configuration") from error
    validate_compose(rendered, app_name)
    return rendered


def reject_unknown_keys(value, allowed, context):
    if not isinstance(value, dict):
        raise DeploymentError(f"{context} must be an object")
    unknown = set(value) - allowed
    if unknown:
        raise DeploymentError(f"{context} contains fields outside the allowlist")


def require_string_list(value, context):
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise DeploymentError(f"{context} must be a string array")


def require_scalar_map(value, context, allow_null=False):
    if not isinstance(value, dict):
        raise DeploymentError(f"{context} must be an object")
    allowed_types = (str, int, float, bool)
    for key, item in value.items():
        if not isinstance(key, str):
            raise DeploymentError(f"{context} keys must be strings")
        if item is None and allow_null:
            continue
        if not isinstance(item, allowed_types):
            raise DeploymentError(f"{context} values must be scalar")


def validate_compose(rendered, app_name):
    reject_unknown_keys(rendered, TOP_LEVEL_KEYS, "Compose document")
    if rendered.get("name") != app_name:
        raise DeploymentError("Compose project name does not match the allowlisted application")

    services = rendered.get("services")
    if not isinstance(services, dict) or not services:
        raise DeploymentError("Compose must define at least one service")

    networks = rendered.get("networks", {})
    if not isinstance(networks, dict):
        raise DeploymentError("networks must be an object")
    for network in networks.values():
        reject_unknown_keys(network or {}, NETWORK_KEYS, "network definition")
        if network and network.get("driver") not in (None, "bridge"):
            raise DeploymentError("only the bridge network driver is allowed")
        if network:
            for boolean_field in ("attachable", "enable_ipv4", "enable_ipv6", "external", "internal"):
                if boolean_field in network and not isinstance(network[boolean_field], bool):
                    raise DeploymentError(f"network {boolean_field} must be boolean")
            if "name" in network and not isinstance(network["name"], str):
                raise DeploymentError("network name must be a string")
        if network and "labels" in network:
            require_scalar_map(network["labels"], "network labels")

    volumes = rendered.get("volumes", {})
    if not isinstance(volumes, dict):
        raise DeploymentError("volumes must be an object")
    for volume in volumes.values():
        reject_unknown_keys(volume or {}, VOLUME_KEYS, "volume definition")
        if volume and "external" in volume and not isinstance(volume["external"], bool):
            raise DeploymentError("volume external must be boolean")
        if volume and "name" in volume and not isinstance(volume["name"], str):
            raise DeploymentError("volume name must be a string")
        if volume and "labels" in volume:
            require_scalar_map(volume["labels"], "volume labels")

    for service_name, service in services.items():
        if not isinstance(service_name, str):
            raise DeploymentError("service names must be strings")
        reject_unknown_keys(service, SERVICE_KEYS | FORBIDDEN_SERVICE_KEYS, "service")
        forbidden = set(service) & FORBIDDEN_SERVICE_KEYS
        if forbidden:
            raise DeploymentError("service contains a forbidden capability")
        reject_unknown_keys(service, SERVICE_KEYS, "service")

        image = service.get("image")
        if not isinstance(image, str) or not image:
            raise DeploymentError("every service must use an explicit image")

        for boolean_field in ("init", "read_only"):
            if boolean_field in service and not isinstance(service[boolean_field], bool):
                raise DeploymentError(f"{boolean_field} must be boolean")

        for string_field in (
            "hostname",
            "platform",
            "restart",
            "stop_grace_period",
            "stop_signal",
            "user",
            "working_dir",
        ):
            if string_field in service and not isinstance(service[string_field], str):
                raise DeploymentError(f"{string_field} must be a string")

        if "environment" in service:
            require_scalar_map(service["environment"], "environment", allow_null=True)
        if "labels" in service:
            require_scalar_map(service["labels"], "service labels")
        if "cap_drop" in service:
            require_string_list(service["cap_drop"], "cap_drop")
        if "tmpfs" in service:
            require_string_list(service["tmpfs"], "tmpfs")

        for command_field in ("command", "entrypoint"):
            if command_field in service:
                command_value = service[command_field]
                if not isinstance(command_value, (str, list)):
                    raise DeploymentError(f"{command_field} must be a string or array")
                if isinstance(command_value, list) and not all(
                    isinstance(item, str) for item in command_value
                ):
                    raise DeploymentError(f"{command_field} array must contain strings")

        expose = service.get("expose", [])
        if not isinstance(expose, list) or not all(isinstance(port, (str, int)) for port in expose):
            raise DeploymentError("expose must be a string/integer array")

        dependencies = service.get("depends_on", {})
        if not isinstance(dependencies, dict):
            raise DeploymentError("depends_on must be an object")
        for dependency_name, dependency in dependencies.items():
            if dependency_name not in services:
                raise DeploymentError("depends_on references an unknown service")
            reject_unknown_keys(dependency or {}, DEPENDENCY_KEYS, "dependency")

        healthcheck = service.get("healthcheck", {})
        reject_unknown_keys(healthcheck, HEALTHCHECK_KEYS, "healthcheck")
        if "test" in healthcheck and not isinstance(healthcheck["test"], (str, list)):
            raise DeploymentError("healthcheck test must be a string or array")
        if isinstance(healthcheck.get("test"), list):
            require_string_list(healthcheck["test"], "healthcheck test")
        if "disable" in healthcheck and not isinstance(healthcheck["disable"], bool):
            raise DeploymentError("healthcheck disable must be boolean")
        if "retries" in healthcheck and not isinstance(healthcheck["retries"], int):
            raise DeploymentError("healthcheck retries must be an integer")
        for duration_field in ("interval", "start_interval", "start_period", "timeout"):
            if duration_field in healthcheck and not isinstance(healthcheck[duration_field], str):
                raise DeploymentError(f"healthcheck {duration_field} must be a string")

        logging_config = service.get("logging", {})
        reject_unknown_keys(logging_config, LOGGING_KEYS, "logging")
        if "driver" in logging_config and not isinstance(logging_config["driver"], str):
            raise DeploymentError("logging driver must be a string")
        if "options" in logging_config:
            require_scalar_map(logging_config["options"], "logging options")

        service_networks = service.get("networks", {})
        if isinstance(service_networks, list):
            for network_name in service_networks:
                if network_name not in networks:
                    raise DeploymentError("service references an undeclared network")
        elif isinstance(service_networks, dict):
            for network_name, network_options in service_networks.items():
                if network_name not in networks:
                    raise DeploymentError("service references an undeclared network")
                reject_unknown_keys(network_options or {}, SERVICE_NETWORK_KEYS, "service network")
                if network_options and "aliases" in network_options:
                    require_string_list(network_options["aliases"], "network aliases")
                if network_options and "link_local_ips" in network_options:
                    require_string_list(network_options["link_local_ips"], "link-local IPs")
        else:
            raise DeploymentError("service networks must be a list or object")

        security_options = service.get("security_opt", [])
        if not isinstance(security_options, list) or any(
            option not in {"no-new-privileges", "no-new-privileges:true"}
            for option in security_options
        ):
            raise DeploymentError("only no-new-privileges is allowed in security_opt")

        mounts = service.get("volumes", [])
        if not isinstance(mounts, list):
            raise DeploymentError("service volumes must be a list")
        for mount in mounts:
            reject_unknown_keys(mount, MOUNT_KEYS, "volume mount")
            if mount.get("type") != "volume":
                raise DeploymentError("bind mounts and non-volume mounts are forbidden")
            if not isinstance(mount.get("source"), str) or mount.get("source") not in volumes:
                raise DeploymentError("volume mount references an undeclared named volume")
            target = mount.get("target")
            if not isinstance(target, str) or not target.startswith("/"):
                raise DeploymentError("volume target must be an absolute container path")
            if target in {"/", "/var/run/docker.sock", "/run/docker.sock"}:
                raise DeploymentError("sensitive volume targets are forbidden")
            if "read_only" in mount and not isinstance(mount["read_only"], bool):
                raise DeploymentError("volume read_only must be boolean")
            reject_unknown_keys(mount.get("volume", {}) or {}, MOUNT_VOLUME_KEYS, "volume options")


def validate_images(rendered, config, deployment_image):
    services = rendered["services"]
    target_service = config["service"]
    if target_service not in services:
        raise DeploymentError("the configured deployment service does not exist")
    if services[target_service]["image"] != deployment_image:
        raise DeploymentError("the deployment service image is not the server-constructed image")

    allowed_images = set(config["allowed_images"])
    for service_name, service in services.items():
        if service_name == target_service:
            continue
        if service["image"] not in allowed_images:
            raise DeploymentError("an auxiliary service image is not explicitly allowlisted")


def write_image_environment(path, image_uri):
    write_secure_text(path, f"DEPLOY_IMAGE={image_uri}\n")


def resolve_digest(repository, commit_sha):
    tag_uri = f"{repository}:{commit_sha}"
    LOGGER.info("stage=pull_commit_image")
    run_command(["docker", "pull", tag_uri], timeout=900)
    output = run_command(
        ["docker", "image", "inspect", tag_uri, "--format", "{{json .RepoDigests}}"],
        timeout=60,
    )
    try:
        digests = json.loads(output)
    except json.JSONDecodeError as error:
        raise DeploymentError("Docker returned invalid digest metadata") from error

    prefix = f"{repository}@"
    matches = [value for value in digests if isinstance(value, str) and value.startswith(prefix)]
    if len(matches) != 1 or not DIGEST_PATTERN.fullmatch(matches[0][len(prefix) :]):
        raise DeploymentError("the pulled image did not resolve to one authorized digest")
    return matches[0]


def compose_command(app_name, compose_path, env_path, operation):
    base = [
        "docker",
        "compose",
        "--project-name",
        app_name,
        "--env-file",
        str(env_path),
        "-f",
        str(compose_path),
    ]
    if operation == "pull":
        return base + ["pull"]
    if operation == "up":
        return base + ["up", "-d", "--remove-orphans", "--wait", "--wait-timeout", "120"]
    if operation == "down":
        return base + ["down"]
    raise DeploymentError("unsupported internal Compose operation")


def health_check(url):
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, request, file_pointer, code, message, headers, new_url):
            return None

    opener = urllib.request.build_opener(NoRedirect)
    for _ in range(24):
        try:
            request = urllib.request.Request(url, method="GET")
            with opener.open(request, timeout=10) as response:
                if 200 <= response.status < 300:
                    return True
        except Exception:
            pass
        time.sleep(5)
    return False


def restore_previous(app_name, work_directory, config):
    rollback_directory = work_directory / ".rollback"
    rollback_compose = rollback_directory / "compose.yaml"
    rollback_env = rollback_directory / ".env.deploy"
    current_compose = work_directory / "compose.yaml"
    current_env = work_directory / ".env.deploy"

    if rollback_compose.exists() and rollback_env.exists():
        LOGGER.warning("stage=rollback_start mode=previous_digest")
        assert_secure_path(rollback_directory, "directory")
        copy_secure_file(rollback_compose, current_compose, 0o640)
        copy_secure_file(rollback_env, current_env, 0o600)
        previous_image = read_secure_text(current_env).strip()
        prefix = "DEPLOY_IMAGE="
        if not previous_image.startswith(prefix):
            raise DeploymentError("rollback image metadata is invalid")
        previous_image = previous_image[len(prefix) :]
        if not previous_image.startswith(f"{config['repository']}@"):
            raise DeploymentError("rollback digest is outside the authorized repository")
        rendered = render_compose(app_name, current_compose, current_env)
        validate_images(rendered, config, previous_image)
        run_command(compose_command(app_name, current_compose, current_env, "up"), timeout=300)
        LOGGER.warning("stage=rollback_complete digest=%s", previous_image.rsplit("@", 1)[1])
        return

    LOGGER.warning("stage=rollback_start mode=stop_first_deployment")
    run_command(compose_command(app_name, current_compose, current_env, "down"), timeout=300)
    LOGGER.warning("stage=rollback_complete mode=stopped")


def deploy(app_name, commit_sha):
    config, source_compose = load_application(app_name)
    work_directory = WORK_ROOT / app_name
    work_directory.mkdir(mode=0o750, parents=False, exist_ok=True)
    os.chown(work_directory, 0, 0)
    os.chmod(work_directory, 0o750)
    assert_secure_path(work_directory, "directory")

    lock_path = WORK_ROOT / f".deploy-{app_name}.lock"
    lock_flags = os.O_CREAT | os.O_RDWR
    if hasattr(os, "O_NOFOLLOW"):
        lock_flags |= os.O_NOFOLLOW
    lock_descriptor = os.open(lock_path, lock_flags, 0o600)
    os.fchmod(lock_descriptor, 0o600)
    os.fchown(lock_descriptor, 0, 0)
    try:
        fcntl.flock(lock_descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError as error:
        os.close(lock_descriptor)
        raise DeploymentError("another deployment is already running for this application") from error

    candidate_compose = work_directory / ".compose.candidate.yaml"
    candidate_env = work_directory / ".env.candidate"
    current_compose = work_directory / "compose.yaml"
    current_env = work_directory / ".env.deploy"
    rollback_directory = work_directory / ".rollback"
    rollback_directory.mkdir(mode=0o700, exist_ok=True)
    os.chown(rollback_directory, 0, 0)
    os.chmod(rollback_directory, 0o700)
    assert_secure_path(rollback_directory, "directory")

    try:
        LOGGER.info("app=%s commit=%s stage=validation_start", app_name, commit_sha)
        copy_secure_file(source_compose, candidate_compose, 0o640)

        placeholder_digest = "sha256:" + ("0" * 64)
        placeholder_image = f"{config['repository']}@{placeholder_digest}"
        write_image_environment(candidate_env, placeholder_image)
        rendered = render_compose(app_name, candidate_compose, candidate_env)
        validate_images(rendered, config, placeholder_image)
        LOGGER.info("app=%s commit=%s stage=validation_complete", app_name, commit_sha)

        deployment_image = resolve_digest(config["repository"], commit_sha)
        digest = deployment_image.rsplit("@", 1)[1]
        write_image_environment(candidate_env, deployment_image)
        rendered = render_compose(app_name, candidate_compose, candidate_env)
        validate_images(rendered, config, deployment_image)
        LOGGER.info("app=%s commit=%s stage=digest_resolved digest=%s", app_name, commit_sha, digest)

        LOGGER.info("app=%s commit=%s stage=pull_digest", app_name, commit_sha)
        run_command(compose_command(app_name, candidate_compose, candidate_env, "pull"), timeout=900)

        if current_compose.exists() or current_env.exists():
            if not current_compose.exists() or not current_env.exists():
                raise DeploymentError("current deployment metadata is incomplete")
            copy_secure_file(current_compose, rollback_directory / "compose.yaml", 0o640)
            copy_secure_file(current_env, rollback_directory / ".env.deploy", 0o600)

        os.replace(candidate_compose, current_compose)
        os.replace(candidate_env, current_env)
        os.chown(current_compose, 0, 0)
        os.chown(current_env, 0, 0)
        os.chmod(current_compose, 0o640)
        os.chmod(current_env, 0o600)

        LOGGER.info("app=%s commit=%s stage=compose_up", app_name, commit_sha)
        try:
            run_command(compose_command(app_name, current_compose, current_env, "up"), timeout=300)
            if not health_check(config["health_url"]):
                raise DeploymentError("the configured health check did not become healthy")
        except DeploymentError:
            restore_previous(app_name, work_directory, config)
            raise

        LOGGER.info(
            "app=%s commit=%s stage=deployment_healthy digest=%s",
            app_name,
            commit_sha,
            digest,
        )
    finally:
        for candidate in (candidate_compose, candidate_env):
            try:
                candidate.unlink()
            except FileNotFoundError:
                pass
        fcntl.flock(lock_descriptor, fcntl.LOCK_UN)
        os.close(lock_descriptor)


def main():
    try:
        app_name, commit_sha = require_exact_arguments()
        assert_secure_path(WORK_ROOT, "directory")
        deploy(app_name, commit_sha)
    except DeploymentError as error:
        LOGGER.error("stage=deployment_failed reason=%s", str(error))
        return 1
    except Exception:
        LOGGER.error("stage=deployment_failed reason=unexpected_internal_error")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
