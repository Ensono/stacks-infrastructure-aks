## Context

The current TLS flow depends on Terraform-managed ACME issuance and inline certificate material. This couples certificate lifecycle to infrastructure
apply operations and increases operational risk during renewals, state recovery, and cutovers. This migration moves certificate issuance and renewal
into Kubernetes-native controllers while preserving controlled rollback, explicit security boundaries, and existing eirctl pipeline conventions.

Target architecture:

```text
Terraform outputs / pipeline vars
  ├─ dns_zone, environment, Key Vault identifiers
  ├─ AKS OIDC issuer and workload identity enablement
  └─ managed identity client IDs
        │
        ▼
cert-manager DNS-01 ──► TLS Secret in cert-manager namespace
        │                         │
        │                         └─ reflector ──► ingress-nginx namespace by default
        ▼
External Secrets Operator PushSecret
        │
        ▼
Azure Key Vault
  ├─ env + sanitized-domain PFX secret for Application Gateway
  └─ env + sanitized-domain certificate object for certificate consumers
        │
        ▼
Application Gateway HTTPS listener via versionless Key Vault secret URI
```

Key constraints:

- All operational, validation, discovery, and rollback commands for this migration must run through eirctl tasks. If an operation is not represented
  by eirctl, add a granular eirctl task before using it.
- eirctl tasks must redact certificate/private-key/Key Vault secret material from stdout/stderr, logs, traces, pipeline artifacts, validation reports,
  and failure messages.
- Existing ACME path must remain available until nonprod issuance, sync, App Gateway cutover, forced renewal, rollback, production stabilization, and
  regression gates pass.
- App Gateway certificate cutover must use a versionless Key Vault secret URI and managed identity.
- AKS identity federation depends on OIDC issuer and workload identity wiring.
- ClusterIssuer usage must be constrained so wildcard/apex issuance is only available to approved platform workloads.
- The prompt file `.github/prompts/plan-certManagerAkvMigration.prompt.md` is source input, not current state; this OpenSpec change is the
  authoritative migration plan.

Stakeholders include platform engineering, security/compliance reviewers, and service teams consuming wildcard TLS certificates.

## Goals / Non-Goals

**Goals:**

- Establish Kubernetes-native wildcard certificate lifecycle using cert-manager with Let's Encrypt ACME DNS-01.
- Issue a certificate containing both `*.${dns_zone}` and `${dns_zone}` DNS names.
- Restrict migration ClusterIssuer use to approved platform namespaces/service accounts and expected DNS names.
- Replicate issued wildcard certificate from the `cert-manager` namespace only to approved platform-owned namespaces, defaulting to `ingress-nginx`.
- Synchronize certificate artifacts to Azure Key Vault as both an App Gateway-compatible PFX secret and a certificate object.
- Cut Application Gateway to a Key Vault certificate source with no manual secret-version pinning.
- Enforce Application Gateway/frontend TLS policy of TLS 1.2+ during and after cutover.
- Validate each new Key Vault certificate version before considering App Gateway rotation healthy, including RSA 2048+ or ECDSA P-256/P-384 key
  policy.
- Preserve automatic rollback to the legacy App Gateway certificate path if cutover validation fails.
- Use staging and production ClusterIssuers, with production usage controlled by pipeline variable after nonprod gates pass.
- Keep execution paths aligned with eirctl-only pipeline/task conventions.
- Capture audit logs, monitoring/alerting proof, and compliance evidence for every migration gate with secrets redacted.
- Verify Helm chart and controller image supply-chain controls for approved sources, immutable versions, provenance/checksum validation where
  supported, and image tag/digest evidence.
- Conditionally remove aad-pod-identity only when eirctl runtime and declarative inventory checks prove no active or dormant users.

**Non-Goals:**

- Replacing eirctl with direct Terraform/Helm/Kubectl/Azure CLI operations.
- Broad ingress-controller migration unrelated to certificate lifecycle.
- Redesigning all existing platform chart topology beyond migration necessities.
- Migrating arbitrary aad-pod-identity consumers to Workload Identity in this change.
- Granting tenant namespaces unrestricted access to wildcard certificate private keys.
- Removing ACME-era variables/tests/docs before production stabilization gates are complete.

## Decisions

1. Certificate lifecycle ownership moves from Terraform ACME resources to cert-manager resources.

- Rationale: decouples renewal from infrastructure apply cycles and aligns with Kubernetes controller patterns.
- Certificate DNS names are `*.${var.dns_zone}` and `${var.dns_zone}`.
- A new `cert_manager_acme_email` variable replaces legacy `acme_email` for cert-manager ACME account registration.
- Alternatives considered:
  - Keep Terraform ACME and add automation around state recovery: rejected due to continued coupling and prior fallback risks.
  - Use manual certificate import into Key Vault: rejected due to operational overhead and renewal fragility.

2. cert-manager will use two ClusterIssuers: staging and production.

- Rationale: allows nonprod validation against Let's Encrypt staging while keeping production endpoint activation explicit.
- Production endpoint/issuer selection is controlled through pipeline/eirctl configuration after nonprod gates pass; Terraform defaults remain
  staging-safe.
- Production cutover requires explicit production gates: production ClusterIssuer Ready, production Certificate Ready, expected production issuer
  chain, Key Vault production object version created, App Gateway listener serving the production chain, and environment approval.

3. ClusterIssuer usage requires explicit authorization controls.

- Rationale: cluster-scoped issuers plus DNS-zone write identity can become an unauthorized certificate issuance path.
- Implement Kubernetes RBAC/admission controls or cert-manager approval policy so only approved platform namespaces/service accounts can create or
  approve Certificates/CertificateRequests that reference migration ClusterIssuers.
- Enforce expected DNS names for `*.${dns_zone}` and `${dns_zone}` only.
- Add eirctl negative validation proving an unapproved namespace cannot obtain a certificate from the migration ClusterIssuers.

4. Kubernetes certificate resources live in the existing `cluster-setup` Helm chart after controller readiness is established.

- Rationale: keeps migration-owned ClusterIssuer, Certificate, SecretStore, and PushSecret templates with existing cluster bootstrap resources while
  avoiding CRD/webhook races.
- Source TLS Secret lives in the `cert-manager` namespace.
- Reflection uses an explicit namespace allow-list and defaults to `ingress-nginx` only.
- cert-manager, external-secrets, and reflector charts must be ordered before `cluster-setup`, or `cluster-setup` dependent resources must run in a
  second eirctl Helm pass after controller rollout checks, CRDs, and webhooks are ready.

5. Wildcard private key replication is treated as privileged platform distribution.

- Rationale: each reflected Secret contains the wildcard private key.
- Recipient namespaces must be platform-owned or explicitly security-approved.
- Recipient namespace RBAC must avoid broad `get/list secrets` grants and tenant write access to the reflected Secret.
- Adding namespaces beyond `ingress-nginx` requires an explicit allow-list change and security approval.

6. External Secrets Operator support for both Key Vault object types is a first hard preflight proof.

- Required outputs:
  - PFX Key Vault secret with App Gateway-compatible content type.
  - Key Vault certificate object for long-term certificate consumer compatibility.
- Preflight must document the exact supported mechanism, CRD/provider fields, PFX conversion path, content type, Key Vault certificate import
  semantics, versioning behavior, and failure semantics.
- If ESO and repository-supported templating cannot produce both object types reliably, migration is blocked before Terraform identity, chart rollout,
  or App Gateway cutover work proceeds.

7. Key Vault object naming must be explicit per object type.

- Deterministic names use environment plus sanitized DNS domain.
- The PFX secret and certificate object must have distinct, documented final names or an explicit proof that Azure Key Vault permits the intended
  same-name layout without conflicting with certificate backing secrets.
- Preflight must assert expected object names do not collide with existing Key Vault objects.

8. App Gateway will consume Key Vault certificate via versionless secret URI and UserAssigned managed identity.

- Rationale: supports rotation without Terraform value churn and aligns with module support for `key_vault` certificate source.
- Existing App Gateway identity is reused when module support/exposure exists; a dedicated UserAssigned identity is created only if no suitable
  identity exists.
- Each new Key Vault version must pass eirctl integrity validation before rotation is considered healthy: SAN exact set, issuer chain, key type/size,
  expiry window, content type, and environment/domain naming.
- Alternatives considered:
  - Version-pinned secret URI: rejected due to operational version update burden.
  - Continue inline certificate upload: rejected due to state sensitivity and rotation friction.

9. Workload identity federation will use separate managed identities for cert-manager and external-secrets.

- cert-manager identity receives the least Azure DNS built-in role and smallest DNS-zone scope that permits DNS-01 challenge writes.
- external-secrets identity receives exact built-in Key Vault role assignments at the narrowest feasible scope needed to create/update the required
  PFX secret and certificate object.
- App Gateway identity receives exact built-in Key Vault read role assignments at the narrowest feasible scope needed to retrieve the certificate
  secret.
- If object-scoped Key Vault RBAC is not feasible for required write/read behavior, prefer a dedicated Key Vault for this certificate path rather than
  whole-vault broad access to unrelated secrets.
- eirctl validation must prove identities cannot read/write/list unrelated Key Vault objects.
- Alternatives considered:
  - Shared controller identity: rejected due to broader blast radius.
  - Reuse AKS identity: rejected due to weak isolation.
  - Custom roles: rejected for this change due to extra policy complexity; built-in least-scope roles are preferred.

10. Chart versions are pinned in this proposal before implementation begins.

- Initial pins:
  - cert-manager chart `v1.20.2` from `https://charts.jetstack.io`
  - external-secrets chart `2.5.0` from `https://charts.external-secrets.io`
  - reflector chart `10.0.46` from `https://emberstack.github.io/helm-charts`
- Preflight must verify service account names, CRD flags, and PushSecret support for these exact versions before Terraform identity/federation work
  proceeds.

11. Migration remains dual-mode until production stabilization gates pass.

- Required nonprod gates: issuer readiness, certificate readiness, issuer authorization checks, reflection, PushSecret sync, Key Vault secret and
  certificate object presence, Key Vault version integrity, App Gateway TLS chain validation, forced renewal/rotation, reflected-secret renewal
  propagation, rollback dry-run/rehearsal, and regression tests.
- Required production gates: production issuer readiness, production certificate readiness, production chain validation, Key Vault production version
  integrity, App Gateway production listener validation, production forced-renewal or approved equivalent rotation proof, regression tests, and
  explicit environment approval.
- Rationale: ensures rollback path remains intact until both nonprod and production paths prove stable.
- Alternatives considered:
  - One-step hard switch and immediate ACME removal: rejected due to elevated outage risk.

12. Cutover failure triggers an automatic revert path with a defined contract.

- If App Gateway cannot retrieve/serve the Key Vault-backed certificate, eirctl rollback tasks revert App Gateway to the legacy certificate source
  while keeping cert-manager/ESO/reflector installed for diagnosis.
- Rollback contract must define task names, inputs, idempotency, timeout/retry behavior, failure detection criteria, automatic pipeline invocation
  point, expected Terraform state transition, and mandatory post-rollback listener certificate-chain validation.
- Full uninstall of controllers is not part of automatic rollback.

13. All operations in this change use eirctl commands with named contracts.

- Rationale: preserves repository conventions, repeatability, and CI parity.
- Direct Terraform, Helm, kubectl, or Azure CLI commands are not permitted for routine execution, discovery, validation, or rollback.
- Missing checks must be added as granular eirctl tasks before use.
- Early implementation must define eirctl task names, inputs, outputs, exit codes, idempotency, timeouts, expected failure modes, and secret-output
  classification for discovery, validation, forced renewal, Key Vault checks, App Gateway checks, authorization negative tests, and rollback.
- eirctl outputs must never include PFX, PEM, private key, token, client secret, Key Vault secret value, or Kubernetes Secret data. Allowed evidence
  is limited to fingerprints, serial numbers, object names, versions, expiry, issuer, SANs, and non-secret metadata.

14. aad-pod-identity removal is conditional.

- Remove aad-pod-identity chart and AzureIdentity/AzureIdentityBinding resources only if eirctl runtime and declarative inventory validation proves no
  active or dormant workloads use aad-pod-identity selectors.
- Inventory must include pods, Deployments, StatefulSets, DaemonSets, Jobs, CronJobs, AzureIdentity, AzureIdentityBinding, and pod-template selector
  labels across all namespaces.
- If runtime or declarative users are found, leave aad-pod-identity installed, continue the cert-manager migration, and record a follow-up cleanup
  task.

15. Legacy certificate outputs and variables are removed only after production stabilization.

- Remove `certificate_pem`, `issuer_pem`, `pfx_password`, and obsolete ACME-era inputs/pipeline vars after nonprod gates, production cutover,
  production stabilization, forced-renewal/rotation proof, rollback rehearsal/dry-run, and regression gates pass.
- Prefer a final cleanup phase and keep rollback material available until cleanup eligibility is explicitly validated.

16. Cryptographic policy is explicit and validated.

- Application Gateway/frontend TLS policy must allow TLS 1.2 or newer only; TLS 1.0/1.1 must not be enabled during or after cutover.
- Managed certificate keys must be RSA 2048-bit or stronger, or ECDSA P-256/P-384. eirctl validation must fail weaker or unexpected key parameters
  before cutover, production activation, or cleanup.

17. Chart and image supply-chain controls are part of migration readiness.

- Pinned Helm chart repositories and versions must be approved before rollout.
- Chart provenance/signature or checksum verification must be captured where supported by the source repository/tooling.
- Controller images must come from approved registries and use pinned tags or digests; mutable `latest` references are not permitted.
- Supply-chain evidence must record chart repository/name/version, verification result, resolved image repository/tag/digest, and allow-list status.

18. Audit logging, monitoring, and compliance evidence are required gates.

- Monitoring must cover cert-manager issuance/renewal, ESO PushSecret sync failures, Key Vault secret/certificate version changes, Key Vault access
  denials, App Gateway certificate retrieval/listener health, and eirctl rollback invocation.
- Compliance evidence for each gate must include eirctl task/run identity, timestamp, environment, sanitized inputs, pass/fail result, approver where
  required, certificate fingerprint/serial/expiry, Key Vault object/version metadata, App Gateway validation result, TLS policy proof, supply-chain
  verification result, and audit/alert configuration proof.
- Evidence artifacts must be stored in the approved pipeline/evidence location and must obey the eirctl redaction contract.

## Risks / Trade-offs

- [Unauthorized certificate issuance through ClusterIssuer] -> Add RBAC/admission or cert-manager approval policy plus negative eirctl tests before
  enabling issuers broadly.
- [Service account name mismatch with federated credential subject] -> Validate exact chart SA names for pinned chart versions before creating
  credentials.
- [AKS workload identity not fully enabled despite OIDC] -> Add preflight gate to verify both cluster knobs and issuer availability before identity
  resources.
- [ESO cannot produce both PFX secret and Key Vault certificate object] -> Block migration as the first hard preflight until supported path is
  identified.
- [PFX content type incompatible with App Gateway] -> Validate object content type and listener provisioning in nonprod before production.
- [Broad Key Vault permissions expose unrelated secrets] -> Use exact role names/scopes, object-scoped assignments where feasible, or a dedicated Key
  Vault for this certificate path.
- [Versionless URI silently consumes bad certificate version] -> Validate every new version's SANs, issuer, key parameters, expiry, content type, and
  object naming before marking rotation healthy.
- [Secrets leak through validation tooling] -> Add eirctl redaction requirements and regression checks for stdout/stderr, logs, traces, artifacts,
  reports, and failure paths before handling certificate or Key Vault data.
- [Weak TLS/key policy is accepted during cutover] -> Enforce TLS 1.2+ and RSA 2048+ or ECDSA P-256/P-384 in templates and eirctl validation before
  App Gateway cutover or production activation.
- [Controller artifact supply-chain drift] -> Pin/approve chart repositories and image sources, capture provenance/checksum where supported, and
  record resolved image tags/digests.
- [Audit/compliance evidence is incomplete] -> Make monitoring, alerting, audit-log, and sanitized evidence capture explicit nonprod/production gates.
- [Transition test failures from ACME-era assumptions] -> Update pipeline/test gates before ACME removal and run eirctl tests in nonprod.
- [Chart rollout race conditions with CRDs/webhooks] -> Pin versions, order controllers before dependent resources, and include rollout/CRD/webhook
  checks.
- [aad-pod-identity dormant consumers exist] -> Keep aad-pod-identity installed unless runtime and declarative inventory checks prove no users.
- [Required AppGW/AKS module capability missing after allowed version bump] -> Stop as blocker rather than bypassing module boundaries.

## Migration Plan

1. Prove first hard blockers: ESO Key Vault PFX secret plus certificate object support, AppGW/AKS module support, workload identity prerequisites,
   chart pins, service account names, object naming, RBAC scope feasibility, and aad-pod-identity runtime/declarative inventory approach.
2. Add any required module version bump task before migration tasks. If required capability remains unsupported after the allowed bump, stop as
   blocker.
3. Define granular eirctl task contracts for all discovery, validation, forced renewal, authorization negative checks, Key Vault checks, App Gateway
   checks, rollback, and cleanup eligibility checks before using them, including secret-output classification and redaction tests.
4. Verify Helm chart and controller image supply-chain controls for approved sources, immutable pins, provenance/checksum where supported, and
   resolved image tag/digest evidence.
5. Introduce issuer authorization controls and recipient namespace security requirements.
6. Introduce identities, federation, narrowly scoped role assignments, and Terraform outputs required for chart templating.
7. Deploy cert-manager, external-secrets, and reflector through eirctl Helm workflow using pinned versions; validate rollout, CRDs, and webhooks
   before dependent resources.
8. Apply ClusterIssuer/Certificate/SecretStore/PushSecret templates through `cluster-setup` only after controller readiness and validate readiness.
9. Validate nonprod issuance, issuer authorization negative tests, reflection allow-list, PushSecret sync, Key Vault object presence, object naming,
   RBAC boundaries, Key Vault version integrity, TLS 1.2+ policy, and cryptographic key policy.
10. Validate audit logging, monitoring, alerting, and sanitized compliance evidence capture in nonprod.
11. Define and validate rollback readiness before changing App Gateway certificate source.
12. Cut Application Gateway to Key Vault certificate source and validate listener certificate chain and TLS policy.
13. Force nonprod certificate renewal and validate source TLS Secret, reflected Secret fingerprints, Key Vault version updates, version integrity, and
    Application Gateway consumption without Terraform URI changes.
14. If cutover validation fails, run eirctl rollback to legacy App Gateway certificate path while preserving controller state for investigation;
    validate listener serves the legacy certificate chain.
15. After nonprod gates pass, enable production issuer/endpoint through pipeline configuration and complete production cutover path in this change.
16. Complete production stabilization gates, including production chain validation, Key Vault version integrity, App Gateway listener validation,
    production rotation proof or approved equivalent, monitoring/audit proof, compliance evidence package, regression tests, and environment approval.
17. Remove legacy ACME dependencies, sensitive outputs, `pfx_password`, and obsolete docs/tests only after cleanup eligibility gates pass.
18. Conditionally remove aad-pod-identity only when runtime and declarative inventory validation prove no active or dormant users.
19. Finalize docs, setup guidance, runbook, alerting expectations, supply-chain review cadence, compliance evidence retention, and ownership updates.

## Open Questions

No product/spec decisions remain open. Remaining items are technical preflight proofs captured in tasks:

- Verify ESO support for required PFX secret and Key Vault certificate object creation with pinned chart/provider versions.
- Verify exact service account names and CRD flags for pinned chart versions.
- Verify App Gateway and AKS module support, including any required version bump.
- Verify feasible Key Vault RBAC role names/scopes or need for a dedicated Key Vault.
- Verify exact PFX secret and certificate object names and collision behavior.
- Verify runtime and declarative aad-pod-identity usage before conditional removal.
