## Context

The current repository manages Application Gateway certificates through Terraform ACME and inline certificate material, while cluster bootstrap and platform components are deployed through eirctl-managed Terraform and Helm workflows. The migration introduces cert-manager, reflector, and External Secrets Operator to move certificate lifecycle management into Kubernetes, push certificate artifacts to Azure Key Vault, and re-point Application Gateway to a Key Vault-backed certificate reference.

Key constraints:
- Operational commands must be executed via eirctl task orchestration.
- Existing ACME path must remain available until nonprod validation and rollback confidence are established.
- App Gateway certificate cutover must use versionless Key Vault URI and managed identity.
- AKS identity federation depends on OIDC issuer and workload identity wiring.

Stakeholders include platform engineering, security/compliance reviewers, and service teams consuming wildcard TLS certificates.

## Goals / Non-Goals

**Goals:**
- Establish Kubernetes-native wildcard certificate lifecycle using cert-manager with ACME DNS-01.
- Replicate issued wildcard certificate to approved namespaces and synchronize to Azure Key Vault.
- Cut Application Gateway to Key Vault certificate source with no manual secret-version pinning.
- Preserve safe rollback and staged rollout controls (staging first, production after gate approval).
- Keep execution paths aligned with existing eirctl pipeline/task conventions.

**Non-Goals:**
- Replacing eirctl with direct Terraform/Helm/Kubectl operations.
- Broad ingress-controller migration unrelated to certificate lifecycle.
- Redesigning all existing platform chart topology beyond migration necessities.
- Immediate removal of all ACME-era variables/tests/docs before transition gates are complete.

## Decisions

1. Certificate lifecycle ownership moves from Terraform ACME resources to cert-manager resources.
- Rationale: decouples renewal from infrastructure apply cycles and aligns with Kubernetes controller patterns.
- Alternatives considered:
  - Keep Terraform ACME and add automation around state recovery: rejected due to continued coupling and prior fallback risks.
  - Use manual certificate import into Key Vault: rejected due to operational overhead and renewal fragility.

2. App Gateway will consume Key Vault certificate via versionless secret URI and UserAssigned managed identity.
- Rationale: supports rotation without Terraform value churn and aligns with module support for key_vault certificate_source.
- Alternatives considered:
  - Version-pinned secret URI: rejected due to operational version update burden.
  - Continue inline certificate upload: rejected due to state sensitivity and rotation friction.

3. Workload identity federation will be created for cert-manager and external-secrets service accounts only for this change.
- Rationale: least-scope identity provisioning for migration-critical controllers.
- Alternatives considered:
  - Broader identity rollout across all charts in this change: rejected to limit blast radius.

4. Migration remains dual-mode until nonprod gates (issuance, sync, ingress cert validation, and rotation) pass.
- Rationale: ensures rollback path remains intact.
- Alternatives considered:
  - One-step hard switch and immediate ACME removal: rejected due to elevated outage risk.

5. All routine infrastructure/platform operations in this change use eirctl commands.
- Rationale: preserves repository conventions, repeatability, and CI parity.
- Alternatives considered:
  - Direct CLI calls in ad-hoc scripts: rejected for inconsistency and auditability concerns.

## Risks / Trade-offs

- [Service account name mismatch with federated credential subject] -> Validate exact chart SA names after version pinning and before creating credentials.
- [AKS workload identity not fully enabled despite OIDC] -> Add preflight gate to verify both cluster knobs and issuer availability before identity resources.
- [PushSecret or Key Vault object format incompatible with App Gateway] -> Validate object type/content-type and perform nonprod listener verification before production.
- [Transition test failures from ACME-era assumptions] -> Update pipeline/test gates before ACME removal and run eirctl tests in nonprod.
- [Chart rollout race conditions with CRDs/webhooks] -> Pin versions and include rollout checks for all controller components.

## Migration Plan

1. Preflight verification of module capabilities, workload identity prerequisites, chart pins, and RBAC prerequisites.
2. Introduce identities, federation, and Terraform outputs required for chart templating.
3. Deploy cert-manager, external-secrets, and reflector through eirctl Helm workflow.
4. Apply ClusterIssuer/Certificate/SecretStore/PushSecret templates and validate readiness.
5. Cut Application Gateway to Key Vault certificate source and validate listener certificate chain.
6. Run nonprod rotation validation and regression checks through eirctl-driven plan/tests.
7. Promote production ACME endpoint and remove legacy ACME dependencies after explicit approval.
8. Finalize docs and setup guidance updates.

Rollback:
- Revert App Gateway certificate source to prior path and apply via eirctl if cutover fails.
- Keep ACME provider/variables available until post-gate stabilization.

## Open Questions

- Should Key Vault sync target certificate object, secret object, or both for long-term consumer compatibility?
- What is the exact minimum Key Vault role set required for External Secrets PushSecret in this environment?
- Are there any downstream consumers currently dependent on certificate_pem/issuer_pem outputs that require a deprecation period?
