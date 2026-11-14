import argparse
import asyncio
import json
from datetime import timedelta

from psycopg.rows import dict_row
from psycopg_pool import AsyncConnectionPool
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class WorkerSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore", hide_input_in_errors=True)
    notification_worker_database_url: SecretStr
    database_sslrootcert: str = "certs/supabase-root-2021.pem"
    firebase_project_id: str


class FirebaseSender:
    def __init__(self, project):
        import firebase_admin

        self.app = firebase_admin.initialize_app(
            options={"projectId": project, "httpTimeout": 20}, name="homecircle-notifications"
        )

    async def send(self, payload):
        from firebase_admin import exceptions, messaging
        from google.auth.exceptions import DefaultCredentialsError

        # Lock-screen copy is deliberately generic. Never send private record titles,
        # bodies, tokens in data, chat text, or Storage capabilities to FCM.
        message = messaging.Message(
            fid=payload["token"],
            notification=messaging.Notification(
                title="HomeCircle", body="You have a household update."
            ),
            data={k: str(payload[k]) for k in ("notification_id", "household_id", "event_type")},
            android=messaging.AndroidConfig(
                priority="high",
                ttl=timedelta(hours=1),
                notification=messaging.AndroidNotification(
                    tag=str(payload["notification_id"]), channel_id="homecircle_updates"
                ),
            ),
        )
        try:
            await asyncio.to_thread(messaging.send, message, app=self.app)
            return "sent", None
        except messaging.UnregisteredError:
            return "invalid_token", "unregistered"
        except DefaultCredentialsError:
            return "permanent", "firebase_configuration"
        except messaging.SenderIdMismatchError:
            return "permanent", "sender_mismatch"
        except (
            messaging.QuotaExceededError,
            exceptions.UnavailableError,
            exceptions.InternalError,
            exceptions.ResourceExhaustedError,
            exceptions.DeadlineExceededError,
        ):
            return "retry", "transient_fcm"
        except exceptions.InvalidArgumentError:
            return "permanent", "invalid_argument"
        except (exceptions.PermissionDeniedError, exceptions.UnauthenticatedError):
            return "permanent", "firebase_configuration"
        except Exception:
            # No exception text: SDK errors may contain registration tokens.
            return "retry", "transport_or_unknown"


class JobStore:
    def __init__(self, pool):
        self.pool = pool

    async def claim(self):
        async with self.pool.connection() as c, c.transaction():
            return await (
                await c.execute("SELECT * FROM public.claim_notification_jobs(20)")
            ).fetchall()

    async def authorize(self, job, lease):
        async with self.pool.connection() as c, c.transaction():
            return (
                await (
                    await c.execute(
                        "SELECT public.authorize_notification_job(%s,%s) AS payload", (job, lease)
                    )
                ).fetchone()
            )["payload"]

    async def finish(self, job, lease, outcome, category):
        async with self.pool.connection() as c, c.transaction():
            return (
                await (
                    await c.execute(
                        "SELECT public.finish_notification_job(%s,%s,%s,%s) AS ok",
                        (job, lease, outcome, category),
                    )
                ).fetchone()
            )["ok"]


async def process_batch(store, sender):
    jobs = await store.claim()

    async def process(job):
        payload = await store.authorize(job["job_id"], job["lease"])
        if not payload:
            return "suppressed_or_stale"
        outcome, category = await sender.send(payload)
        accepted = await store.finish(job["job_id"], job["lease"], outcome, category)
        return outcome if accepted else "stale_acknowledgement"

    results = await asyncio.gather(*(process(job) for job in jobs))
    return {key: results.count(key) for key in set(results)}


async def run(once):
    settings = WorkerSettings()
    async with AsyncConnectionPool(
        settings.notification_worker_database_url.get_secret_value(),
        kwargs={
            "sslmode": "verify-full",
            "sslrootcert": settings.database_sslrootcert,
            "row_factory": dict_row,
            "prepare_threshold": None,
            "connect_timeout": 10,
        },
        min_size=1,
        max_size=5,
        open=False,
    ) as pool:
        async with pool.connection() as c:
            role = await (
                await c.execute(
                    "SELECT current_user AS name,rolsuper,rolbypassrls FROM pg_roles WHERE "
                    "rolname=current_user"
                )
            ).fetchone()
            if role["name"] != "homecircle_worker" or role["rolsuper"] or role["rolbypassrls"]:
                raise RuntimeError("A restricted homecircle_worker login is required")
        sender = FirebaseSender(settings.firebase_project_id)
        store = JobStore(pool)
        while True:
            try:
                print(
                    json.dumps({"delivery_results": await process_batch(store, sender)}), flush=True
                )
            except Exception:
                print(json.dumps({"worker": "retry_after_database_failure"}), flush=True)
                if once:
                    raise RuntimeError("Notification batch failed") from None
            if once:
                return
            await asyncio.sleep(10)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
    options = parser.parse_args()
    # Async Psycopg needs a selector loop on Windows, just like the existing API.
    from app.core.event_loop import create_event_loop

    try:
        with asyncio.Runner(loop_factory=create_event_loop) as runner:
            runner.run(run(options.once))
    except KeyboardInterrupt:
        pass
    except Exception as error:
        print(
            json.dumps({"worker": "startup_or_batch_failed", "category": type(error).__name__}),
            flush=True,
        )
        raise SystemExit(1) from None
