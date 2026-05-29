## Why

The current TLS flow depends on Terraform-managed ACME issuance and inline certificate material, which couples certificate lifecycle to infrastructure apply operations and increases operational risk during renewals and cutovers. This change is needed now to move certificate issuance and rotation into Kubernetes-native controllers while preserving controlled rollback and existing pipeline conventions.

## What Changes

- Introduce cert-manager based wildcard certificate issuance using ACME DNS-01 with a staging-first rollout.
- Introduce External Secrets Operator PushSecret flow to synchronize certificate material into Azure Key Vault for Application Gateway consumption.
- Transition Application Gateway certificate source from inline/ACME inputs to Key Vault versionless secret reference with managed identity access.
- Add Workload Identity and federated credentials for cert-manager and external-secrets service accounts.
- Update pipeline/test/documentation expectations to support a dual-mode transition and safe ACME retirement after stabilization.
- Enforce eirctl-only execution for Terraform/Helm/test operations in this migration workflow.

## Capabilities

### New Capabilities

- `kubernetes-certificate-lifecycle`: Issue, manage, and replicate wildcard TLS certificates in-cluster using cert-manager and reflector patterns.
- `key-vault-certificate-sync`: Synchronize managed certificate artifacts from Kubernetes to Azure Key Vault for downstream consumers.
- `app-gateway-key-vault-tls-source`: Configure Application Gateway to use Key Vault-backed certificate source with managed identity and rotation-safe references.

### Modified Capabilities

- None.

## Impact

- Affected code and config: Terraform under deploy/terraform, Helm chart manifest/values/templates under deploy/helm, Azure DevOps pipeline vars and stage wiring under build/azDevOps/azure, and InSpec tests under deploy/tests.
- External systems: Azure DNS zone permissions, Azure Key Vault RBAC, AKS Workload Identity federation, Application Gateway TLS configuration.
- Dependencies: cert-manager chart, external-secrets chart, reflector chart, and existing eirctl task orchestration.
