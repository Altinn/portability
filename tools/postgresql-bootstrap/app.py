"""Fixed PostgreSQL bootstrap actions; invocation auth is enforced by Scaleway.

POST /extensions installs a fixed set of extensions. No arbitrary SQL, database
names, credentials or extension names are accepted from HTTP callers.
Health checks never connect to or mutate the database.
"""

import json
import os
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psycopg
from psycopg import sql


APPLICATION_EXTENSIONS = ("uuid-ossp", "hstore", "pg_stat_statements", "pgaudit")
CRON_EXTENSIONS = ("pg_cron",)
LOCK_ID = 1935762801
LOCAL_LOCK = threading.Lock()


class PrerequisiteError(Exception):
    def __init__(self, category):
        self.category = category


def connect(database, certificate_path):
    return psycopg.connect(
        host=os.environ["POSTGRES_HOST"],
        port=int(os.environ["POSTGRES_PORT"]),
        dbname=database,
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        sslmode="verify-ca",
        sslrootcert=certificate_path,
        connect_timeout=10,
        autocommit=True,
        options="-c statement_timeout=60000 -c lock_timeout=10000",
    )


def ensure_extensions(connection, names):
    """Use a static allowlist and quote identifiers, even for known names."""
    if any(name not in APPLICATION_EXTENSIONS + CRON_EXTENSIONS for name in names):
        raise PrerequisiteError("unsupported_extension")

    with connection.cursor() as cursor:
        cursor.execute("SELECT name FROM pg_available_extensions")
        available = {row[0] for row in cursor.fetchall()}
        if not set(names).issubset(available):
            raise PrerequisiteError("extension_unavailable")

        cursor.execute("SHOW shared_preload_libraries")
        preloaded = {name.strip().strip('"') for name in cursor.fetchone()[0].split(",")}
        for name in ("pg_stat_statements", "pgaudit", "pg_cron"):
            if name in names and name not in preloaded:
                raise PrerequisiteError(name + "_not_preloaded")

        for name in names:
            cursor.execute(
                sql.SQL("CREATE EXTENSION IF NOT EXISTS {}").format(sql.Identifier(name))
            )

        cursor.execute("SELECT extname, extversion FROM pg_extension")
        installed = dict(cursor.fetchall())
        if not set(names).issubset(installed):
            raise PrerequisiteError("extension_verification_failed")
        return {name: installed[name] for name in names}


def install_extensions():
    database = os.environ["POSTGRES_DATABASE"]
    if database == "rdb":
        raise PrerequisiteError("application_database_must_differ_from_rdb")

    with tempfile.NamedTemporaryFile(mode="w", suffix=".pem") as certificate:
        certificate.write(os.environ["POSTGRES_CA_PEM"])
        certificate.flush()

        # Session lock serializes operations across replicas/restarts as well as
        # threads. Disconnect releases the lock, including on failure.
        with connect("rdb", certificate.name) as control:
            with control.cursor() as cursor:
                cursor.execute("SELECT pg_try_advisory_lock(%s)", (LOCK_ID,))
                if not cursor.fetchone()[0]:
                    raise PrerequisiteError("bootstrap_already_running")

            with connect(database, certificate.name) as application:
                installed = ensure_extensions(application, APPLICATION_EXTENSIONS)
            cron = ensure_extensions(control, CRON_EXTENSIONS)

    return {"status": "ok", "application_extensions": installed, "rdb_extensions": cron}


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, body):
        data = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/health"):
            self.reply(200, {"status": "running"})
        else:
            self.reply(404, {"error": "not_found"})

    def do_POST(self):
        if self.path != "/extensions":
            self.reply(404, {"error": "not_found"})
            return
        # Only a body-less call is allowed; the endpoint is a fixed operation.
        if self.headers.get("Content-Length", "0") != "0" or self.headers.get("Transfer-Encoding"):
            self.reply(400, {"error": "request_body_not_supported"})
            return
        if not LOCAL_LOCK.acquire(blocking=False):
            self.reply(409, {"status": "failed", "error": "bootstrap_already_running"})
            return
        try:
            self.reply(200, install_extensions())
        except PrerequisiteError as error:
            self.reply(503, {"status": "failed", "error": error.category})
        except Exception as error:
            # Do not expose exception messages or connection strings.
            category = "permission_denied" if getattr(error, "sqlstate", None) == "42501" else "database_operation_failed"
            self.reply(503, {"status": "failed", "error": category, "error_type": type(error).__name__})
        finally:
            LOCAL_LOCK.release()


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), Handler).serve_forever()
