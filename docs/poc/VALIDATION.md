# Verification report – 12 October 2026

| Check | Result |
|---|---|
| Terraform 1.13.5 format check, recursively | Passed |
| Environment `terraform init -backend=false` | Passed; signed Scaleway 2.86.0 installed and lock file created |
| Bootstrap `terraform init -backend=false -lockfile=readonly` | Passed |
| Independent HCL parsing | Passed for 45 Terraform/test files |
| Resource input-name review against pinned provider Go source | Passed for 13 resource declarations; top-level names only |
| Local module paths and input contracts | Passed for all seven environment module calls |
| GitHub Actions YAML parsing | Passed for both workflow files |
| CI configuration Python unit tests | 3 passed |
| Probe versioned-object cleanup and error-disclosure tests | 3 passed |
| Probe Python syntax | Passed |
| Full `terraform validate` / provider schema evaluation | Blocked by execution environment, not reported as passed |
| Terraform mock plan suite | Included for CI; not run locally due the same provider restriction |
| Probe Docker build and registry push | Not run locally; Docker runtime is unavailable |
| Real Scaleway plan, apply, database migrations and `/checks` | Not run; no authorized project credentials supplied |

The provider process exits during initialization with
`listen unix /tmp/plugin...: socket: operation not permitted` in this execution
environment. The GitHub Ubuntu workflow performs provider-based validation and
mocked plan tests before any cloud action. A passing static check is not equivalent
to a passing Terraform provider validation or a real API deployment.

The source review also identified that Redis `private_network` is a Terraform
set, so Redis outputs use `one(...)` rather than invalid numerical indexing.
Serverless Jobs lacks Private Network attachment; no private migration connection
has been invented. Secret Manager version payloads are passed as raw strings,
not double-base64-encoded data. Container configuration uses the current `image`,
`memory_limit_bytes`, `https_connections_only` and `liveness_probe` fields rather
than the deprecated equivalents in the pinned provider.

The package is ready to import and test in the existing GitHub repository, with
remaining runtime verification clearly assigned to CI and the Digdir-owned
Scaleway project. Do not label this foundation a working full Correspondence
application until the application-porting acceptance evidence is recorded.
