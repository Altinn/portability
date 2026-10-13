#!/usr/bin/env python3
"""Write non-secret TF inputs and S3 partial backend config on a GitHub runner."""
import json
import os
from pathlib import Path

ROOT = Path("environments/internal-poc/correspondence/scaleway/terraform")
FORBIDDEN = {"project_id", "database_password", "redis_password", "application_secrets",
             "s3_access_key", "s3_secret_key"}

def build(env):
    config = json.loads(env.get("SCW_TFVARS_JSON") or "{}")
    if not isinstance(config, dict):
        raise ValueError("SCW_TFVARS_JSON must be a JSON object")
    if FORBIDDEN.intersection(config):
        raise ValueError("SCW_TFVARS_JSON contains reserved or secret variable names")
    project = env.get("SCW_DEFAULT_PROJECT_ID", "")
    bucket = env.get("SCW_STATE_BUCKET", "")
    if not project or not bucket:
        raise ValueError("Set SCW_PROJECT_ID and SCW_STATE_BUCKET as GitHub variables")
    config["project_id"] = project
    config.setdefault("region", "fr-par")
    config.setdefault("zone", config["region"] + "-1")
    config.setdefault("name_prefix", "altinn-corr-internal-poc")
    # Keep state region independent from compute region; bootstrap bucket does not move.
    state_region = env.get("SCW_STATE_REGION") or "fr-par"
    backend = {
        "bucket": bucket, "key": "internal-poc/correspondence/scaleway/terraform.tfstate",
        "region": state_region, "endpoints": {"s3": f"https://s3.{state_region}.scw.cloud"},
        "use_lockfile": True, "use_path_style": True,
        "skip_credentials_validation": True, "skip_region_validation": True,
        "skip_requesting_account_id": True, "skip_metadata_api_check": True,
        "skip_s3_checksum": True,
    }
    return config, backend

def main():
    config, backend = build(os.environ)
    if os.environ.get("TF_ACTION") == "destroy":
        if os.environ.get("DESTROY_CONFIRMATION") != config["name_prefix"]:
            raise ValueError("For destroy, confirmation must match name_prefix exactly")
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / ".ci.auto.tfvars.json").write_text(json.dumps(config, indent=2) + "\n")
    # -backend-config accepts JSON when given a .json configuration file.
    (ROOT / "backend.ci.json").write_text(json.dumps(backend, indent=2) + "\n")

if __name__ == "__main__":
    main()
