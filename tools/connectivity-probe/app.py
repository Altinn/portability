"""Authenticated-by-platform probe: / is liveness; /checks exercises data services."""

import json
import os
import tempfile
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import boto3
import psycopg
from botocore.config import Config


def check_postgres():
    ca = os.environ["POSTGRES_CA_PEM"]

    with tempfile.NamedTemporaryFile(mode="w", suffix=".pem") as certificate:
        certificate.write(ca)
        certificate.flush()

        with psycopg.connect(
            host=os.environ["POSTGRES_HOST"],
            port=os.environ["POSTGRES_PORT"],
            dbname=os.environ["POSTGRES_DATABASE"],
            user=os.environ["POSTGRES_USER"],
            password=os.environ["POSTGRES_PASSWORD"],
            sslmode="verify-ca",
            sslrootcert=certificate.name,
            connect_timeout=5,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                if cursor.fetchone() != (1,):
                    raise RuntimeError("Unexpected query result")

    # verify-ca validates the CA chain for the private IP.


def check_s3():
    client = boto3.client(
        "s3",
        endpoint_url=os.environ["S3_ENDPOINT"],
        region_name=os.environ["S3_REGION"],
        aws_access_key_id=os.environ["S3_ACCESS_KEY"],
        aws_secret_access_key=os.environ["S3_SECRET_KEY"],
        config=Config(
            signature_version="s3v4",
            connect_timeout=5,
            read_timeout=5,
            retries={"max_attempts": 1},
            s3={"addressing_style": "path"},
        ),
    )

    bucket = os.environ["S3_BUCKET"]
    key = "portability-probe/" + str(uuid.uuid4())
    version_id = None
    created = False

    try:
        result = client.put_object(Bucket=bucket, Key=key, Body=b"ok")
        version_id = result.get("VersionId")
        created = True

        args = {"Bucket": bucket, "Key": key}
        if version_id:
            args["VersionId"] = version_id

        result = client.get_object(**args)
        try:
            if result["Body"].read() != b"ok":
                raise RuntimeError("Unexpected object content")
        finally:
            result["Body"].close()
    finally:
        try:
            if created:
                args = {"Bucket": bucket, "Key": key}
                if version_id:
                    args["VersionId"] = version_id
                client.delete_object(**args)
        finally:
            client.close()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/health"):
            status = 200
            body = {"status": "running", "checks": "/checks"}

        elif self.path == "/checks":
            body = {}
            checks = (
                ("postgresql", check_postgres),
                ("object_storage", check_s3),
            )

            for name, check in checks:
                try:
                    check()
                    body[name] = {"status": "ok"}
                except Exception as error:
                    # Never expose credentials or exception messages.
                    body[name] = {
                        "status": "failed",
                        "error_type": type(error).__name__,
                    }

            status = (
                200
                if all(result["status"] == "ok" for result in body.values())
                else 503
            )

        else:
            status = 404
            body = {"error": "not_found"}

        encoded = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


if __name__ == "__main__":
    server = ThreadingHTTPServer(
        ("0.0.0.0", int(os.environ.get("PORT", "8080"))),
        Handler,
    )
    server.serve_forever()