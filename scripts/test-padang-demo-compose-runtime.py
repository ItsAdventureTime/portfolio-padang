#!/usr/bin/env python3
"""Run the demo Compose stack against disposable Docker Sandbox state."""

import json
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PROJECT = f"padang-demo-check-{uuid.uuid4().hex}"


def run(command: list[str]) -> str:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        raise subprocess.CalledProcessError(result.returncode, command)
    return result.stdout


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="padang-demo-check-") as temp:
        secret = Path(temp, "db-password")
        secret.write_text("sandbox-test-only\n")
        secret.chmod(0o644)
        override = Path(temp, "compose.override.yaml")
        override.write_text(
            "secrets:\n  db-password:\n    file: "
            + json.dumps(str(secret))
            + "\n"
        )
        compose = [
            "docker",
            "compose",
            "--project-name",
            PROJECT,
            "-f",
            str(ROOT / "compose.yaml"),
            "-f",
            str(override),
        ]
        volume = f"{PROJECT}_postgres-data"
        if volume in run(["docker", "volume", "ls", "--quiet", "--filter", f"name={volume}"]).splitlines():
            raise RuntimeError(f"Refusing to reuse existing test volume {volume}")
        if run(["docker", "ps", "--all", "--quiet", "--filter", f"label=com.docker.compose.project={PROJECT}"]):
            raise RuntimeError(f"Refusing to reuse existing test project {PROJECT}")

        network_created = False
        cleanup_errors: list[str] = []

        try:
            if subprocess.run(
                ["docker", "network", "inspect", "cloudflared-network"],
                capture_output=True,
                check=False,
            ).returncode != 0:
                run(["docker", "network", "create", "cloudflared-network"])
                network_created = True
            run([*compose, "config", "--quiet"])
            run([*compose, "up", "-d", "--wait", "--wait-timeout", "120", "db"])
            run([*compose, "--profile", "migrate", "run", "--rm", "migrate"])
            run([*compose, "--profile", "demo-seed", "run", "--rm", "demo-seed"])
            run([*compose, "up", "-d", "--wait", "--wait-timeout", "120", "api", "frontend", "gateway"])
            run([*compose, "exec", "-T", "-u", "postgres", "db", "sh", "-ec", "test -r /run/secrets/db-password"])
            run([*compose, "exec", "-T", "-u", "nobody", "api", "sh", "-ec", "test -r /run/secrets/db-password"])

            def get(path: str) -> str:
                return run([*compose, "exec", "-T", "gateway", "wget", "-qO-", f"http://127.0.0.1{path}"])

            health = json.loads(get("/api/v1/health"))
            assert health["status"] == "ok" and health["environment"] == "demo"
            assert "Padang" in get("/")
            assert "projects" in get("/api/v1/dashboard/summary")
            assert "Read-only register" in get("/projects")
        finally:
            down = subprocess.run([*compose, "down"], cwd=ROOT, capture_output=True, text=True)
            if down.returncode:
                cleanup_errors.append(f"compose down failed: {down.stderr.strip()}")
            volumes = subprocess.run(
                ["docker", "volume", "ls", "--quiet", "--filter", f"name={volume}"],
                capture_output=True,
                text=True,
            )
            if volumes.returncode:
                cleanup_errors.append(f"volume listing failed: {volumes.stderr.strip()}")
            elif volume in volumes.stdout.splitlines():
                removed = subprocess.run(["docker", "volume", "rm", volume], capture_output=True, text=True)
                if removed.returncode:
                    cleanup_errors.append(f"volume removal failed: {removed.stderr.strip()}")
            if network_created:
                removed = subprocess.run(
                    ["docker", "network", "rm", "cloudflared-network"],
                    capture_output=True,
                    text=True,
                )
                if removed.returncode:
                    cleanup_errors.append(f"network removal failed: {removed.stderr.strip()}")
            if cleanup_errors:
                message = "Runtime-test cleanup failed: " + "; ".join(cleanup_errors)
                if sys.exc_info()[0] is None:
                    raise RuntimeError(message)
                print(message, file=sys.stderr)

    print("Compose config, migration, seed, secret reads, gateway, dashboard data, and read-only UI passed.")


if __name__ == "__main__":
    main()
