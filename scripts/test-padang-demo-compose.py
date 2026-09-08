#!/usr/bin/env python3
"""Check the demo Compose isolation contract without starting services."""

import json
import subprocess
import sys


def compose_config(*profiles: str) -> dict:
    config = subprocess.run(
        ["docker", "compose", "-f", "compose.yaml", *profiles, "config", "--format", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(config.stdout)


def main() -> None:
    default = compose_config()
    assert "migrate" not in default["services"]
    assert "demo-seed" not in default["services"]

    compose = compose_config("--profile", "migrate", "--profile", "demo-seed")
    services = compose["services"]

    assert compose["networks"]["padang-network"]["internal"] is True
    assert compose["networks"]["cloudflared-network"]["external"] is True
    assert set(services["gateway"]["networks"]) == {"padang-network", "cloudflared-network"}
    for name, service in services.items():
        assert "ports" not in service, name
        assert "build" not in service, name
        assert "env_file" not in service, name
        if name != "gateway":
            assert set(service["networks"]) == {"padang-network"}, name
    for name in ("api", "frontend"):
        assert services[name]["image"].endswith(":manual")
        assert services[name]["pull_policy"] == "never"
    assert services["migrate"]["profiles"] == ["migrate"]
    assert services["demo-seed"]["profiles"] == ["demo-seed"]
    for name, command in (("migrate", "exec migrate"), ("demo-seed", "exec psql")):
        assert len(services[name]["command"]) == 1
        assert command in services[name]["command"][0]
        subprocess.run(["sh", "-n"], input=services[name]["command"][0].replace("$$", "$"), text=True, check=True)


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"padang demo Compose check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
