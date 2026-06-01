## 1. First Hard Preflight And Safety Gates

- [ ] 1.1 Prove ESO can synchronize both required Key Vault outputs before downstream migration work: App Gateway-compatible PFX secret and Key Vault
      certificate object; block migration if both cannot be supported
- [ ] 1.2 Document exact ESO mechanism, CRD/provider fields, PFX conversion path, content type, Key Vault certificate import semantics, versioning
      behavior, and failure semantics
- [ ] 1.3 Verify AKS module/root wiring exposes and enables OIDC issuer and workload identity for the target cluster
- [ ] 1.4 Confirm App Gateway module inputs for `certificate_source = "key_vault"`, versionless `key_vault_secret_id`, and managed identity wiring are
      available at the pinned module version
- [ ] 1.5 If AKS/AppGW module support is missing, add a module version bump task before migration tasks; stop as blocker if required capability
      remains unsupported after the allowed bump
- [ ] 1.6 Pin and verify chart versions before implementation: cert-manager `v1.20.2`, external-secrets `2.5.0`, reflector `10.0.46`
- [ ] 1.7 Verify Helm chart and container-image supply-chain controls for pinned controllers: approved repositories, immutable chart versions, chart
      provenance/signature or checksum validation where supported, pinned/allow-listed image registries, image tags/digests, and no mutable `latest`
      references
- [ ] 1.8 Confirm exact service account names, workload identity annotation paths, CRD install flags, and PushSecret support for pinned chart versions
- [ ] 1.9 Define exact Key Vault PFX secret and certificate object names, including collision behavior with Key Vault certificate backing secrets
- [ ] 1.10 Validate DNS zone delegation/write prerequisites, Key Vault RBAC mode, feasible role scopes, App Gateway identity read access
      prerequisites, and PFX content type expected by Application Gateway
- [ ] 1.11 Add eirctl runtime and declarative inventory preflight for aad-pod-identity users before any aad-pod-identity removal decision
- [ ] 1.12 Inventory ACME-era references (`acme_email`, `pfx_password`, `create_valid_cert`, `certificate_pem`, `issuer_pem`) across
      pipeline/tests/docs for transition and cleanup planning

## 2. eirctl Contracts And Security Controls

- [ ] 2.1 Add granular eirctl task contracts before use for discovery, validation, forced renewal, issuer authorization negative tests, Key Vault
      checks, App Gateway checks, rollback, and cleanup eligibility; direct terraform/helm/kubectl/az commands are not permitted
- [ ] 2.2 Define each new eirctl task name, inputs, outputs, exit codes, idempotency expectations, timeout/retry behavior, expected failure mode, and
      secret-output classification
- [ ] 2.3 Add mandatory eirctl secret redaction requirements for migration tasks: no PFX, PEM, private key, token, client secret, Key Vault secret
      value, or kube Secret data may appear in stdout/stderr, logs, traces, pipeline artifacts, validation reports, or failure messages; fingerprints,
      serial numbers, object names, versions, and non-secret metadata are allowed
- [ ] 2.4 Add automated redaction regression checks for eirctl tasks that handle certificate or Key Vault data, including negative tests with
      representative secret patterns and failure-output paths
- [ ] 2.5 Add issuer authorization controls so only approved platform namespaces/service accounts can create or approve
      Certificates/CertificateRequests for migration ClusterIssuers
- [ ] 2.6 Add eirctl negative validation proving unapproved namespaces cannot obtain certificates from migration ClusterIssuers
- [ ] 2.7 Define reflected-secret recipient namespace security requirements: platform-owned or security-approved, restricted secret-read RBAC, and no
      tenant write access to reflected Secret
- [ ] 2.8 Add Key Vault audit/validation expectations for new certificate versions and unexpected certificate attribute changes
- [ ] 2.9 Add audit logging and monitoring requirements covering cert-manager issuance/renewal events, ESO PushSecret sync failures, Key Vault
      secret/certificate version changes, Key Vault access denied events, App Gateway certificate retrieval/listener health, and eirctl rollback
      invocations
- [ ] 2.10 Define explicit compliance evidence capture for each gate: eirctl command/task name, run ID, timestamp, environment, sanitized inputs,
      pass/fail result, approver where required, certificate fingerprint/serial/expiry, Key Vault object/version metadata, App Gateway listener
      validation result, and alert/audit configuration proof

## 3. Terraform Identity And Output Wiring

- [ ] 3.1 Add `cert_manager_acme_email` and ACME issuer selection/pipeline wiring while keeping staging as the safe default until nonprod gates pass
- [ ] 3.2 Add separate cert-manager and external-secrets user-assigned identities and federated identity credentials with exact subject/issuer
      matching for pinned chart service accounts
- [ ] 3.3 Add exact least built-in Azure DNS role assignment for cert-manager at the smallest feasible DNS zone scope
- [ ] 3.4 Add exact least built-in Key Vault role assignments for external-secrets to create/update both PFX secret and certificate object at the
      narrowest feasible scope
- [ ] 3.5 Reuse existing App Gateway UserAssigned identity when supported/exposed; create a dedicated App Gateway identity only if no suitable
      identity exists
- [ ] 3.6 Add exact least built-in Key Vault read role assignment for the App Gateway identity at the narrowest feasible scope
- [ ] 3.7 If object-scoped Key Vault RBAC is not feasible, prefer a dedicated Key Vault for this certificate path rather than broad access to
      unrelated secrets
- [ ] 3.8 Add/verify outputs needed by Helm templating: identity client IDs, OIDC issuer URL dependency, Key Vault identifiers, DNS zone, environment,
      deterministic object names, and authorization settings
- [ ] 3.9 Keep ACME provider and legacy variables intact through transition until production stabilization and cleanup eligibility gates pass

## 4. Helm Charts, Values, And Templates

- [ ] 4.1 Add cert-manager chart `v1.20.2`, external-secrets chart `2.5.0`, and reflector chart `10.0.46` to `deploy/helm/k8s_apps.yaml` using
      `values_template`
- [ ] 4.2 Ensure cert-manager, external-secrets, and reflector deploy before `cluster-setup`, or split dependent `cluster-setup` resources into a
      second eirctl Helm pass after controller readiness
- [ ] 4.3 Create values files for cert-manager, external-secrets, and reflector with workload identity annotations and pinned-version-specific options
- [ ] 4.4 Update `cluster-setup` values with `cert_manager_acme_email`, issuer selection, DNS inputs, identity client IDs, Key Vault name/URI inputs,
      environment, deterministic object names, reflection namespace allow-list, and issuer authorization settings
- [ ] 4.5 Add two ClusterIssuer templates in `cluster-setup`: `letsencrypt-staging` and `letsencrypt-prod`
- [ ] 4.6 Add Certificate template in `cluster-setup` that stores the source TLS Secret in the `cert-manager` namespace and includes both
      `*.${dns_zone}` and `${dns_zone}` DNS names
- [ ] 4.7 Add reflector annotations/templates so only explicitly allowed namespaces receive the reflected secret, defaulting to `ingress-nginx`
- [ ] 4.8 Add SecretStore and PushSecret templates with workload identity authentication, deterministic per-object naming, PFX secret output,
      certificate object output, content type, and status conditions used by validation
- [ ] 4.9 Configure certificate private-key policy and validation defaults to enforce RSA 2048+ or ECDSA P-256/P-384 only; reject weaker keys during
      eirctl validation
- [ ] 4.10 Add chart/image supply-chain metadata to deployment configuration or evidence output: chart repository URL, chart name/version,
      provenance/checksum verification result where supported, resolved image repository/tag/digest, and approved registry status
- [ ] 4.11 Ensure cluster-setup chart rendering remains compatible when aad-pod-identity resources are retained or conditionally disabled

## 5. Nonprod Validation And Forced Renewal

- [ ] 5.1 Run lint and Terraform validation via eirctl only (`eirctl run lint`, `eirctl run lint:terraform:format`, `eirctl run
      lint:terraform:validate`)
- [ ] 5.2 Run init/plan/apply via eirctl only (`eirctl run infra:init`, `eirctl run infra:plan`, `eirctl run infra:apply`) and review expected diffs
- [ ] 5.3 Deploy platform charts via `eirctl run infra:helm:apply` and verify cert-manager, ESO, reflector readiness plus CRD/webhook availability
      through granular eirctl validation tasks
- [ ] 5.4 Validate staging and production ClusterIssuer resources exist, with staging used for initial nonprod issuance
- [ ] 5.5 Validate certificate readiness for both wildcard and apex DNS names
- [ ] 5.6 Validate issuer authorization controls, including successful approved issuance and failed unapproved namespace issuance
- [ ] 5.7 Validate reflected TLS Secret exists in `ingress-nginx` by default and does not exist in unapproved namespaces
- [ ] 5.8 Validate recipient namespace RBAC/security preconditions before allowing additional reflected namespaces beyond `ingress-nginx`
- [ ] 5.9 Validate PushSecret synchronization and confirm both Key Vault objects exist with deterministic non-conflicting names
- [ ] 5.10 Validate Key Vault RBAC boundaries: ESO cannot affect unrelated objects and App Gateway identity cannot list/read unrelated secrets
- [ ] 5.11 Validate each new Key Vault version's SAN set, issuer chain, key type/size, signature algorithm, expiry window, content type, and
      environment/domain naming; cryptographic validation MUST require RSA 2048+ or ECDSA P-256/P-384
- [ ] 5.12 Validate App Gateway/frontend TLS policy allows TLS 1.2 or newer only and does not enable TLS 1.0/1.1 during or after cutover
- [ ] 5.13 Validate nonprod audit logging, alert rules, diagnostic settings, and monitoring queries fire or can be queried for certificate issuance,
      Key Vault version creation/access failures, ESO sync failures, and App Gateway certificate-read/listener health
- [ ] 5.14 Capture nonprod compliance evidence package with secrets redacted and store it in the approved pipeline/evidence location
- [ ] 5.15 Define and dry-run/rehearse App Gateway rollback readiness before changing Application Gateway certificate source
- [ ] 5.16 Force nonprod cert-manager renewal/reissue through eirctl task and prove source TLS Secret updates, reflected Secret fingerprints match
      source, Key Vault object versions update, Terraform `key_vault_secret_id` remains versionless and unchanged, and compliance evidence records
      renewed fingerprint/serial without exposing secret material

## 6. Application Gateway Cutover And Rollback

- [ ] 6.1 Update `ssl_app_gateway` wiring to Key Vault certificate source using a versionless `key_vault_secret_id` pointing at the PFX Key Vault
      secret only after rollback readiness passes
- [ ] 6.2 Ensure App Gateway identity has required Key Vault read role and validate listener uses the Key Vault-backed TLS certificate
- [ ] 6.3 Add automatic eirctl rollback path that reverts App Gateway to the legacy certificate source if cutover validation fails while leaving
      cert-manager/ESO/reflector installed for diagnosis
- [ ] 6.4 Define rollback triggers, timeout, idempotency, expected Terraform state transition, automatic pipeline invocation point, and post-rollback
      listener certificate-chain validation
- [ ] 6.5 Update transition preconditions/tests so nonprod validation no longer depends on ACME-only assumptions during cutover
- [ ] 6.6 Validate App Gateway cutover preserves TLS 1.2+ frontend policy and records listener certificate-chain evidence without
      certificate/private-key disclosure
- [ ] 6.7 Run `eirctl run tests` and ensure pipeline and InSpec gates pass with updated expectations

## 7. Production Activation And Stabilization

- [ ] 7.1 Enable production issuer/endpoint through pipeline configuration after nonprod gates pass and explicit environment approval is recorded
- [ ] 7.2 Validate production ClusterIssuer Ready and production Certificate Ready before production App Gateway cutover
- [ ] 7.3 Validate production certificate uses expected production issuer chain and is not a staging-chain certificate
- [ ] 7.4 Validate production Key Vault PFX secret and certificate object versions exist with expected object names and version integrity
- [ ] 7.5 Validate production App Gateway listener serves the expected production certificate chain from the versionless Key Vault secret URI
- [ ] 7.6 Complete production forced-renewal/rotation proof or approved equivalent rotation validation before cleanup eligibility
- [ ] 7.7 Validate production monitoring, alerting, and audit logs are enabled and queryable for certificate renewal/sync/cutover signals
- [ ] 7.8 Capture production compliance evidence package, including explicit production approval, sanitized eirctl outputs, certificate
      fingerprint/serial/expiry, Key Vault object/version metadata, App Gateway listener validation, TLS policy proof, and supply-chain verification
      results
- [ ] 7.9 Re-run regression tests and record production stabilization completion

## 8. Cleanup, aad-pod-identity, And Documentation

- [ ] 8.1 Validate cleanup eligibility: nonprod gates, production cutover, production stabilization, forced-renewal/rotation proof, rollback
      rehearsal/dry-run, and regression gates all passed
- [ ] 8.2 After cleanup eligibility passes, remove ACME provider and legacy certificate inputs/outputs including `pfx_password`, `certificate_pem`,
      and `issuer_pem`
- [ ] 8.3 Remove aad-pod-identity chart and AzureIdentity/AzureIdentityBinding resources only if eirctl runtime and declarative inventory preflight
      proves no active or dormant users; otherwise keep them and record follow-up cleanup
- [ ] 8.4 Update docs/setup prompts to remove ACME-era requirements after cleanup completes
- [ ] 8.5 Add post-migration ownership/runbook updates: responsible team, renewal/expiry alerts, sync failure alerts, App Gateway certificate-read
      alerts, Key Vault version-change audit expectations, chart/image supply-chain review cadence, compliance evidence retention location, redaction
      expectations, and incident response steps
- [ ] 8.6 Finalize compliance evidence index mapping every required gate to stored evidence artifacts before archive
