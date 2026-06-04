# AKS OIDC / Workload Identity Preflight

## Scope

Task 1.3: verify AKS module/root wiring exposes and enables OIDC issuer and workload identity for the target cluster.

## Findings

Root AKS module call:

- `deploy/terraform/aks.tf` uses `git::https://github.com/Ensono/stacks-terraform//azurerm/modules/azurerm-aks?ref=v8.0.52`.

Module cache evidence for pinned module:

- `deploy/terraform/.terraform/modules/ssl_app_gateway/azurerm/modules/azurerm-aks/aks.tf` sets `oidc_issuer_enabled = var.oidc_issuer_enabled`.
- `deploy/terraform/.terraform/modules/ssl_app_gateway/azurerm/modules/azurerm-aks/variables.tf` defines
  `variable "oidc_issuer_enabled"` with default `true`.

Root wiring gaps:

- `deploy/terraform/aks.tf` does not pass `oidc_issuer_enabled` explicitly.
- `deploy/terraform/variables.tf` has no root `oidc_issuer_enabled` variable.
- `deploy/terraform/outputs.tf` has no OIDC issuer URL output.

Workload Identity gap:

- Repo grep found no `workload_identity_enabled` root variable, module input, or output.
- Pinned cached AKS module exposes OIDC issuer only; no workload identity enablement knob is visible in the module interface.

## Conclusion

Preflight does not pass yet.

- OIDC issuer appears supported by the pinned module and defaults to enabled, but root wiring does not explicitly expose it or output issuer URL.
- Workload Identity enablement is not exposed/enabled by current root/module wiring.

Task 1.3 remains blocked until AKS module support is added/bumped or another supported wiring path enables
`workload_identity_enabled` and exposes the OIDC issuer URL needed for federated credentials.
