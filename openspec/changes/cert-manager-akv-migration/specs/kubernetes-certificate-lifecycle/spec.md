## ADDED Requirements

### Requirement: Wildcard and apex certificate SHALL be issued by cert-manager using DNS-01

The platform SHALL issue a certificate for the configured DNS zone using cert-manager and ACME DNS-01 challenge validation. The certificate SHALL
include both `*.${dns_zone}` and `${dns_zone}` DNS names, where `dns_zone` is sourced from the existing Terraform DNS zone configuration.

#### Scenario: Successful wildcard and apex issuance

- **WHEN** the selected ClusterIssuer is configured with valid ACME server, DNS zone settings, and workload identity credentials
- **THEN** cert-manager MUST report the Certificate as Ready
- **AND** the Certificate MUST include `*.${dns_zone}`
- **AND** the Certificate MUST include `${dns_zone}`

### Requirement: ACME issuer selection SHALL support staging and production

The platform SHALL define separate cert-manager ClusterIssuers for Let's Encrypt staging and production, with staging used by default until nonprod
validation gates pass.

#### Scenario: Initial nonprod issuance uses staging issuer

- **WHEN** nonprod certificate issuance is first enabled
- **THEN** the Certificate MUST reference the staging ClusterIssuer by default

#### Scenario: Production issuer is selected after nonprod gates

- **WHEN** nonprod issuance, synchronization, App Gateway, forced renewal, issuer authorization, Key Vault version-integrity, and rollback readiness
  gates pass
- **THEN** pipeline/eirctl configuration MUST select the production ClusterIssuer only after explicit production approval
- **AND** production ClusterIssuer readiness, production Certificate readiness, and expected production issuer chain MUST be validated before
  production cutover

### Requirement: ClusterIssuer usage SHALL be restricted to approved platform workloads

The platform SHALL prevent unauthorized namespaces or service accounts from obtaining certificates through the migration ClusterIssuers.

#### Scenario: Approved platform workload requests managed certificate

- **WHEN** an approved platform namespace and service account requests the managed wildcard/apex certificate using an allowed migration ClusterIssuer
- **THEN** the certificate request MAY be approved and fulfilled

#### Scenario: Unapproved namespace requests migration issuer certificate

- **WHEN** an unapproved namespace or service account creates a Certificate or CertificateRequest that references a migration ClusterIssuer
- **THEN** admission, RBAC, approver policy, or equivalent controls MUST prevent the request from being fulfilled
- **AND** eirctl validation MUST report the unauthorized issuance attempt as blocked

#### Scenario: Unexpected DNS name is requested

- **WHEN** a Certificate or CertificateRequest references a migration ClusterIssuer with DNS names outside `*.${dns_zone}` and `${dns_zone}`
- **THEN** the request MUST be denied or left unapproved

### Requirement: Source TLS Secret SHALL be owned in cert-manager namespace

The platform SHALL store the source TLS Secret produced by the Certificate resource in the `cert-manager` namespace.

#### Scenario: Source secret exists in cert-manager namespace

- **WHEN** the Certificate is Ready
- **THEN** the source TLS Secret MUST exist in the `cert-manager` namespace

### Requirement: Wildcard certificate SHALL be replicated only to approved namespaces

The platform SHALL replicate the wildcard certificate secret from the `cert-manager` namespace only to namespaces explicitly allowed by configuration.
The default allow-list SHALL include `ingress-nginx` only.

#### Scenario: Default namespace receives mirrored certificate secret

- **WHEN** the reflection allow-list is not overridden
- **THEN** the mirrored certificate secret MUST exist in the `ingress-nginx` namespace

#### Scenario: Allowed namespace receives mirrored certificate secret

- **WHEN** a namespace is listed in `reflectionAllowedNamespaces`
- **THEN** the mirrored certificate secret MUST exist in that namespace

#### Scenario: Unlisted namespace does not receive mirrored certificate secret

- **WHEN** a namespace is not listed in `reflectionAllowedNamespaces`
- **THEN** the wildcard certificate secret MUST NOT be reflected into that namespace

### Requirement: Reflected certificate recipient namespaces SHALL meet security prerequisites

The platform SHALL treat each reflected wildcard TLS Secret as privileged private key material and SHALL restrict recipient namespaces to
platform-owned or explicitly security-approved namespaces.

#### Scenario: Additional namespace is added to reflection allow-list

- **WHEN** a namespace beyond `ingress-nginx` is added to `reflectionAllowedNamespaces`
- **THEN** the namespace MUST have security approval
- **AND** the namespace MUST avoid broad `get/list secrets` RBAC grants and tenant write access to the reflected Secret

#### Scenario: Recipient namespace fails security prerequisites

- **WHEN** a namespace does not meet reflected-secret security prerequisites
- **THEN** the namespace MUST NOT receive the wildcard certificate secret

### Requirement: Reflected certificates SHALL update during forced renewal

The platform SHALL validate that forced renewal updates every approved reflected certificate Secret, not only the source Secret and Key Vault objects.

#### Scenario: Forced renewal updates reflected secrets

- **WHEN** nonprod renewal is forced through eirctl
- **THEN** each reflected TLS Secret in an approved namespace MUST match the renewed source certificate fingerprint or serial within the configured
  timeout

### Requirement: Certificate lifecycle SHALL use pinned controller versions

The platform SHALL deploy cert-manager, external-secrets, and reflector using pinned Helm chart versions before certificate lifecycle resources are
applied.

#### Scenario: Pinned chart versions are used

- **WHEN** platform charts are deployed
- **THEN** cert-manager chart version MUST be `v1.20.2`
- **AND** external-secrets chart version MUST be `2.5.0`
- **AND** reflector chart version MUST be `10.0.46`

### Requirement: Controller charts and images SHALL satisfy supply-chain controls

The platform SHALL verify supply-chain controls for cert-manager, external-secrets, and reflector before rollout. Approved chart repositories,
immutable chart versions, chart provenance/signature or checksum validation where supported, approved image registries, and pinned image tags or
digests SHALL be captured as evidence. Mutable `latest` image references SHALL NOT be used.

#### Scenario: Controller artifact supply-chain evidence is captured

- **WHEN** controller charts are prepared for deployment
- **THEN** evidence MUST record chart repository URL, chart name, chart version, provenance/signature or checksum verification result where supported,
  resolved image repository, image tag or digest, and approved registry status

#### Scenario: Controller artifact source is not approved

- **WHEN** a chart repository, image registry, chart version, or image reference is not approved or uses a mutable `latest` reference
- **THEN** rollout MUST be blocked before controller deployment

### Requirement: eirctl certificate tasks SHALL redact secrets

All eirctl tasks that handle certificate, Kubernetes Secret, Key Vault, workload identity, or Azure credential data SHALL redact secret material from
stdout, stderr, logs, traces, pipeline artifacts, validation reports, and failure messages. Secret material includes PFX, PEM private keys,
certificate private keys, token values, client secrets, Key Vault secret values, and Kubernetes Secret data. Fingerprints, serial numbers, object
names, versions, expiry, issuer, SANs, and non-secret metadata MAY be emitted.

#### Scenario: eirctl task emits validation output

- **WHEN** an eirctl migration task validates certificate or Key Vault state
- **THEN** output MUST NOT include PFX bytes, PEM private keys, token values, client secrets, Key Vault secret values, or Kubernetes Secret data
- **AND** output MAY include certificate fingerprint, serial number, issuer, expiry, SANs, Key Vault object name, and Key Vault version identifier

#### Scenario: redaction regression fails

- **WHEN** redaction tests detect representative secret material in any success or failure output path
- **THEN** the task MUST fail validation and MUST NOT be used as migration evidence

### Requirement: Controller CRDs and webhooks SHALL be ready before dependent resources

The platform SHALL not apply ClusterIssuer, Certificate, SecretStore, or PushSecret resources before required controller CRDs and webhooks are
available.

#### Scenario: Dependent resources are applied after controller readiness

- **WHEN** cert-manager, external-secrets, and reflector are deployed
- **THEN** eirctl validation MUST confirm controller rollout, CRD availability, and webhook readiness before `cluster-setup` applies dependent
  resources

### Requirement: aad-pod-identity cleanup SHALL be conditional on runtime and declarative usage

The platform SHALL remove aad-pod-identity resources only when eirctl runtime and declarative inventory validation proves no active or dormant
workloads use aad-pod-identity selectors.

#### Scenario: No runtime or declarative aad-pod-identity users exist

- **WHEN** eirctl runtime validation reports no active aad-pod-identity users
- **AND** declarative inventory finds no Deployments, StatefulSets, DaemonSets, Jobs, CronJobs, AzureIdentity, AzureIdentityBinding, or pod-template
  selectors that use aad-pod-identity
- **THEN** aad-pod-identity chart and AzureIdentity/AzureIdentityBinding resources MAY be removed in this change

#### Scenario: Runtime aad-pod-identity users exist

- **WHEN** eirctl runtime validation reports active aad-pod-identity users
- **THEN** aad-pod-identity resources MUST remain installed
- **AND** the cert-manager migration MUST continue without expanding scope to migrate those users

#### Scenario: Dormant aad-pod-identity users exist

- **WHEN** declarative inventory finds scaled-to-zero, suspended, or otherwise dormant aad-pod-identity consumers
- **THEN** aad-pod-identity resources MUST remain installed
- **AND** a follow-up cleanup or migration task MUST be recorded
