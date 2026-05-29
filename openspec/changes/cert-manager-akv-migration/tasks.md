## 1. Preflight And Safety Gates

- [ ] 1.1 Verify AKS module/root wiring exposes and enables OIDC issuer and workload identity for the target cluster
- [ ] 1.2 Confirm App Gateway module inputs for key_vault certificate_source, versionless URI, and managed identity are available at pinned version
- [ ] 1.3 Pin cert-manager, external-secrets, and reflector chart versions and confirm service account names/CRD flags for those versions
- [ ] 1.4 Validate DNS delegation/write permissions, Key Vault RBAC mode, and App Gateway identity read access prerequisites
- [ ] 1.5 Inventory ACME-era references (acme_email, pfx_password, create_valid_cert, certificate_pem, issuer_pem) across pipeline/tests/docs for transition planning

## 2. Terraform Identity And Output Wiring

- [ ] 2.1 Add acme_server variable for cert-manager issuer configuration and wire pipeline variable without changing default create_key_vault behavior
- [ ] 2.2 Add cert-manager and external-secrets user-assigned identities and federated identity credentials with exact subject/issuer matching
- [ ] 2.3 Add DNS and Key Vault role assignments with least privilege required for issuance and PushSecret synchronization
- [ ] 2.4 Add/verify outputs needed by Helm templating (identity client IDs, OIDC issuer URL dependency, Key Vault identifiers)
- [ ] 2.5 Keep ACME provider and legacy variables intact through transition until post-cutover gates pass

## 3. Helm Charts, Values, And Templates

- [ ] 3.1 Add cert-manager, external-secrets, and reflector chart entries to k8s_apps.yaml using values_template and rollout checks
- [ ] 3.2 Create values files for cert-manager, external-secrets, and reflector with workload identity annotations and version-specific options
- [ ] 3.3 Update cluster_setup values with acmeServer, DNS inputs, identity client IDs, Key Vault name, and reflection namespace allow-list
- [ ] 3.4 Add ClusterIssuer and wildcard Certificate templates for DNS-01 and reflector annotations
- [ ] 3.5 Add SecretStore and PushSecret templates with deterministic Key Vault object naming and expected object type/content-type

## 4. App Gateway Cutover And Transition Cleanup

- [ ] 4.1 Update ssl_app_gateway wiring to key_vault certificate_source, versionless key_vault_secret_id, and UserAssigned identity inputs
- [ ] 4.2 Ensure App Gateway identity has required Key Vault read role and validate listener uses Key Vault-backed TLS certificate
- [ ] 4.3 Update transition preconditions/tests so nonprod validation no longer depends on ACME-only assumptions during cutover
- [ ] 4.4 After nonprod stabilization and approval, remove ACME provider and legacy certificate inputs/outputs

## 5. Validation, Rollback, And Documentation

- [ ] 5.1 Run lint and terraform validation via eirctl only (eirctl run lint, eirctl run lint:terraform:format, eirctl run lint:terraform:validate)
- [ ] 5.2 Run init/plan/apply via eirctl only (eirctl run infra:init, eirctl run infra:plan, eirctl run infrastructure) and review expected diffs
- [ ] 5.3 Deploy platform charts via eirctl run infra:helm:apply and verify cert-manager, ESO, reflector readiness plus CRD availability
- [ ] 5.4 Validate issuer/certificate readiness, PushSecret synchronization, Key Vault object presence, and App Gateway TLS chain behavior
- [ ] 5.5 Validate rotation behavior shows no steady-state Terraform input change for versionless URI path
- [ ] 5.6 Run eirctl run tests and ensure pipeline and InSpec gates pass with updated expectations
- [ ] 5.7 Update docs/setup prompts to remove ACME-era requirements after cleanup completes
