"""Start and test an isolated local Supabase stack using the pinned CLI."""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

from tests.database_target import LOCAL_TEST_MARKER, validate_local_test_target

ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = ROOT / ".tmp" / "homecircle-local-test"
CONFIG = ROOT / "backend" / "tests" / "local_supabase.toml"
CLI_VERSION = "3.1.0"
NETWORK = "homecircle-local-test"
DB_URL = "postgresql://postgres:postgres@127.0.0.1:55422/postgres"
DB_CONTAINER = "supabase_db_homecircle-test"


def prepare():
    destination = WORKSPACE / "supabase"
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(CONFIG, destination / "config.toml")
    migrations = destination / "migrations"
    migrations.mkdir(exist_ok=True)
    source_files = list((ROOT / "supabase" / "migrations").glob("*.sql"))
    expected = {path.name for path in source_files}
    if any(path.name not in expected for path in migrations.glob("*.sql")):
        raise RuntimeError("Test workspace has unexpected migrations. Review it before continuing.")
    for path in source_files:
        shutil.copyfile(path, migrations / path.name)
    print(f"Prepared {len(source_files)} migrations in {WORKSPACE}", flush=True)


def cli_command():
    if binary := os.environ.get("HOMECIRCLE_SUPABASE_CLI"):
        return [binary]
    npm = shutil.which("npx.cmd") or shutil.which("npx")
    if not npm:
        raise RuntimeError(
            "Install Node.js/npm or set HOMECIRCLE_SUPABASE_CLI to the CLI executable"
        )
    return [npm, "--yes", f"supabase@{CLI_VERSION}"]


def cli(arguments, *, capture=False):
    command = [*cli_command(), *arguments, "--workdir", str(WORKSPACE)]
    if capture:
        return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=True)
    log = ROOT / ".tmp" / "local-supabase-start.log"
    with log.open("a", encoding="utf-8") as output:
        result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f"Local Supabase command failed. See {log}")


def require_docker():
    docker = shutil.which("docker")
    if not docker and os.name == "nt":
        candidate = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / (
            "Docker/Docker/resources/bin/docker.exe"
        )
        if candidate.exists():
            docker = str(candidate)
    if not docker:
        raise RuntimeError("Install and start Docker Desktop before starting local Supabase")
    try:
        result = subprocess.run([docker, "info"], capture_output=True, text=True, timeout=20)
    except subprocess.TimeoutExpired:
        raise RuntimeError(
            "Docker engine did not respond. Check Docker Desktop and Windows restart"
        ) from None
    if result.returncode:
        raise RuntimeError("Docker engine is unavailable. Start Docker Desktop and check WSL setup")
    environment_path = os.environ.get("PATH", "")
    os.environ["PATH"] = str(Path(docker).parent) + os.pathsep + environment_path
    return docker


def ensure_network(docker):
    result = subprocess.run(
        [docker, "network", "inspect", NETWORK],
        capture_output=True,
        text=True,
    )
    if result.returncode:
        subprocess.run(
            [
                docker,
                "network",
                "create",
                "--driver",
                "bridge",
                "--opt",
                "com.docker.network.bridge.host_binding_ipv4=127.0.0.1",
                NETWORK,
            ],
            check=True,
            capture_output=True,
        )
        return
    network = json.loads(result.stdout)[0]
    if network.get("Options", {}).get("com.docker.network.bridge.host_binding_ipv4") != "127.0.0.1":
        raise RuntimeError("Existing test network does not restrict published ports to loopback")


def mark_database(docker):
    status = json.loads(cli(["status", "--output", "json"], capture=True).stdout)
    if status.get("DB_URL") != DB_URL:
        raise RuntimeError("CLI reported an unexpected local database URL")
    validate_local_test_target(DB_URL, "test")
    with psycopg.connect(
        DB_URL,
        sslmode="disable",
        hostaddr="127.0.0.1",
        connect_timeout=10,
        row_factory=dict_row,
    ) as connection:
        row = connection.execute(
            "SELECT current_database() AS database, current_user AS role"
        ).fetchone()
        if row != {"database": "postgres", "role": "postgres"}:
            raise RuntimeError("Unexpected local database identity")
    # Current local images do not make `postgres` a superuser, so the marker and the
    # test role switching are configured as the container's local admin role.
    # Fixed database, marker and role values belong only to this dedicated local stack.
    local_admin_sql(
        docker,
        f"ALTER DATABASE postgres SET homecircle.test_instance = '{LOCAL_TEST_MARKER}'",
    )
    # Integration tests SET ROLE into the restricted app roles; grant SET only.
    local_admin_sql(
        docker, "GRANT homecircle_api, homecircle_worker TO postgres WITH SET TRUE, INHERIT FALSE"
    )


def local_admin_sql(docker, statement):
    subprocess.run(
        [
            docker,
            "exec",
            DB_CONTAINER,
            "psql",
            "-U",
            "supabase_admin",
            "-d",
            "postgres",
            "-v",
            "ON_ERROR_STOP=1",
            "-qc",
            statement,
        ],
        check=True,
        capture_output=True,
    )


def verify_port_bindings(docker):
    network = json.loads(
        subprocess.run(
            [docker, "network", "inspect", NETWORK],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    )[0]
    containers = list(network.get("Containers", {}))
    if not containers:
        raise RuntimeError("Dedicated Docker network has no running Supabase containers")
    descriptions = json.loads(
        subprocess.run(
            [docker, "inspect", *containers],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    )
    for container in descriptions:
        bindings = container.get("NetworkSettings", {}).get("Ports", {})
        for addresses in bindings.values():
            if any(
                address.get("HostIp") not in ("127.0.0.1", "::1") for address in addresses or []
            ):
                cli(["stop"])
                raise RuntimeError(
                    "Stopped local test stack because a port was exposed beyond loopback"
                )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    options = parser.add_mutually_exclusive_group()
    options.add_argument("--prepare-only", action="store_true")
    options.add_argument("--test-only", action="store_true")
    options.add_argument("--stop", action="store_true")
    args = parser.parse_args()
    prepare()
    if args.prepare_only:
        return 0
    docker = require_docker()
    version = subprocess.run(
        [*cli_command(), "--version"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    if version != CLI_VERSION:
        raise RuntimeError(f"Local integration runner requires Supabase CLI {CLI_VERSION}")
    if args.stop:
        cli(["stop"])
        print("Stopped the local test stack. Its data volumes are retained.")
        return 0
    if not args.test_only:
        ensure_network(docker)
        print("Starting dedicated local Supabase services...", flush=True)
        cli(["start", "--network-id", NETWORK])
    verify_port_bindings(docker)
    if not args.test_only:
        # CLI 3.1 defaults db push to the local workspace. No remote/link flags are used.
        cli(["db", "push"])
        mark_database(docker)
    environment = os.environ.copy()
    environment.update(
        {
            "APP_ENV": "test",
            "HOMECIRCLE_TEST_DB": "local-test",
            "SUPABASE_TEST_DATABASE_URL": DB_URL,
        }
    )
    print("Running guarded integration tests on 127.0.0.1:55422...", flush=True)
    return subprocess.run(
        [sys.executable, "-m", "pytest", "-m", "integration", "-q"],
        cwd=ROOT / "backend",
        env=environment,
    ).returncode


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, subprocess.CalledProcessError, psycopg.Error) as error:
        # Keep CLI status/connection output private. It may contain local credentials.
        message = str(error) if isinstance(error, RuntimeError) else type(error).__name__
        print(f"Local test setup stopped: {message}", file=sys.stderr)
        raise SystemExit(1) from None
