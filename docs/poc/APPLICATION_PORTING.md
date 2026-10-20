# Application work required before enabling Correspondence mode


| Area | What the supplied code does | Required Scaleway work |
|---|---|---|
| HTTP | Dockerfile listens on 2525; Bicep checks `/health` | Preserve 2525; use `/healthz` for liveness, `/health` only after checking its readiness semantics |
| PostgreSQL | `Program.cs` reads `DatabaseOptions:ConnectionString`; passwordless path obtains an Azure token | Connection string includes the password and `/app/certs/postgresql-ca.pem`. `DatabaseOptions__SslRootCertificatePem` is injected so the process can write that file. `ScalewayPoc` applies EF migrations during startup |
| Redis | `GeneralSettings.RedisConnectionString`; cache and Data Protection connect at startup | Inject the private endpoint with `user`, `password`, and `ssl=true`, plus `GeneralSettings__RedisCaPem`. The Warsaw certificate covers the private IP, so `sslHost` is not set |
| Attachment storage | S3 when `AttachmentStorageOptions:S3Endpoint` is set; Azure Blob remains the default | Set `AttachmentStorageOptions__S3Endpoint`, `S3Bucket`, `S3Region`, `S3AccessKey`, and `S3SecretKey` from the attachment bucket and its separate runtime key |
| Secrets | Some values are env vars; `KeyVaultSecretStore` calls Azure Key Vault directly | Separate env injection from API calls; replace Key Vault integrations where exercised |
| IAM | `DefaultAzureCredential`, Managed Identity and Azure ARM clients | Replace Azure-specific paths, use dedicated runtime credentials; do not inject infra-admin credentials |
| Key rotation | Maskinporten rotation references Key Vault and Azure Container Apps | Disabled by the root; implement an approved replacement before enabling |
| Integrations | Maskinporten, Altinn Platform/auth/register, Dialogporten, ID-porten, subscription keys | Add approved TT02/test configuration and secret values; never use production keys/data by default |
| Telemetry | Azure Monitor exporters/Application Insights | Decide whether to retain Azure telemetry or configure portable logging/metrics |
| Malware/eventing | Event Grid + Defender for Storage in Azure IaC | Design explicit test behavior or equivalent scanning flow; never infer scanning from S3 alone |
| Background work | Hangfire, scheduled work and immediate Redis dependency | Keep >=1 replica, verify worker behavior/timeouts and orderly shutdown |
| Migrations | Azure Container App job/file-share workflow | `ScalewayPoc` applies EF migrations on startup, the same way local development does. This repository does not deploy a migration job |

## Health semantics in the uploaded source

`HealthController` exposes process-only `/healthz`. Its `/health` handler calls
`CanConnectAsync()` but does not check the returned boolean, so HTTP 200 alone is
not proof of database connectivity. Fix the readiness handler to reject a false
result before treating it as acceptance evidence. Terraform configures `/healthz`
for Correspondence liveness so a data-service interruption does not itself cause
process restarts. The separate probe's `SELECT 1` is the initial DB check.

## Configuration and secrets

`ASPNETCORE_ENVIRONMENT=ScalewayPoc` selects `appsettings.ScalewayPoc.json` from
`feat/scaleway`. Terraform injects the remaining startup values. Examples:

- `DatabaseOptions__ConnectionString` and `DatabaseOptions__SslRootCertificatePem`
- `GeneralSettings__RedisConnectionString` and `GeneralSettings__RedisCaPem`
- `GeneralSettings__CorrespondenceBaseUrl`
- `AttachmentStorageOptions__S3Endpoint`, `S3Bucket`, `S3Region`, `S3AccessKey`, and `S3SecretKey`
- `AltinnOptions__PlatformSubscriptionKey`
- `AltinnOptions__AccessManagementSubscriptionKey`
- `MaskinportenSettings__ClientId` and `MaskinportenSettings__EncodedJwk`
- `AltinnIdProviderSettings__ClientId` and `AltinnIdProviderSettings__ClientSecret`
- `StatisticsApiKey`

See `.azure/modules/containerApp/main.bicep` in the original repo for the complete
Azure deployment env/secret list. That list is evidence of current dependencies,
not proof that every secret should be carried into the Scaleway PoC unchanged.

PostgreSQL connection strings generated here explicitly contain a password, so
`Program.cs` does not enter its Azure token acquisition branch. The string uses
`SSL Mode=VerifyCA` and `/app/certs/postgresql-ca.pem`.
`DatabaseOptions__SslRootCertificatePem` supplies the PEM, and the process writes
that file before the first connection. VerifyCA checks the chain rather than the
hostname.

Redis uses the private IP with `user`, `password`, and `ssl=true`.
`GeneralSettings__RedisCaPem` is the cluster CA. The Warsaw connectivity probe
verified that IP with hostname checking, so the connection string does not set
`sslHost`. If a renewed certificate stops covering the IP, set `sslHost` to a
name that is on the certificate.

Serverless Containers Terraform resource 2.86.0 has a sensitive environment-value
map rather than a Secret Manager ID-reference field. This code writes secret
versions **and** injects sensitive values; the two are separate resources. It is
not equivalent to managed-identity Key Vault references. Serverless Jobs supports
Secret Manager ID references, but lacks Private Network attachment.

## Migration execution

`feat/scaleway` applies EF migrations when `ASPNETCORE_ENVIRONMENT` is `ScalewayPoc`,
before the API serves traffic. That runs inside the private-network container.
This repository does not add a Serverless Job or a startup provisioner for schema
migration. Do not expose PostgreSQL publicly so a GitHub-hosted runner can reach it.

## Acceptance evidence

1. GitHub CI and real provider plan pass.
2. `/checks` passes for private PostgreSQL, private TLS Redis and S3.
3. Startup migration completes; necessary PostgreSQL extensions are compatible.
4. Adapted API `/health` passes; an approved test request uses DB, cache and attachments.
5. Approved test integrations/authentication pass without unintended production calls.
6. Attachment download/upload, retry/timeout behavior and secret rotation are tested.
7. Logging, malware handling, budget and cleanup ownership are explicitly recorded.

No public rollout, live data migration or production equivalence is implied by
Terraform validation or by a passing nginx HTTP check.
