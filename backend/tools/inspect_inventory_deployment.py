"""Read-only catalog check. Never prints connection strings or exception details."""

import json
import os

import psycopg

from app.core.config import Settings


def main():
    settings = Settings()
    print(
        json.dumps(
            {
                "separate_test_configured": bool(
                    os.getenv("SUPABASE_TEST_DATABASE_URL")
                    and os.getenv("HOMECIRCLE_TEST_DB") == "hosted-test"
                )
            }
        )
    )
    try:
        with psycopg.connect(
            settings.database_url.get_secret_value(),
            sslmode="verify-full",
            sslrootcert=settings.database_sslrootcert,
            connect_timeout=10,
            options="-c default_transaction_read_only=on -c statement_timeout=10000",
        ) as connection:
            names = [
                "public.inventory_items",
                "public.inventory_categories",
                "public.inventory_activity",
                "private.inventory_uploads",
            ]
            for name in names:
                row = connection.execute("SELECT to_regclass(%s)::text", (name,)).fetchone()
                print(json.dumps({"relation": name, "exists": row[0] is not None}))
            row = connection.execute(
                "SELECT to_regprocedure('public.lock_inventory_household(uuid)')::text"
            ).fetchone()
            print(json.dumps({"inventory_access_helper_exists": row[0] is not None}))
            try:
                with connection.transaction():
                    rows = connection.execute(
                        "SELECT version FROM supabase_migrations.schema_migrations ORDER BY version"
                    ).fetchall()
                    print(json.dumps({"migration_versions": [r[0] for r in rows]}))
            except psycopg.errors.InsufficientPrivilege:
                print(json.dumps({"migration_history": "restricted role cannot read history"}))
    except psycopg.Error as error:
        message = str(error).lower()
        category = next(
            (
                label
                for term, label in [
                    ("certificate", "tls_certificate"),
                    ("password authentication", "credentials_rejected"),
                    ("timeout", "connection_timeout"),
                    ("resolve", "hostname_resolution"),
                    ("tenant or user", "pooler_identity"),
                ]
                if term in message
            ),
            "connection_unavailable",
        )
        print(
            json.dumps(
                {
                    "connection_check": "failed",
                    "error_type": type(error).__name__,
                    "category": category,
                }
            )
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
