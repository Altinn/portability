# Application work required before enabling Correspondence mode


| Area | What the supplied code does | Required Scaleway work |
|---|---|---|
| HTTP | Dockerfile listens on 2525; Bicep checks `/health` | Preserve 2525; use `/healthz` for liveness, `/health` only after checking its readiness semantics |
| PostgreSQL | `Program.cs` reads `DatabaseOptions:ConnectionString`; passwordless path obtains an Azure token | Supply password; install Scaleway CA, confirm EF extensions/settings and migrations |
| Redis | `GeneralSettings.RedisConnectionString`; cache and Data Protection connect at startup | Use private TLS endpoint, trust the exported CA and verify server identity in StackExchange.Redis |
| Attachment storage | Azure Blob SDK, connection strings and Azure resource management | Implement/test an S3 storage adapter; `Portability__S3*` is only a proposed new configuration contract |
| Secrets | Some values are env vars; `KeyVaultSecretStore` calls Azure Key Vault directly | Separate env injection from API calls; replace Key Vault integrations where exercised |
| IAM | `DefaultAzureCredential`, Managed Identity and Azure ARM clients | Replace Azure-specific paths, use dedicated runtime credentials; do not inject infra-admin credentials |
| Key rotation | Maskinporten rotation references Key Vault and Azure Container Apps | Disabled by the root; implement an approved replacement before enabling |
| Integrations | Maskinporten, Altinn Platform/auth/register, Dialogporten, ID-porten, subscription keys | Add approved TT02/test configuration and secret values; never use production keys/data by default |
| Telemetry | Azure Monitor exporters/Application Insights | Decide whether to retain Azure telemetry or configure portable logging/metrics |
| Malware/eventing | Event Grid + Defender for Storage in Azure IaC | Design explicit test behavior or equivalent scanning flow; never infer scanning from S3 alone |
| Background work | Hangfire, scheduled work and immediate Redis dependency | Keep >=1 replica, verify worker behavior/timeouts and orderly shutdown |
| Migrations | Azure Container App job/file-share workflow | Build self-contained EF migration bundle; run on VPC-connected runner, not current Serverless Jobs |

## Health semantics in the uploaded source

`HealthController` exposes process-only `/healthz`. Its `/health` handler calls
`CanConnectAsync()` but does not check the returned boolean, so HTTP 200 alone is
not proof of database connectivity. Fix the readiness handler to reject a false
result before treating it as acceptance evidence. Terraform configures `/healthz`
for Correspondence liveness so a data-service interruption does not itself cause
process restarts. The separate probe's `SELECT 1` is the initial DB check.

## Configuration and secrets

`ASPNETCORE_ENVIRONMENT=ScalewayPoc` is proposed. The source has no matching
portable deployment configuration that this Terraform package can assume exists.
Add an application configuration for that environment and validate every startup
requirement. Examples of existing source config names include:

- `DatabaseOptions__ConnectionString`
- `GeneralSettings__RedisConnectionString`
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
`SSL Mode=VerifyCA` and `/app/certs/postgresql-ca.pem`. Add the exported CA to the
adapted image or a controlled runtime mount. Rotate/redeploy the CA as required.
VerifyCA checks the chain rather than the hostname; if moving to VerifyFull,
use an endpoint name covered by the actual certificate.

Redis has a custom TLS certificate. Integrate its CA with the .NET Redis client
and the Data Protection connection, and verify the TLS host name. A connection
string by itself cannot install a trust anchor in the unchanged image.

Serverless Containers Terraform resource 2.86.0 has a sensitive environment-value
map rather than a Secret Manager ID-reference field. This code writes secret
versions **and** injects sensitive values; the two are separate resources. It is
not equivalent to managed-identity Key Vault references. Serverless Jobs supports
Secret Manager ID references, but lacks Private Network attachment.

## Migration execution

Use a Digdir-controlled runner with private connectivity, or a dedicated ephemeral
compute workload attached to the same Private Network. Build the EF bundle from
the **same application commit** as the API image. Run it once before changing the
API image; record the commit, image digest, migration result and time.
Do not add a `local-exec` provisioner to Terraform, run migrations on every plan,
or expose PostgreSQL publicly just to reach it from GitHub-hosted runners.

## Acceptance evidence

1. GitHub CI and real provider plan pass.
2. `/checks` passes for private PostgreSQL, private TLS Redis and S3.
3. Migration bundle passes; necessary PostgreSQL extensions are compatible.
4. Adapted API `/health` passes; an approved test request uses DB, cache and attachments.
5. Approved test integrations/authentication pass without unintended production calls.
6. Attachment download/upload, retry/timeout behavior and secret rotation are tested.
7. Logging, malware handling, budget and cleanup ownership are explicitly recorded.

No public rollout, live data migration or production equivalence is implied by
Terraform validation or by a passing nginx HTTP check.
