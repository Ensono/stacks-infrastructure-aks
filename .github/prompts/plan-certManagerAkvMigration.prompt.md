## Plan: Migrate TLS Certificate Management to cert-manager with AKV Storage

Ticket Reference:

- Primary ticket: <https://github.com/Ensono/stacks-infrastructure-aks/issues/136>

Scope Consistency With Local Changes:

- This plan document is currently the only local change.
- No Terraform/Helm/pipeline files are changed yet.
- Treat this as an approved implementation runbook; execute tasks in order and validate after each phase.

Migrate from Terraform ACME-based certificate management to cert-manager using Let's Encrypt DNS-01, store wildcard certificates in Kubernetes,
replicate to consumer namespaces, sync to Azure Key Vault with External Secrets Operator, and switch Application Gateway to Key Vault-backed
certificates. Use Let's Encrypt staging by default and production only after validation gates pass.

## Execution Guardrails

1. Use eirctl commands only for platform operations:

- Do not call terraform, helm, kubectl, or az directly for routine execution/validation in this migration runbook.
- Use existing eirctl tasks for init/plan/apply/helm/tests/lint.
- If a required operation is not currently represented by an eirctl task, add the task first, then execute via eirctl.

2. Keep migration in dual-mode until cutover validation passes:

- Do not remove ACME provider/inputs in the same step as first App Gateway Key Vault cutover.
- Keep rollback path intact until nonprod renewal and rotation checks are complete.

## Preflight Checks (Do First)

1. Validate module capability before coding:

- Confirm AKS module exposes OIDC issuer and supports Workload Identity.
- Confirm AKS root wiring enables both OIDC issuer and Workload Identity for the deployed cluster.
- Confirm OIDC issuer URL is available for azurerm_federated_identity_credential issuer input (module output or explicit data lookup).
- Confirm App Gateway module version supports Key Vault certificate reference (versionless secret id) and identity wiring.
- If unsupported, add a module version bump task before migration tasks.

2. Validate Kubernetes chart compatibility:

- Pin chart versions for cert-manager, external-secrets, and reflector.
- Confirm exact chart values to enable CRDs and PushSecret for the pinned external-secrets version.
- Confirm exact service account names used by pinned chart versions (cert-manager controller SA, external-secrets SA) before creating federated
  identity credentials.

3. Validate repository conventions:

- In deploy/helm/k8s_apps.yaml use values_template (not values_repo).
- Validate there are no missing values_template files for enabled or newly enabled charts.
- Keep create_key_vault default unchanged in Terraform unless explicitly required across all consumers; prefer stage/pipeline variable control.

4. Validate operational prerequisites:

- Public DNS zone is delegated and writable by cert-manager identity.
- Key Vault is RBAC-enabled.
- Managed identity used by Application Gateway has access to read secrets/certificates from Key Vault.
- Confirm certificate object format/content-type expected by App Gateway when sourced from Key Vault secret/certificate URI.

5. Validate pipeline and tests before migration edits:

- Identify all references to acme_email, pfx_password, create_valid_cert, certificate_pem, issuer_pem in pipeline, tests, and docs.
- Plan test-gate updates before removing ACME-era variables/outputs to avoid false failures.

## Phased Implementation Plan

### Phase 1: Infrastructure Primitives and Identities

1. Add acme_server variable in deploy/terraform/variables.tf:

- Type string.
- Default <https://acme-staging-v02.api.letsencrypt.org/directory>.
- Description includes production URL and cutover guidance.
- Use this variable for cert-manager ClusterIssuer only (do not bind Terraform ACME provider server URL to this variable).

2. Add/update pipeline variable in build/azDevOps/azure/pipeline-vars.yml:

- Add acme_server.
- Keep/create create_key_vault=true in pipeline variables for target stages.
- Do not force a global Terraform default change unless explicitly intended.
- Preserve acme_email and pfx_password during transition phase; remove only after Task 15 gate passes.

3. Create cert-manager identity in deploy/terraform/aks.tf:

- azurerm_user_assigned_identity.
- azurerm_federated_identity_credential for system:serviceaccount:cert-manager:cert-manager.
- DNS Zone Contributor role assignment scoped to the DNS zone.
- Ensure federated credential issuer exactly matches the cluster OIDC issuer URL and subject exactly matches final service account naming.

4. Create ESO identity in deploy/terraform/aks.tf:

- azurerm_user_assigned_identity.
- azurerm_federated_identity_credential for the external-secrets service account.
- Key Vault Secrets Officer (or minimum required write role) scoped to Key Vault.
- Validate minimum write permissions for PushSecret operation and avoid over-privileging.

5. Add outputs required by Helm templating:

- cert_manager_identity_client_id.
- external_secrets_identity_client_id.
- aks_oidc_issuer_url (or equivalent output used by identity/federation resources).
- key_vault_name (and secret URI if needed).

### Phase 2: Helm Platform Components

6. Add cert-manager chart to deploy/helm/k8s_apps.yaml:

- Namespace cert-manager.
- installCRDs enabled.
- values_template: deploy/helm/values/cert_manager.yaml.
- Add rollout checks for cert-manager controller/webhook/cainjector deployments.

7. Add external-secrets chart to deploy/helm/k8s_apps.yaml:

- Namespace external-secrets.
- CRDs enabled for pinned version.
- PushSecret feature enabled per pinned version requirements.
- values_template: deploy/helm/values/external_secrets.yaml.
- Add rollout checks for controller deployment.
- Include rollout checks for webhook/cert-controller if enabled by chosen chart version.

8. Add reflector chart to deploy/helm/k8s_apps.yaml:

- Namespace reflector.
- values_template: deploy/helm/values/reflector.yaml.
- Add rollout checks for reflector deployment.

9. Update deploy/helm/values/cluster_setup.yaml with new inputs:

- acmeServer, dnsZone, dnsResourceGroup, subscriptionId.
- certManagerIdentityClientId, esoIdentityClientId.
- keyVaultName.
- reflectionAllowedNamespaces.
- Remove or isolate legacy AAD Pod Identity inputs if not used by the target flow.

### Phase 3: Issuance and Sync Manifests

10. Create ClusterIssuer template in deploy/helm/charts/cluster-setup/templates/cluster-issuer.yaml:

- ACME server from values.
- DNS-01 azureDNS solver.
- Workload Identity managedIdentity.clientID wired from cert-manager identity output.
- References dnsZone, dnsResourceGroup, subscriptionId.

11. Create wildcard Certificate template in deploy/helm/charts/cluster-setup/templates/wildcard-certificate.yaml:

- Certificate for *.dnsZone.
- Namespace cert-manager.
- Secret annotations for reflector allowed namespaces.

12. Create SecretStore and PushSecret templates in deploy/helm/charts/cluster-setup/templates:

- Workload Identity auth using ESO identity.
- Push wildcard cert material to Key Vault in required format.
- Ensure Key Vault object type/content-type align with App Gateway expectations.
- Define deterministic naming for Key Vault target object to support App Gateway versionless URI references.

### Phase 4: Application Gateway Cutover

13. Update deploy/terraform/ssl_app_gateway.tf:

- Switch from local cert creation inputs (create_ssl_cert, pfx_password, acme_email) to Key Vault reference.
- Use certificate_source = "key_vault" and key_vault_secret_id wiring.
- Use versionless Key Vault secret id for rotation.
- Ensure App Gateway identity is set (UserAssigned) and has Key Vault read role.
- Keep legacy inputs/provider in place until post-cutover validation gate passes.

14. After successful cutover and validation, remove ACME dependencies:

- Remove ACME provider from deploy/terraform/provider.tf.
- Remove acme_email and pfx_password from deploy/terraform/variables.tf and pipeline vars.
- Remove any obsolete outputs that expose certificate_pem/issuer_pem if no longer needed.
- Remove/replace ACME-era preconditions and test expectations tied to create_valid_cert behavior.

## Validation Gates

1. Terraform validation:

- eirctl run lint:terraform:format
- eirctl run lint:terraform:validate
- eirctl run infra:init
- eirctl run infra:plan
- Plan must show expected identity/RBAC/app-gateway changes only.

2. Helm/platform validation:

- eirctl run infra:helm:apply
- cert-manager, external-secrets, reflector deployments are Ready.
- CRDs exist: ClusterIssuer, Certificate, SecretStore, PushSecret.

3. Certificate issuance validation:

- ClusterIssuer Ready=True.
- wildcard Certificate Ready=True.
- Secret exists in cert-manager namespace.
- Reflection present in allowed namespaces.

4. Key Vault sync validation:

- PushSecret reports Synced.
- Key Vault contains expected certificate/secret object.

5. App Gateway validation:

- eirctl run tests
- Listener uses Key Vault certificate reference.
- HTTPS endpoint serves correct wildcard cert chain.
- Rotation test confirms no Terraform change required for secret version updates.

6. Pipeline/test regression validation:

- Confirm Azure DevOps pipeline succeeds end-to-end with eirctl-driven infra and helm stages.
- Confirm InSpec controls no longer rely on ACME-only assumptions after cutover.
- Confirm docs and setup prompts no longer require removed ACME variables once Task 15 completes.

## Rollback Strategy

1. Keep ACME resources in place until Key Vault path is proven in nonprod.
2. Gate production ACME endpoint switch behind explicit approval.
3. If cutover fails, revert App Gateway to previous certificate input path and re-apply Terraform.
4. Remove ACME provider/resources only after at least one successful renewal cycle in nonprod.

## eirctl Command Mapping (Mandatory)

Use this mapping during implementation and validation:

- YAML/Terraform lint: eirctl run lint
- Terraform fmt-only check: eirctl run lint:terraform:format
- Terraform validate-only: eirctl run lint:terraform:validate
- Terraform init/workspace: eirctl run infra:init
- Terraform plan: eirctl run infra:plan
- Terraform apply full workflow: eirctl run infrastructure
- Helm deployment: eirctl run infra:helm:apply
- Infrastructure tests: eirctl run tests

If a migration step needs an operation not covered above, add/approve an eirctl task first, then execute via eirctl.

## Task List

- [ ] Task 0: Complete preflight compatibility and prerequisite checks
- [ ] Task 1: Add acme_server variable and pipeline wiring
- [ ] Task 2: Ensure AKS OIDC + Workload Identity root wiring is explicit and validated
- [ ] Task 3: Create cert-manager and ESO identities with federated credentials and RBAC
- [ ] Task 4: Add required Terraform outputs for Helm templating and OIDC/federation dependencies
- [ ] Task 5: Add cert-manager Helm chart and values template
- [ ] Task 6: Add external-secrets Helm chart and values template
- [ ] Task 7: Add reflector Helm chart and values template
- [ ] Task 8: Update cluster-setup Helm values template with cert/key-vault inputs
- [ ] Task 9: Create ClusterIssuer template
- [ ] Task 10: Create wildcard Certificate template with reflector annotations
- [ ] Task 11: Create SecretStore and PushSecret templates
- [ ] Task 12: Cut over App Gateway to Key Vault certificate reference
- [ ] Task 13: Update ACME-era test/pipeline preconditions for transition compatibility
- [ ] Task 14: Run validation gates in nonprod using eirctl tasks only
- [ ] Task 15: Switch to production ACME endpoint after approval
- [ ] Task 16: Remove ACME provider and legacy cert inputs after stabilization
- [ ] Task 17: Update docs/prompts/setup guidance to remove ACME-era variable requirements
