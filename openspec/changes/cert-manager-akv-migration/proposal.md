## Why

The current TLS flow depends on Terraform-managed ACME issuance and inline certificate material, which couples certificate lifecycle to infrastructure
apply operations and increases operational risk during renewals and cutovers. This change is needed now to move certificate issuance and rotation into
Kubernetes-native controllers while preserving controlled rollback, explicit security boundaries, and existing eirctl pipeline conventions.

## What Changes

- Introduce cert-manager based wildcard/apex certificate issuance using Let's Encrypt ACME DNS-01 with staging-first rollout and production activation
  after nonprod gates.
- Issue certificate DNS names for both `*.${dns_zone}` and `${dns_zone}` using the existing DNS zone configuration.
- Add issuer authorization controls so only approved platform namespaces/service accounts can request certificates from the migration ClusterIssuers.
- Introduce External Secrets Operator PushSecret flow to synchronize certificate material into Azure Key Vault as both:
  - App Gateway-compatible PFX secret.
  - Key Vault certificate object.
- Transition Application Gateway certificate source from inline/ACME inputs to Key Vault versionless secret reference with managed identity access.
- Add separate Workload Identity federated credentials and explicitly scoped Azure RBAC for cert-manager, external-secrets, and Application Gateway
  identities.
- Add/extend eirctl tasks for all migration discovery, validation, forced renewal, rollback, negative authorization checks, Key Vault
  version-integrity checks, and production stabilization gates; direct terraform/helm/kubectl/az operations are not part of this workflow.
- Require eirctl secret redaction for certificate/private-key/Key Vault material across stdout/stderr, logs, traces, pipeline artifacts, validation
  reports, and failure paths.
- Add audit logging, monitoring, alerting, and explicit compliance evidence capture for issuance, synchronization, Key Vault version changes, App
  Gateway listener health, rollback, approvals, and production stabilization gates.
- Tighten cryptographic policy to require TLS 1.2+ for Application Gateway/frontend TLS and managed certificate keys of RSA 2048+ or ECDSA
  P-256/P-384.
- Add supply-chain controls for Helm charts and controller images, including approved sources, immutable versions, provenance/checksum validation
  where supported, image allow-listing, and digest/tag evidence.
- Add a defined automatic eirctl rollback contract for failed Application Gateway Key Vault cutover, including triggers, timeout, idempotency, state
  transition, and post-rollback listener validation.
- Conditionally remove aad-pod-identity only when eirctl runtime and declarative inventory validation prove no active or dormant users.
- Update pipeline/test/documentation expectations to support a dual-mode transition and defer ACME retirement until production stabilization gates
  pass.

## Capabilities

### New Capabilities

- `kubernetes-certificate-lifecycle`: Issue, manage, force-renew, authorize, and replicate wildcard/apex TLS certificates in-cluster using
  cert-manager and reflector patterns.
- `key-vault-certificate-sync`: Synchronize managed certificate artifacts from Kubernetes to Azure Key Vault as both PFX secret and certificate object
  with scoped RBAC and version-integrity validation.
- `app-gateway-key-vault-tls-source`: Configure Application Gateway to use Key Vault-backed certificate source with managed identity, versionless
  references, forced-renewal validation, production stabilization gates, and rollback-safe cutover.

### Modified Capabilities

- None.

## Chart Pins

The migration SHALL use these pinned Helm chart versions unless preflight proves a blocker requiring proposal update before implementation:

- cert-manager chart `v1.20.2` from `https://charts.jetstack.io`
- external-secrets chart `2.5.0` from `https://charts.external-secrets.io`
- reflector chart `10.0.46` from `https://emberstack.github.io/helm-charts`

## Impact

- Affected code and config: Terraform under `deploy/terraform`, Helm chart manifest/values/templates under `deploy/helm`, eirctl tasks under
  `build/eirctl`, Azure DevOps pipeline vars and stage wiring under `build/azDevOps/azure`, InSpec tests under `deploy/tests`, and setup docs/prompts.
- External systems: Azure DNS zone permissions, Azure Key Vault RBAC, AKS Workload Identity federation, Application Gateway TLS configuration, Let's
  Encrypt ACME endpoints, and Kubernetes admission/RBAC controls for cert-manager resources.
- Dependencies: cert-manager chart `v1.20.2`, external-secrets chart `2.5.0`, reflector chart `10.0.46`, supported ESO Azure Key Vault PushSecret
  behavior, existing eirctl task orchestration, approved chart repositories/container registries, chart provenance/checksum verification where
  supported, and image tag/digest evidence.
- Cleanup: after nonprod gates, production cutover, production stabilization, forced-renewal validation, rollback rehearsal/dry-run, and regression
  gates succeed, remove obsolete ACME-era provider/variables/outputs/docs including `pfx_password`, `certificate_pem`, and `issuer_pem`.
