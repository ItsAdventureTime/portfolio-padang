#!/usr/bin/env python3
"""Run the demo Compose stack against disposable Docker Sandbox state."""

import json
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PROJECT = f"padang-demo-check-{uuid.uuid4().hex}"

PROCESS_CHECK = r"""
found=false
for proc in /proc/[0-9]*; do
  if read -r comm < "$proc/comm" 2>/dev/null && [ "$comm" = "$1" ]; then
    cmdline=$(tr '\000' '\n' < "$proc/cmdline" 2>/dev/null) || continue
    environ=$(tr '\000' '\n' < "$proc/environ" 2>/dev/null) || continue
    if [ -n "$cmdline" ] && printf '%s\n' "$environ" | grep -q '^PGPASSFILE='; then
      for metadata in "$cmdline" "$environ"; do
        if printf '%s\n' "$metadata" | grep -Fqf /run/secrets/db-password; then
          echo "Database password found in process metadata" >&2
          exit 1
        fi
      done
      found=true
    fi
  fi
done
if [ "$found" != true ]; then
  echo "Job process is not visible yet" >&2
  exit 2
fi
"""


def run(command: list[str]) -> str:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        raise subprocess.CalledProcessError(result.returncode, command)
    return result.stdout


def run_job(compose: list[str], service: str, jobs: list[str]) -> None:
    profile = "migrate" if service == "migrate" else "demo-seed"
    process = "migrate" if service == "migrate" else "psql"
    container = run([*compose, "--profile", profile, "run", "--detach", "--no-deps", service]).strip()
    jobs.append(container)
    for _ in range(100):
        state = run(["docker", "inspect", "--format", "{{.State.Status}}", container]).strip()
        if state != "running":
            raise RuntimeError(f"{service} exited before its process metadata could be checked")
        check = subprocess.run(
            ["docker", "exec", container, "sh", "-ec", PROCESS_CHECK, "check-process", process],
            capture_output=True,
            text=True,
        )
        if check.returncode == 0:
            break
        if check.returncode != 2:
            raise RuntimeError(f"{service} process metadata check failed")
        time.sleep(0.05)
    else:
        raise RuntimeError(f"{service} process metadata check timed out")
    status = run(["docker", "wait", container]).strip()
    if status != "0":
        raise RuntimeError(f"{service} exited with status {status}")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="padang-demo-check-") as temp:
        secret = Path(temp, "db-password")
        secret.write_text("sandbox:test\\only\n")
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
        jobs: list[str] = []

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
            run_job(compose, "migrate", jobs)
            run_job(compose, "demo-seed", jobs)
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
            for container in jobs:
                removed = subprocess.run(["docker", "rm", "-f", container], capture_output=True, text=True)
                if removed.returncode:
                    cleanup_errors.append(f"job container removal failed: {removed.stderr.strip()}")
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
