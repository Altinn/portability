# Scaleway Internal PoC – Deployment Runbook

> **Scope**
>
> This runbook describes the deployment procedure for the **Altinn Correspondence internal PoC on Scaleway** using the current Terraform and GitHub Actions structure.
>
> The PoC supports:
>
> - **Scaleway Serverless Container** as the existing baseline runtime.
> - **Scaleway Kapsule / Kubernetes** as a parallel runtime extension.
>
> Kubernetes does **not** replace the Serverless Container in the current root configuration. Both can exist at the same time and use the same Correspondence image and shared backend services.
>
> **Verification basis:** this runbook has been checked against the current repository Terraform root, all Scaleway modules, all seven GitHub workflows, CI helper scripts, probe/bootstrap code, the committed provider lock file, and current Scaleway documentation. Where repository documentation conflicts with executable code, the executable Terraform/workflow behavior is treated as the source of truth.

---

## 1. Deployment sequence

Use the following order for a new PoC environment:

```text
1. Bootstrap the Terraform state bucket
2. Configure the GitHub Environment
3. Configure GitHub variables and secrets
4. Deploy shared infrastructure + initial smoke container
5. Configure the Registry endpoint
6. Optionally run the connectivity probe
7. Build and deploy the PostgreSQL bootstrap image
8. Configure required PostgreSQL extensions
9. Build the Correspondence image
10. Deploy Correspondence to Serverless Container
11. Verify the Serverless baseline
12. Enable Kubernetes configuration
13. Deploy the Kubernetes Private Network, Kapsule cluster and node pool
14. Deploy the Kubernetes application resources
15. Verify pod, Service, Load Balancer and /health
16. Run the intended functional Correspondence test
17. Run a final full Terraform plan
```

> **Current repository behavior**
>
> The current GitHub Terraform workflow exposes these actions only:
>
> ```text
> plan
> apply-kubernetes-cluster
> apply
> destroy
> ```
>
> There are no dedicated `apply-common` or `apply-container` workflow actions.
>
> The root Terraform configuration also always contains the Serverless Container module. Therefore the normal GitHub deployment path creates the shared infrastructure together with an initial smoke container. The container is then changed from smoke mode to Correspondence mode in a later full apply.

---

# 2. Repository locations

The main Scaleway PoC files are located under:

```text
cloud-providers/scaleway/terraform/
├── bootstrap/state
└── modules/
    ├── container-registry
    ├── kubernetes-application
    ├── kubernetes-cluster
    ├── object-storage
    ├── postgresql
    ├── private-network
    ├── redis
    ├── secret-manager
    ├── serverless-container
    └── serverless-job

environments/internal-poc/correspondence/scaleway/terraform/

.github/workflows/
├── scaleway-build-correspondence.yml
├── scaleway-build-postgresql-bootstrap.yml
├── scaleway-build-probe.yml
├── scaleway-configure-postgresql-extensions.yml
├── scaleway-connectivity.yml
├── scaleway-test-connectivity.yml
└── scaleway-terraform.yml
```

Main Terraform root:

```text
environments/internal-poc/correspondence/scaleway/terraform
```

Main infrastructure workflow:

```text
.github/workflows/scaleway-terraform.yml
```

---

# 3. Current target architecture

The current PoC is intentionally small:

```text
                         Internet / test clients
                                  |
                     +------------+------------+
                     |                         |
                     v                         v
          Serverless Container        Scaleway Load Balancer
                     |                         |
                     |                         v
                     |                 Kubernetes Service
                     |                    port 80
                     |                         |
                     |                         v
                     |                 Correspondence pod
                     |                    port 2525
                     |                         |
          +----------+-------------------------+-----------+
          |                    Scaleway VPC                |
          |                                                 |
          | PN A: 10.20.0.0/24       PN B: 10.21.0.0/22  |
          |                                                 |
          | PostgreSQL 17             Kapsule cluster       |
          | Redis 8.6.6               1 x DEV1-M worker     |
          |                           1 x Correspondence pod |
          |                                                 |
          +-------------------- VPC routing ----------------+
                                    |
                       Object Storage S3 endpoint
```

Current important values:

| Setting | Current PoC value |
|---|---|
| Compute region | `pl-waw` |
| Primary zone | `pl-waw-1` |
| Existing Private Network | `10.20.0.0/24` |
| Kubernetes Private Network | `10.21.0.0/22` |
| Kubernetes service | Kapsule |
| Kubernetes node type | `DEV1-M` |
| Worker nodes | `1` |
| Correspondence replicas | `1` |
| Kubernetes namespace | `correspondence` |
| Public LoadBalancer port | `80` |
| Correspondence container port | `2525` |
| CNI | Cilium |

The Kubernetes `/22` network is currently hard-coded in the environment root:

```hcl
cidr = "10.21.0.0/22"
```

It is not currently exposed as a `SCW_TFVARS_JSON` variable.

The `/22` is intentional. Scaleway Kapsule automatically allocates a `/22` subnet from the attached Private Network. The original `/24` network was therefore too small for Kapsule.

The two Private Networks are in the **same routed VPC**, allowing Kubernetes to reach PostgreSQL and Redis through VPC routing.

---

# 4. Important current-repository rules

These rules are important because several older comments and summaries in the repository still describe the previous runtime model.

## 4.1 `enable_kubernetes` is the active runtime extension switch

Use:

```json
"enable_kubernetes": true
```

to add Kubernetes.

The current environment root always deploys Serverless Container.

The variable:

```text
application_runtime
```

still exists in `variables.tf`, `terraform.tfvars`, README text and the Correspondence build summary, but it is **not used to select the runtime in the current `main.tf`**.

Do not use:

```json
"application_runtime": "kubernetes"
```

as the deployment switch.

It has no runtime-selection effect in the current root.

## 4.2 Current build-workflow summary contains legacy guidance

`scaleway-build-correspondence.yml` currently prints examples using:

```text
application_runtime
```

That output is stale relative to the current parallel-runtime Terraform model.

Use:

```text
enable_kubernetes
```

instead.

## 4.3 Current Terraform workflow requires the Registry pull secret early

The current `scaleway-terraform.yml` checks `POC_REGISTRY_PULL_SECRET` for:

```text
plan
apply
apply-kubernetes-cluster
```

even when:

```json
"enable_kubernetes": false
```

Terraform itself only requires the Registry pull secret when Kubernetes is enabled with a non-smoke private image, but the **current workflow is stricter**.

Therefore, with the workflow as it exists today:

> Configure `POC_REGISTRY_PULL_SECRET` before the first normal `plan` or `apply`.

Alternatively, the workflow can later be improved so that this check is conditional on `enable_kubernetes`.

## 4.4 Explicitly configure the Warsaw region

The Terraform root defaults to Warsaw, but `tools/ci/write-config.py` currently applies this CI default when `region` is missing:

```text
fr-par
```

Therefore every GitHub deployment must explicitly include:

```json
"region": "pl-waw",
"zone": "pl-waw-1"
```

Do not rely on the Terraform variable default when using GitHub Actions.

---

# 5. Prerequisites

Before deployment, confirm:

- A Digdir-owned Scaleway Organization exists.
- A Digdir-owned Scaleway Project exists.
- Billing is owned by Digdir.
- A Terraform automation IAM application/API key exists.
- The Terraform identity can provision the required Scaleway resources.
- The current image build workflows can push to Container Registry.
- A separate runtime S3 key exists for the attachment bucket.
- A dedicated Registry read credential exists for Kubernetes.
- GitHub Environment `scaleway-internal-poc` exists.
- Terraform `1.13.5` is used for parity with GitHub Actions.

The Terraform code itself allows:

```text
>= 1.13.0, < 2.0.0
```

but the workflows are pinned to:

```text
1.13.5
```

The current Terraform root pins these providers:

```text
scaleway/scaleway   = 2.86.0
hashicorp/kubernetes = 3.3.0
```

Keep the root `.terraform.lock.hcl` synchronized with both providers. The current repository snapshot requires the Kubernetes provider in `versions.tf`; if the committed lock file does not contain `hashicorp/kubernetes`, regenerate the lock file with Terraform 1.13.5 and commit it before relying on workflows that use `terraform init -lockfile=readonly`.

Recommended IAM separation:

| Identity | Purpose |
|---|---|
| Terraform automation | Provision Scaleway infrastructure |
| Kubernetes Registry reader | Pull private images from Kapsule |
| Runtime S3 identity | Attachment bucket object read/write/delete, including deletion of a specific object version |
| Terraform state identity | Optional dedicated state bucket access |

Suggested Kubernetes Registry reader application name:

```text
altinn-corr-internal-poc-k8s-registry-reader
```

Use least-privilege Registry read/pull permissions.

> **Current implementation note**
>
> The image build workflows currently use `SCW_SECRET_KEY` for Docker Registry login and push. If strict IAM separation is required for build/push, introduce a separate Registry push credential and update the build workflows.

For the attachment runtime key, the connectivity probe requires enough Object Storage access to:

```text
PutObject
GetObject
DeleteObject
DeleteObjectVersion
```

The exact IAM policy should be scoped as narrowly as Scaleway IAM permits for the PoC project/bucket.

---

# 6. Bootstrap Terraform remote state

The remote state bucket must exist before the main Terraform root is initialized.

Bootstrap root:

```text
cloud-providers/scaleway/terraform/bootstrap/state
```

The bootstrap intentionally uses **local Terraform state**.

## 6.1 Configure local credentials

Export:

```bash
export SCW_ACCESS_KEY="<access-key>"
export SCW_SECRET_KEY="<secret-key>"
export SCW_DEFAULT_ORGANIZATION_ID="<organization-id>"
```

Copy:

```text
cloud-providers/scaleway/terraform/bootstrap/state/terraform.tfvars.example
```

to:

```text
cloud-providers/scaleway/terraform/bootstrap/state/terraform.tfvars
```

Example:

```hcl
project_id  = "<SCW_PROJECT_ID>"
region      = "fr-par"
zone        = "fr-par-1"
bucket_name = "<globally-unique-state-bucket-name>"
```

The state bucket is intentionally independent of the Warsaw compute region.

## 6.2 Create the state bucket

From:

```text
cloud-providers/scaleway/terraform/bootstrap/state
```

run:

```bash
terraform init
terraform plan
terraform apply
terraform output
```

Record:

```text
bucket_name
s3_endpoint
```

The bucket has:

```text
versioning = enabled
prevent_destroy = true
force_destroy = false
```

Preserve the bootstrap `terraform.tfstate` securely outside Git.

Do not destroy the bootstrap root as part of normal PoC cleanup.

## 6.3 Backend permissions

The identity used for Terraform state must have the required S3-compatible permissions for:

```text
bucket list
state object get/put
Terraform lockfile get/put/delete
```

The main backend key is:

```text
internal-poc/correspondence/scaleway/terraform.tfstate
```

---

# 7. Configure the GitHub Environment

Create:

```text
scaleway-internal-poc
```

Recommended controls:

- Restrict deployments to the default branch.
- Use required reviewers if required by policy.
- Store sensitive values as Environment Secrets.
- Store only non-sensitive values as Environment Variables.

The main Terraform deployment job only runs when manually dispatched from the repository default branch.

Pull requests and pushes execute validation/test jobs but do not execute cloud deployment.

---

# 8. GitHub Environment variables

Configure:

| Variable | Current requirement | Purpose |
|---|---|---|
| `SCW_ORGANIZATION_ID` | Required | Digdir Scaleway Organization UUID |
| `SCW_PROJECT_ID` | Required | Digdir Scaleway Project UUID |
| `SCW_STATE_BUCKET` | Required | Existing Terraform state bucket |
| `SCW_STATE_REGION` | Optional | Defaults to `fr-par` |
| `SCW_TFVARS_JSON` | Required for real deployment | Non-sensitive Terraform input |
| `SCW_REGISTRY_ENDPOINT` | Required after Registry creation for image builds | Warsaw Registry endpoint |
| `SCW_POSTGRES_BOOTSTRAP_IMAGE` | Optional | Enables the PostgreSQL bootstrap runtime |
| `SCW_CONTAINER_ENDPOINT` | Optional | Used by the connectivity-test workflow |

Example Registry endpoint:

```text
rg.pl-waw.scw.cloud/altinn-corr-internal-poc-registry
```

Do not include:

```text
https://
```

---

# 9. GitHub Environment secrets

Configure:

| Secret | Current requirement | Purpose |
|---|---|---|
| `SCW_ACCESS_KEY` | Required | Terraform automation access key |
| `SCW_SECRET_KEY` | Required | Terraform automation secret key; currently also used by build workflows |
| `POC_DATABASE_PASSWORD` | Required | PostgreSQL password |
| `POC_REDIS_PASSWORD` | Required | Redis password |
| `POC_S3_ACCESS_KEY` | Required for `connectivity` / `correspondence` | Dedicated attachment-bucket runtime key |
| `POC_S3_SECRET_KEY` | Required for `connectivity` / `correspondence` | Matching S3 runtime secret |
| `POC_APPLICATION_SECRETS_JSON` | Required for `correspondence` | TT02/application secrets |
| `POC_REGISTRY_PULL_SECRET` | Required by current `plan/apply` workflow | Kapsule private Registry image pull secret |
| `SCW_STATE_ACCESS_KEY` | Optional | Dedicated Terraform state key |
| `SCW_STATE_SECRET_KEY` | Optional | Dedicated Terraform state secret |

If dedicated state credentials are absent, the workflow uses:

```text
SCW_ACCESS_KEY
SCW_SECRET_KEY
```

for the S3-compatible Terraform backend.

## 9.1 Database and Redis password format

Both passwords are validated by Terraform.

Use 16–128 characters containing:

```text
at least one uppercase letter
at least one lowercase letter
at least one digit
at least one "_" or "-"
```

Only these characters are accepted:

```text
A-Z
a-z
0-9
_
-
```

---

# 10. SCW_TFVARS_JSON rules

`SCW_TFVARS_JSON` is written to `.ci.auto.tfvars.json` by:

```text
tools/ci/write-config.py
```

It must contain only **non-sensitive** Terraform configuration.

Do not put any of the following keys in `SCW_TFVARS_JSON`:

```text
project_id
database_password
redis_password
application_secrets
s3_access_key
s3_secret_key
registry_pull_secret
```

The CI helper rejects those keys.

`project_id` is injected from:

```text
SCW_PROJECT_ID
```

Sensitive values are injected through `TF_VAR_*` environment variables.

---

# 11. Application secrets

`POC_APPLICATION_SECRETS_JSON` should contain the TT02/integration values required by Correspondence.

The **minimum clean application-specific set** used by the current Terraform guard is:

```json
{
  "MaskinportenSettings__ClientId": "<value>",
  "MaskinportenSettings__EncodedJwk": "<value>",
  "AltinnOptions__PlatformSubscriptionKey": "<value>",
  "AltinnOptions__AccessManagementSubscriptionKey": "<value>",
  "AltinnIdProviderSettings__ClientId": "<value>",
  "AltinnIdProviderSettings__ClientSecret": "<value>",
  "GeneralSettings__CorrespondenceBaseUrl": "<value>"
}
```

The keys in `POC_APPLICATION_SECRETS_JSON` must **exactly match** `application_secret_names`.

```json
"application_secret_names": [
  "MaskinportenSettings__ClientId",
  "MaskinportenSettings__EncodedJwk",
  "AltinnOptions__PlatformSubscriptionKey",
  "AltinnOptions__AccessManagementSubscriptionKey",
  "AltinnIdProviderSettings__ClientId",
  "AltinnIdProviderSettings__ClientSecret",
  "GeneralSettings__CorrespondenceBaseUrl"
]
```

Terraform generates/injects the following separately:

```text
DatabaseOptions__ConnectionString
DatabaseOptions__SslRootCertificatePem
GeneralSettings__RedisConnectionString
GeneralSettings__RedisCaPem
AttachmentStorageOptions__S3AccessKey
AttachmentStorageOptions__S3SecretKey
AttachmentStorageOptions__S3Endpoint
AttachmentStorageOptions__S3Bucket
AttachmentStorageOptions__S3Region
```

Do not duplicate these generated values in `POC_APPLICATION_SECRETS_JSON` unless there is an intentional reason to override them.

This is important because `runtime_secret_environment_variables` is built with Terraform `merge(...)` and `var.application_secrets` is merged **last**. Therefore, if `POC_APPLICATION_SECRETS_JSON` contains keys such as:

```text
DatabaseOptions__SslRootCertificatePem
GeneralSettings__RedisConnectionString
GeneralSettings__RedisCaPem
AttachmentStorageOptions__S3AccessKey
AttachmentStorageOptions__S3SecretKey
```

those manually supplied values override the values generated from the currently deployed PostgreSQL, Redis and S3 resources. Stale values can therefore silently break a later deployment.

If an existing GitHub secret still contains an older, larger key set, either:

1. keep `application_secret_names` exactly synchronized with that JSON, or preferably
2. remove the redundant generated keys from both the JSON secret and `application_secret_names`, leaving the application-specific integration secrets only.


When reducing `application_secret_names`, expect Terraform to remove the corresponding **Scaleway Secret Manager resources**, because that same name set also drives `module.secrets`. This does not remove the generated runtime values from the Serverless/Kubernetes configuration, but the plan should be reviewed so the Secret Manager cleanup is intentional.

---

# 12. Phase A – Deploy shared infrastructure

## 12.1 What is shared

Shared resources are:

```text
VPC
Private Network A
PostgreSQL
Redis
Object Storage
Secret Manager
Container Registry
```

> **Secret Manager behavior**
>
> The current Serverless Container and Kubernetes runtimes do **not** resolve their runtime values directly from Scaleway Secret Manager. Terraform writes selected secret versions to Secret Manager, but it also injects the sensitive values directly into the Serverless Container and into a Kubernetes `Secret`.
>
> Changing a Secret Manager value manually is therefore **not** a runtime configuration update. Runtime changes should be made through the GitHub secret/Terraform flow and applied again.

## 12.2 Current supported GitHub deployment behavior

The current Terraform root also always contains:

```text
module.application
```

for Serverless Container.

Therefore the supported first GitHub deployment is:

> Shared infrastructure **plus an initial smoke Serverless Container**.

This is the safest deployment path with the current repository.

There is no `apply-common` workflow action today.

## 12.3 Initial SCW_TFVARS_JSON

Use:

```json
{
  "region": "pl-waw",
  "zone": "pl-waw-1",
  "name_prefix": "altinn-corr-internal-poc",
  "redis_version": "8.6.6",
  "container_mode": "smoke",
  "container_privacy": "private",
  "min_scale": 0,
  "enable_kubernetes": false
}
```

`redis_version` must be a currently available patched version in `pl-waw-1`.

The value above reflects the PoC configuration used during the Kubernetes extension. Verify version availability before creating a new environment in the future.

## 12.4 Run Terraform plan

From GitHub:

```text
Actions
  → Scaleway Terraform
  → Run workflow
  → action: plan
```

Review the plan carefully.

For a new environment, expect resources for:

```text
VPC
Private Network
PostgreSQL
Redis
Object Storage
Secret Manager
Container Registry
Serverless Container namespace
Serverless smoke container
```

Then run:

```text
Actions
  → Scaleway Terraform
  → Run workflow
  → action: apply
```

The earlier `plan` run is a review aid only. The `apply` action creates a **fresh plan** in the same workflow run and applies that exact generated plan; it does not reuse the plan produced by the earlier `plan` action.

## 12.5 Record outputs

Important outputs include:

```text
registry_endpoint
attachments_bucket
private_network_id
postgresql_endpoint
redis_endpoint
container_endpoint
```

Set:

```text
SCW_REGISTRY_ENDPOINT
```

to the `registry_endpoint` value.

---

# 13. Strict shared-infrastructure-only deployment

The current GitHub workflow does **not** implement strict shared-only deployment.

If strict phase separation is required, change the workflow to add a reviewed `apply-common` action or run a controlled targeted Terraform operation outside the normal workflow.

The logical shared targets are:

```text
module.network
module.postgresql
module.redis
module.attachments
module.secrets
module.registry
```

Example for controlled bootstrap/recovery only:

```bash
terraform plan \
  -target=module.network \
  -target=module.postgresql \
  -target=module.redis \
  -target=module.attachments \
  -target=module.secrets \
  -target=module.registry \
  -out=run.tfplan

terraform apply run.tfplan
```

Do not use targeted deployment as the normal operating model.

Always follow it with:

```bash
terraform plan
```

to identify changes omitted by `-target`.

---

# 14. Optional connectivity probe

Before deploying Correspondence, the repository can validate PostgreSQL, Redis and Object Storage connectivity from inside the Serverless Container runtime.

## 14.1 Build probe image

Run:

```text
Actions
  → Scaleway Build Connectivity Probe
```

The workflow pushes:

```text
connectivity:<commit-sha>
```

to `SCW_REGISTRY_ENDPOINT`.

## 14.2 Configure probe runtime

Update `SCW_TFVARS_JSON`:

```json
{
  "region": "pl-waw",
  "zone": "pl-waw-1",
  "name_prefix": "altinn-corr-internal-poc",
  "redis_version": "8.6.6",
  "container_mode": "connectivity",
  "container_image": "rg.pl-waw.scw.cloud/<namespace>/connectivity:<commit-sha>",
  "container_privacy": "private",
  "min_scale": 0,
  "enable_kubernetes": false
}
```

Ensure:

```text
POC_S3_ACCESS_KEY
POC_S3_SECRET_KEY
```

are configured.

Run:

```text
Scaleway Terraform → plan
Scaleway Terraform → apply
```

Set:

```text
SCW_CONTAINER_ENDPOINT
```

to the `container_endpoint` Terraform output.

## 14.3 Run the connectivity test

Run:

```text
Actions
  → Scaleway Test Connectivity
```

The probe expects all of the following:

```text
PostgreSQL: ok
Redis: ok
Object Storage: ok
```

The checks are substantive:

```text
PostgreSQL: SELECT 1 over TLS/VerifyCA
Redis:      PING + set/get/delete over TLS
S3:         put/get/delete of a unique object version
```

This probe is stronger infrastructure acceptance evidence than a process-only HTTP health endpoint.

> **Do not use `Test Scaleway connectivity` as the application data-plane validation.**
>
> The current `scaleway-connectivity.yml` contains a hard-coded `fr-par` RDB API URL and is not the correct Warsaw private-service validation workflow.
>
> Use `Scaleway Test Connectivity`, which calls the deployed probe container.

---

# 15. PostgreSQL bootstrap and extensions

The PostgreSQL bootstrap is optional and is disabled while:

```text
SCW_POSTGRES_BOOTSTRAP_IMAGE
```

is empty.

Recommended order:

## 15.1 Build bootstrap image

Run:

```text
Actions
  → Scaleway Build PostgreSQL Bootstrap
```

The workflow prints an image such as:

```text
rg.pl-waw.scw.cloud/<namespace>/postgresql-bootstrap:<sha>
```

Set the GitHub variable:

```text
SCW_POSTGRES_BOOTSTRAP_IMAGE
```

to that image.

## 15.2 Deploy the bootstrap runtime

Run:

```text
Scaleway Terraform → plan
Scaleway Terraform → apply
```

Terraform deploys the private bootstrap Serverless Container.

## 15.3 Configure extensions

Run:

```text
Actions
  → Scaleway Configure PostgreSQL Extensions
```

This workflow:

1. Reads `postgresql_bootstrap_endpoint` from Terraform state.
2. Calls the private-authenticated bootstrap endpoint using `SCW_SECRET_KEY`.
3. Configures/verifies the required PostgreSQL extensions.

Do this before the final Correspondence deployment if the application requires those extensions.

---

# 16. Phase B – Build Correspondence

Run:

```text
Actions
  → Scaleway Build Correspondence
```

Current workflow behavior:

```text
Repository: Altinn/altinn-correspondence
Branch:     feat/scaleway
Platform:   linux/amd64
Registry:   Warsaw private Registry
```

The pushed image is initially tagged with the Correspondence Git commit SHA.

The workflow also prints an immutable digest:

```text
rg.pl-waw.scw.cloud/<namespace>/correspondence@sha256:<digest>
```

Use the immutable digest in Terraform.

> **Legacy workflow-output warning**
>
> The current build summary still tells the user to set `application_runtime`.
> Ignore that part of the summary.
>
> The current parallel-runtime root uses `enable_kubernetes`.

---

# 17. Phase B – Deploy Correspondence to Serverless Container

## 17.1 Configure application secrets

Ensure:

```text
POC_S3_ACCESS_KEY
POC_S3_SECRET_KEY
POC_APPLICATION_SECRETS_JSON
```

are configured correctly.

## 17.2 Configure SCW_TFVARS_JSON

Example:

```json
{
  "region": "pl-waw",
  "zone": "pl-waw-1",
  "name_prefix": "altinn-corr-internal-poc",
  "redis_version": "8.6.6",

  "container_mode": "correspondence",
  "container_image": "rg.pl-waw.scw.cloud/<namespace>/correspondence@sha256:<digest>",
  "container_privacy": "public",
  "min_scale": 1,

  "enable_kubernetes": false,

  "application_secret_names": [
    "MaskinportenSettings__ClientId",
    "MaskinportenSettings__EncodedJwk",
    "AltinnOptions__PlatformSubscriptionKey",
    "AltinnOptions__AccessManagementSubscriptionKey",
    "AltinnIdProviderSettings__ClientId",
    "AltinnIdProviderSettings__ClientSecret",
    "GeneralSettings__CorrespondenceBaseUrl"
  ]
}
```

Correspondence must use:

```text
min_scale >= 1
```

because the root configuration guard requires at least one continuously running Serverless Container for Correspondence mode.

The Serverless Container is public because private invocation requires an `X-Auth-Token` that TT02 cannot send.

## 17.3 Plan and apply

Run:

```text
Scaleway Terraform → plan
```

Verify that there are no unexpected replacement/destruction operations on:

```text
PostgreSQL
Redis
Object Storage
VPC
Private Network
```

Then:

```text
Scaleway Terraform → apply
```

## 17.4 Verify Serverless Container

The Serverless Container module enforces HTTPS-only connections.

Use:

```bash
curl -i https://<container-endpoint>/health
```

Expected:

```text
HTTP 200
```

Treat this as HTTP/application-health evidence only. The portability repository's application-porting notes warn that the Correspondence `/health` implementation used during the PoC may return HTTP 200 without reliably proving the result of the database connectivity check. Do not use `/health` alone as database acceptance evidence.

For database/cache/object-storage evidence, use the explicit connectivity probe and/or a real Correspondence functional flow.

Then perform the existing functional Correspondence test against TT02 and confirm persistence in:

```text
PostgreSQL
Object Storage
```

---

# 18. GeneralSettings__CorrespondenceBaseUrl

This setting needs special attention in the parallel-runtime PoC.

The current root passes the **same `application_secrets` map** to:

```text
Serverless Container
Kubernetes
```

Therefore both runtimes currently receive the same value for:

```text
GeneralSettings__CorrespondenceBaseUrl
```

For the original functional test, this value points to the public Serverless Container URL.

For Kubernetes:

- `/health` can be validated independently against the Kubernetes LoadBalancer.
- A full functional Correspondence test through Kubernetes may require changing `GeneralSettings__CorrespondenceBaseUrl` to the Kubernetes public URL.
- Changing the shared secret affects both runtimes during the next Terraform apply.

This is an intentional PoC limitation of the current shared configuration.

If parallel end-to-end testing of both runtimes is required, introduce runtime-specific configuration/secrets or a stable common front door/DNS name.

## 18.1 Parallel-runtime side effects

Both runtimes point to the same PostgreSQL and Redis services, and `ScalewayPoc` performs EF migrations during application startup.

With:

```text
Serverless min_scale = 1
Kubernetes replicas  = 1
```

both application processes can also run background work against the same shared backend.

For the PoC this is useful for runtime comparison, but it must **not** be interpreted as a validated active/active design. Before sustained parallel functional testing, verify Hangfire/background-worker behavior, locking/idempotency and whether duplicate consumers can process the same work.

---

# 19. Phase C – Configure Kubernetes

Kubernetes is added in parallel with Serverless Container.

Do **not** remove or disable the Serverless Container for the current PoC model.

Update `SCW_TFVARS_JSON`:

```json
{
  "region": "pl-waw",
  "zone": "pl-waw-1",
  "name_prefix": "altinn-corr-internal-poc",
  "redis_version": "8.6.6",

  "container_mode": "correspondence",
  "container_image": "rg.pl-waw.scw.cloud/<namespace>/correspondence@sha256:<digest>",
  "container_privacy": "public",
  "min_scale": 1,

  "enable_kubernetes": true,

  "kubernetes_version": "1.37.1",
  "kubernetes_node_type": "DEV1-M",
  "kubernetes_pool_size": 1,
  "kubernetes_min_size": 1,
  "kubernetes_max_size": 1,
  "kubernetes_autoscaling": false,
  "kubernetes_namespace": "correspondence",
  "kubernetes_replicas": 1,
  "kubernetes_public_port": 80,

  "application_secret_names": [
    "MaskinportenSettings__ClientId",
    "MaskinportenSettings__EncodedJwk",
    "AltinnOptions__PlatformSubscriptionKey",
    "AltinnOptions__AccessManagementSubscriptionKey",
    "AltinnIdProviderSettings__ClientId",
    "AltinnIdProviderSettings__ClientSecret",
    "GeneralSettings__CorrespondenceBaseUrl"
  ]
}
```

The current PoC intentionally pins:

```text
pool_size = 1
min_size = 1
max_size = 1
autoscaling = false
replicas = 1
```

This avoids an unnecessary `max_size = 1 -> 2` plan when autoscaling is disabled.

Verify Kubernetes version availability before creating a fresh cluster in the future.

---

# 20. Kubernetes Registry image pull

The Correspondence image is private.

Terraform creates a Kubernetes Secret of type:

```text
kubernetes.io/dockerconfigjson
```

and references it through:

```text
imagePullSecrets
```

The GitHub secret:

```text
POC_REGISTRY_PULL_SECRET
```

must contain the Scaleway API secret key for an IAM identity with Registry read/pull access.

The Registry username is supplied by Terraform from the Registry namespace name.

The Registry pull credential is stored through the Kubernetes provider and therefore becomes sensitive Terraform state data.

Protect the remote state accordingly.

---

# 21. Phase C – Deploy Kubernetes cluster infrastructure

The first Kubernetes deployment is intentionally split.

This avoids trying to create Kubernetes API objects before Kapsule and its API are available.

Run:

```text
Actions
  → Scaleway Terraform
  → action: apply-kubernetes-cluster
```

The current workflow targets:

```text
module.network.scaleway_vpc.this
module.kubernetes_network[0]
module.kubernetes_cluster[0]
```

This creates or handles:

```text
existing VPC state/address
Kubernetes Private Network
Kapsule cluster
Kubernetes worker node pool
```

Current Kubernetes network:

```text
10.21.0.0/22
```

Current cluster:

```text
name:      altinn-corr-internal-poc-k8s
type:      Kapsule
CNI:       Cilium
node pool: applications
node type: DEV1-M
nodes:     1
```

The node module currently has:

```text
public_ip_disabled = false
```

so the worker receives a public IP in the current PoC.

This matches Scaleway's controlled-isolation model: worker public IPs are primarily used for outbound access, while inbound traffic is protected by the Kapsule security model. The application must still be exposed through the Kubernetes LoadBalancer Service, not through the worker IP or NodePort.

If `public_ip_disabled` is later changed to `true`, provide the required egress path (for example a Public Gateway/default route) before expecting access to the public S3 endpoint or other internet services.

After the targeted apply, the workflow automatically runs a normal full Terraform plan to show the remaining changes.

> `-target` is used only for the initial cluster establishment/recovery path.  
> Do not use it for normal routine deployment.

---

# 22. Phase C – Deploy Kubernetes application infrastructure

After the cluster and node pool are Ready, run:

```text
Actions
  → Scaleway Terraform
  → action: plan
```

The remaining plan should create/update the Kubernetes application resources.

Then:

```text
Actions
  → Scaleway Terraform
  → action: apply
```

Terraform creates:

```text
Namespace: correspondence
Application Secret
Registry imagePullSecret
Deployment
1 x Correspondence pod
LoadBalancer Service
```

Traffic flow:

```text
Internet
   |
   v
Scaleway Load Balancer
   |
   | TCP/HTTP 80
   v
Kubernetes Service
   |
   | targetPort 2525
   v
Correspondence pod
   |
   +--> PostgreSQL through VPC routing
   +--> Redis through VPC routing
   +--> Object Storage through regional S3 endpoint
```

Object Storage is different from PostgreSQL and Redis in the Warsaw PoC. The Terraform module uses:

```text
https://s3.pl-waw.scw.cloud
```

which is the public regional S3 endpoint. Scaleway Object Storage private VPC access is currently limited to `fr-par`, so the Warsaw pod does not reach the attachment bucket through the Kubernetes Private Network. The current worker has a public IP for controlled-isolation egress, which allows access to the regional public S3 endpoint.

The current Kubernetes endpoint is generated as:

```text
http://<load-balancer-ip>
```

There is currently no DNS/TLS/Ingress layer in front of the Kubernetes endpoint.

Therefore `/health` can be tested directly over HTTP for PoC validation, but the Kubernetes endpoint is not yet externally equivalent to the HTTPS-only Serverless endpoint. Before using Kubernetes as the callback/base URL for a complete TT02/browser flow, confirm that HTTP is acceptable for that test or add DNS/TLS/Ingress (or another HTTPS front door).

---

# 23. Kubernetes health configuration

Current deployment probes:

```text
startup_probe
readiness_probe
liveness_probe
```

In the current Terraform code, **all three use the same `health_path`**, which is `/health` in `correspondence` mode.

The startup probe is important.

During the initial PoC deployment, liveness checks started before Correspondence was listening on port `2525`, which caused repeated restarts.

Current startup behavior:

```text
period_seconds    = 10
timeout_seconds   = 5
failure_threshold = 30
```

This gives the application up to approximately five minutes to start before startup is considered failed.

After startup succeeds:

- **readiness** controls whether the pod receives Service traffic.
- **liveness** can restart the process if it later becomes unhealthy.

Current Terraform Deployment configuration also has:

```text
wait_for_rollout = false
```

This was introduced during troubleshooting so Terraform did not wait for the Deployment to become Ready.

Once the workload is considered stable, consider restoring:

```text
wait_for_rollout = true
```

so Terraform apply also validates rollout success.

> **Health-path design issue to review**
>
> `docs/poc/APPLICATION_PORTING.md` recommends process-only `/healthz` for liveness and `/health` for readiness, while the current Terraform code uses `/health` for startup, readiness and liveness.
>
> That mismatch should be resolved in code/documentation. A production-style design would normally separate process liveness from dependency readiness so a temporary PostgreSQL/Redis outage does not cause unnecessary process restarts.

---

# 24. Verify Kubernetes

Use `kubectl` or the Kubernetes extension in VS Code.

## 24.1 Node

```bash
kubectl get nodes -o wide
```

Expected:

```text
1 Ready worker node
```

## 24.2 Pod

```bash
kubectl get pods -n correspondence -o wide
```

Expected:

```text
READY   STATUS
1/1     Running
```

Detailed status:

```bash
kubectl describe pod \
  -n correspondence \
  -l app.kubernetes.io/name=altinn-corr-internal-poc-api
```

Logs:

```bash
kubectl logs \
  -n correspondence \
  -l app.kubernetes.io/name=altinn-corr-internal-poc-api \
  --tail=200
```

Previous logs after a restart:

```bash
kubectl logs \
  -n correspondence \
  -l app.kubernetes.io/name=altinn-corr-internal-poc-api \
  --previous \
  --tail=200
```

## 24.3 Service

```bash
kubectl get svc -n correspondence
```

Expected Service:

```text
altinn-corr-internal-poc-api-public
```

Expected configuration:

```text
Type:       LoadBalancer
Port:       80
TargetPort: 2525
```

Retrieve the public IP:

```bash
kubectl get svc altinn-corr-internal-poc-api-public \
  -n correspondence \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Or from Terraform:

```bash
terraform output kubernetes_load_balancer_ip
```

## 24.4 Health check

```bash
curl -i http://<LOAD_BALANCER_IP>/health
```

A successful PoC response is:

```json
{
  "status": "Healthy",
  "message": "Environment properly configured and database is accessible"
}
```

Expected HTTP result:

```text
200 OK
```

This proves:

```text
public Load Balancer
→ Kubernetes Service
→ pod on port 2525
→ HTTP application response
```

The observed PoC response included the message:

```text
Environment properly configured and database is accessible
```

but do not treat the HTTP 200/body alone as definitive database acceptance evidence unless the corresponding application code is verified to fail the endpoint when `CanConnectAsync()` returns false.

Use an explicit data-plane check or functional Correspondence transaction to prove database access. `/health` also does not by itself prove Redis, Object Storage or the TT02 functional flow.

---

# 25. Kubernetes resource capacity

Current application request/limit in Correspondence mode:

```text
CPU request:    500m
CPU limit:      1100m
Memory request: 1Gi
Memory limit:   2Gi
```

During the first rollout, Kubernetes temporarily reported:

```text
Insufficient memory
```

on the single `DEV1-M` node.

The pod later scheduled successfully, but capacity should be monitored before:

```text
adding more workloads
increasing replicas
enabling autoscaling
```

Useful commands:

```bash
kubectl describe node
kubectl top nodes
kubectl top pods -A
```

`kubectl top` requires working Kubernetes metrics collection.

---

# 26. Load Balancer lifecycle

The Service is declared as:

```text
type = LoadBalancer
```

The Scaleway Kubernetes Cloud Controller Manager creates and manages the external Scaleway Load Balancer.

The controller adds metadata such as:

```text
service.beta.kubernetes.io/scw-loadbalancer-id
```

The Terraform module currently ignores controller-managed Service annotations:

```hcl
lifecycle {
  ignore_changes = [
    metadata[0].annotations
  ]
}
```

Do not manually manage the Kubernetes Load Balancer from the Scaleway console.

Manage the Kubernetes Service and its annotations through Kubernetes/Terraform.

---

# 27. Final Terraform validation

After any targeted deployment, run a normal full plan:

```text
Actions
  → Scaleway Terraform
  → action: plan
```

The desired stable result is:

```text
No changes.
```

or equivalently:

```text
0 to add
0 to change
0 to destroy
```

Do not accept unexpected replacement/destruction of:

```text
VPC
Private Networks
PostgreSQL
Redis
Object Storage
Serverless Container
Kapsule cluster
```

without explicit review.

---

# 28. Routine Correspondence image update

When infrastructure already exists:

## Step 1

Run:

```text
Scaleway Build Correspondence
```

## Step 2

Copy the immutable digest.

## Step 3

Update:

```text
SCW_TFVARS_JSON → container_image
```

## Step 4

Run:

```text
Scaleway Terraform → plan
```

## Step 5

Verify the expected application changes only.

## Step 6

Run:

```text
Scaleway Terraform → apply
```

Because both runtimes use the same root variable:

```text
container_image
```

a full apply updates the configured image for both:

```text
Serverless Container
Kubernetes Deployment
```

when Kubernetes is enabled.

---

# 29. Kubernetes disable/removal behavior

`enable_kubernetes` is safe as an **enable/create switch**, but the current provider configuration makes it unsafe to treat it as a simple on/off toggle after Kubernetes API resources exist.

The provider is configured as:

```hcl
host = try(module.kubernetes_cluster[0].kubeconfig.host, "https://127.0.0.1")
```

If Kubernetes resources exist in state and `enable_kubernetes` is changed directly to `false`, Terraform may need to destroy Kubernetes `Deployment`, `Service`, `Secret` and `Namespace` objects while the provider has already fallen back to `127.0.0.1`.

Do not use this as the normal Kubernetes teardown sequence.

To remove only the Kubernetes extension while keeping Serverless:

1. Keep `enable_kubernetes = true`.
2. Destroy the Kubernetes application module while the Kapsule API/provider is still reachable.
3. Then set `enable_kubernetes = false`.
4. Run a normal plan/apply to remove the Kapsule cluster and Kubernetes Private Network.
5. Run a final normal plan.

The current GitHub workflow does not provide a dedicated action for this staged Kubernetes-only teardown. Add a reviewed workflow action before making this a routine operation.

For complete PoC destruction, keep the configuration needed to reach the Kubernetes API (including `enable_kubernetes = true` when Kubernetes is deployed) until the normal full destroy has removed the Kubernetes API resources.

---

# 30. Destroy procedure

Destruction is manually controlled by:

```text
Scaleway Terraform → destroy
```

The confirmation input must exactly match:

```text
name_prefix
```

Default/current prefix:

```text
altinn-corr-internal-poc
```

Before destroy:

- Decide whether PostgreSQL data must be retained.
- Export any data required for evidence.
- Inspect Object Storage versions.
- Confirm whether Registry images require retention.
- Confirm that the test environment is no longer in use.

The attachment bucket is versioned and defaults to:

```text
force_destroy = false
```

A non-empty versioned bucket can therefore block destruction.

Do not casually set:

```text
force_destroy_attachments = true
```

unless permanent deletion is explicitly intended.

The bootstrap Terraform state bucket is outside the normal environment root and must remain.

---

# 31. Sensitive Terraform state

Terraform state contains sensitive values, including or potentially including:

```text
database password-derived configuration
Redis credentials
application secret data
Kubernetes Secret data
Registry pull credential
Kapsule kubeconfig/token data
```

The state bucket must therefore be treated as sensitive infrastructure.

Do not:

```text
commit Terraform state
upload Terraform plans as public artifacts
copy state to unprotected locations
```

The GitHub workflow keeps the generated plan on the runner and removes it after the run.

---

# 32. Known current repository inconsistencies

The following are known documentation/workflow issues in the current repository and should not be mistaken for the intended deployment model.

## 32.1 Legacy `application_runtime`

Still present in:

```text
variables.tf
terraform.tfvars
environment README
Correspondence build-workflow summary
```

But current `main.tf` uses:

```text
enable_kubernetes
```

for Kubernetes parallel deployment.

Recommended cleanup:

```text
remove application_runtime
update terraform.tfvars comments
update environment README
update build-workflow summary
```

## 32.2 CI helper region default

`tools/ci/write-config.py` defaults missing region to:

```text
fr-par
```

while the current PoC is Warsaw.

Always explicitly configure:

```json
"region": "pl-waw",
"zone": "pl-waw-1"
```

Recommended cleanup: align the helper default with the current PoC or require `region` explicitly.

## 32.3 Registry pull secret check

`scaleway-terraform.yml` currently requires:

```text
POC_REGISTRY_PULL_SECRET
```

for every `plan` and `apply`, even when Kubernetes is disabled.

Recommended cleanup: parse `SCW_TFVARS_JSON` and require the secret only when Kubernetes/private Registry pull is actually needed.

## 32.4 Legacy connectivity workflow

`scaleway-connectivity.yml` currently queries:

```text
rdb/v1/regions/fr-par
```

and is not a correct validation of the Warsaw PoC.

Use:

```text
scaleway-test-connectivity.yml
```

for the deployed connectivity probe.

Recommended cleanup: update or remove the legacy API-only workflow.

## 32.5 Root provider lock file must include Kubernetes

The root requires:

```text
hashicorp/kubernetes = 3.3.0
```

The repository snapshot inspected for this runbook had a root `.terraform.lock.hcl` containing only the Scaleway provider.

This is masked by the main Terraform workflow because its normal `terraform init` is allowed to update the lock file on the ephemeral runner. However, `Scaleway Configure PostgreSQL Extensions` uses:

```text
terraform init -lockfile=readonly
```

and can fail if the committed lock file does not contain the Kubernetes provider.

Recommended cleanup:

```text
run Terraform 1.13.5 init locally
verify scaleway/scaleway 2.86.0
verify hashicorp/kubernetes 3.3.0
commit the updated .terraform.lock.hcl
```

## 32.6 CI documentation overstates current validation

The repository README says CI includes formatting and mocked Terraform plan tests. In the inspected snapshot:

- `scaleway-terraform.yml` does not run `terraform fmt -check`.
- `terraform test` is executed, but no `.tftest.hcl` files are present in the environment root.

Therefore `terraform test` currently provides no mocked-plan coverage.

Recommended cleanup:

```text
add terraform fmt -check -recursive
add real .tftest.hcl plan tests, or remove the claim from README
```

## 32.7 Local terraform.tfvars is not the CI deployment source

The checked-in/local `terraform.tfvars` still contains older example values such as:

```text
redis_version = 8.4.0
application_runtime = serverless-container
```

GitHub deployment is driven by:

```text
SCW_TFVARS_JSON
```

through `.ci.auto.tfvars.json`.

Treat the GitHub Environment configuration as the source of deployment-time non-secret overrides.

---

# 33. Definition of done

A deployment is technically complete when:

## Shared infrastructure

- [ ] Terraform state bucket exists and is versioned.
- [ ] Main root uses remote state successfully.
- [ ] VPC exists.
- [ ] Private Network A exists.
- [ ] PostgreSQL is available.
- [ ] Redis is available.
- [ ] Object Storage bucket is available.
- [ ] Secret Manager resources are available.
- [ ] Private Container Registry exists.

## Serverless Container

- [ ] Correspondence image exists in the Warsaw Registry.
- [ ] Correspondence runs as Serverless Container.
- [ ] `min_scale >= 1`.
- [ ] Public Serverless endpoint is available.
- [ ] `/health` returns HTTP 200.
- [ ] Existing functional test has been completed as intended.

## Kubernetes

- [ ] Private Network B `10.21.0.0/22` exists in the same VPC.
- [ ] Kapsule cluster is Ready.
- [ ] Node pool has 1 Ready `DEV1-M` worker.
- [ ] Namespace `correspondence` exists.
- [ ] Correspondence pod is `Running` and `Ready 1/1`.
- [ ] Registry image pull works.
- [ ] LoadBalancer Service exists.
- [ ] LoadBalancer has an external IP.
- [ ] External `/health` returns HTTP 200.
- [ ] Database connectivity from Kubernetes is confirmed by an explicit data-plane/functional test, not only by `/health`.
- [ ] Full functional Kubernetes test is completed if that is part of the test scope.

## Terraform

- [ ] Final normal Terraform plan has no unexpected changes.
- [ ] No unexpected resource destruction is pending.
- [ ] No targeted plan is left as the assumed final state.

---

# 34. Quick operational checklist

```text
[ ] Bootstrap state
[ ] Configure GitHub Environment
[ ] Set SCW_ORGANIZATION_ID
[ ] Set SCW_PROJECT_ID
[ ] Set SCW_STATE_BUCKET
[ ] Set SCW_STATE_REGION
[ ] Verify committed root .terraform.lock.hcl includes Scaleway 2.86.0 and Kubernetes 3.3.0
[ ] Set SCW_TFVARS_JSON with explicit pl-waw/pl-waw-1
[ ] Set SCW_ACCESS_KEY / SCW_SECRET_KEY
[ ] Set database and Redis passwords
[ ] Set POC_REGISTRY_PULL_SECRET (required by current plan/apply workflow)
[ ] Terraform plan
[ ] Terraform apply shared + smoke baseline
[ ] Set SCW_REGISTRY_ENDPOINT
[ ] Optional connectivity probe
[ ] Optional PostgreSQL bootstrap/extensions
[ ] Build Correspondence image
[ ] Set POC_S3 credentials
[ ] Set POC_APPLICATION_SECRETS_JSON
[ ] Switch container_mode to correspondence
[ ] Terraform plan/apply Serverless baseline
[ ] Verify Serverless /health and functional test
[ ] Set enable_kubernetes=true
[ ] Set Kubernetes pool size/min/max = 1
[ ] Run apply-kubernetes-cluster
[ ] Review automatic full plan after cluster creation
[ ] Run normal plan
[ ] Run normal apply
[ ] Verify node
[ ] Verify pod
[ ] Verify Service and LoadBalancer
[ ] Verify Kubernetes /health (routing/application check only)
[ ] Verify DB/Redis/S3 through explicit data-plane or functional test
[ ] Handle CorrespondenceBaseUrl before full Kubernetes functional test
[ ] Run final normal Terraform plan
```

---

# 35. External behavior verified for this runbook

The deployment model relies on standard Scaleway behavior:

- Kapsule allocates a `/22` subnet from its attached Private Network.
- VPC routing allows communication between Private Networks in the same routed VPC.
- A Kubernetes `Service` of type `LoadBalancer` is realized by the Scaleway Cloud Controller Manager.
- A private Scaleway Registry image can be pulled into Kapsule using a Kubernetes image pull secret backed by a Scaleway API secret key; Scaleway's Kapsule example uses the Registry namespace name as the Docker username.
- Kapsule controlled isolation gives worker nodes public IPs for outbound access by default.
- Object Storage Private Network access is currently a private-beta feature available only in `fr-par`; the Warsaw PoC therefore uses `https://s3.pl-waw.scw.cloud`.

These platform behaviors were cross-checked against Scaleway documentation available in October 2026. Recheck them if the PoC is recreated later because supported versions and product behavior evolve.

Authoritative references:

- https://www.scaleway.com/en/docs/kubernetes/reference-content/secure-cluster-with-private-network/
- https://www.scaleway.com/en/docs/vpc/how-to/manage-routing/
- https://www.scaleway.com/en/docs/kubernetes/reference-content/kubernetes-load-balancer/
- https://www.scaleway.com/en/docs/kubernetes/how-to/deploy-image-from-container-registry/
- https://www.scaleway.com/en/docs/object-storage/how-to/use-obj-stor-with-private-networks/
