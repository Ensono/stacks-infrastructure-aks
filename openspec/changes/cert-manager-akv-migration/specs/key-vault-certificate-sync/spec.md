## ADDED Requirements

### Requirement: Certificate artifacts SHALL be synchronized to Azure Key Vault

The platform SHALL synchronize wildcard/apex certificate material from Kubernetes to Azure Key Vault using External Secrets Operator PushSecret and
workload identity authentication.

#### Scenario: PushSecret synchronization succeeds

- **WHEN** SecretStore and PushSecret resources are applied with valid identity and Key Vault access
- **THEN** PushSecret MUST report a successful synchronized state through documented status conditions

### Requirement: Key Vault synchronization SHALL create both secret and certificate objects

The platform SHALL create both an Application Gateway-compatible PFX Key Vault secret and a Key Vault certificate object for the managed certificate.
Both object types are mandatory for this migration.

#### Scenario: PFX secret is synchronized for Application Gateway

- **WHEN** certificate material is synchronized to Key Vault
- **THEN** Key Vault MUST contain a PFX secret suitable for Application Gateway listener configuration
- **AND** the secret MUST use an App Gateway-compatible content type

#### Scenario: Certificate object is synchronized for consumers

- **WHEN** certificate material is synchronized to Key Vault
- **THEN** Key Vault MUST contain a certificate object representing the same managed certificate

#### Scenario: Required Key Vault object type is unsupported

- **WHEN** External Secrets Operator and repository-supported templating cannot reliably create both the PFX secret and certificate object
- **THEN** migration MUST stop before Terraform identity work, controller rollout, or App Gateway cutover

### Requirement: ESO Key Vault support SHALL be proven before downstream migration work

The platform SHALL prove the exact ESO/provider mechanism for PFX secret and certificate-object synchronization before implementing downstream
identity, chart, or cutover tasks.

#### Scenario: ESO support proof is captured

- **WHEN** preflight validates ESO support
- **THEN** the migration MUST document CRD/provider fields, PFX conversion path, content type, Key Vault certificate import semantics, versioning
  behavior, and failure semantics

### Requirement: Key Vault target object naming SHALL be deterministic and collision-free

The synchronization process SHALL use deterministic target naming so downstream consumers can reference stable versionless Key Vault URIs. Names SHALL
be derived from environment plus sanitized DNS domain and SHALL distinguish the PFX secret from the certificate object unless preflight proves the
intended same-name layout is safe.

#### Scenario: Stable environment-plus-domain object names are used

- **WHEN** the deployment environment is `dev` and DNS zone is `example.com`
- **THEN** the Key Vault target object names MUST use the normalized prefix `dev-wildcard-example-com`
- **AND** the PFX secret and certificate object final names MUST be documented explicitly

#### Scenario: Stable Key Vault object reference across renewals

- **WHEN** certificate renewal updates source secret material
- **THEN** the Key Vault object names MUST remain unchanged while new versions are created

#### Scenario: Existing Key Vault object would collide

- **WHEN** preflight detects an existing Key Vault object or certificate backing secret that conflicts with the planned object names
- **THEN** migration MUST stop until object names are changed or the conflict is resolved

### Requirement: External Secrets SHALL use a dedicated workload identity with narrow Key Vault scope

The platform SHALL use a dedicated external-secrets managed identity and federated credential for Key Vault synchronization.

#### Scenario: ESO authenticates through workload identity

- **WHEN** PushSecret synchronizes certificate material
- **THEN** External Secrets Operator MUST authenticate using its dedicated federated workload identity
- **AND** the identity MUST have exact least built-in Key Vault permissions needed to create/update the required secret and certificate objects at the
  narrowest feasible scope

#### Scenario: ESO access to unrelated Key Vault objects is checked

- **WHEN** eirctl validates Key Vault RBAC boundaries
- **THEN** the external-secrets identity MUST NOT be able to read, write, or list unrelated Key Vault objects beyond the migration certificate
  objects, unless a dedicated Key Vault is used for this certificate path

### Requirement: Application Gateway Key Vault access SHALL be read-limited

The platform SHALL grant Application Gateway identity only the Key Vault read access needed for the synchronized PFX secret.

#### Scenario: Application Gateway access to unrelated secrets is checked

- **WHEN** eirctl validates Key Vault RBAC boundaries
- **THEN** the Application Gateway identity MUST be able to retrieve the configured PFX secret
- **AND** the identity MUST NOT be able to list or read unrelated Key Vault secrets, unless a dedicated Key Vault is used for this certificate path

### Requirement: Forced renewal SHALL update Key Vault object versions

The platform SHALL validate renewal behavior by forcing a nonprod cert-manager renewal/reissue through an eirctl task.

#### Scenario: Forced renewal creates new Key Vault versions

- **WHEN** nonprod renewal is forced through eirctl
- **THEN** the source Kubernetes TLS Secret MUST be updated
- **AND** the Key Vault PFX secret MUST receive a new version under the same object name
- **AND** the Key Vault certificate object MUST receive a new version under the same object name

### Requirement: New Key Vault certificate versions SHALL pass integrity validation

The platform SHALL validate certificate identity and cryptographic properties for each new Key Vault version before marking rotation or cutover
healthy.

#### Scenario: Key Vault version integrity is valid

- **WHEN** Key Vault receives a new PFX secret or certificate object version
- **THEN** eirctl validation MUST confirm expected SAN set, issuer chain, key type and size, signature algorithm, expiry window, content type, and
  environment/domain naming
- **AND** cryptographic validation MUST require RSA 2048-bit or stronger, or ECDSA P-256/P-384

#### Scenario: Key Vault version integrity is invalid

- **WHEN** a new Key Vault version has unexpected SANs, issuer chain, key parameters, signature algorithm, expiry, content type, object naming, RSA
  key size below 2048 bits, or unsupported ECDSA curve
- **THEN** cutover or rotation validation MUST fail
- **AND** production activation or cleanup MUST be blocked

### Requirement: Key Vault certificate synchronization SHALL be audited and monitored

The platform SHALL enable or verify audit logging, diagnostic settings, monitoring queries, and alerts for certificate synchronization and access
signals. Required signals include Key Vault secret/certificate version creation, unexpected certificate attribute changes, access-denied events for
migration identities, ESO PushSecret synchronization failures, and eirctl rollback invocations that affect Key Vault-backed certificate state.

#### Scenario: audit and monitoring are enabled

- **WHEN** Key Vault synchronization is enabled in an environment
- **THEN** eirctl validation MUST prove required diagnostic settings, audit log sinks, monitoring queries, and alert rules exist or are queryable for
  migration certificate objects

#### Scenario: Key Vault access or version signal is missing

- **WHEN** eirctl cannot verify audit logs or monitoring coverage for Key Vault version changes, access denied events, or ESO sync failures
- **THEN** production activation and cleanup MUST be blocked

### Requirement: Compliance evidence SHALL be captured without secret disclosure

The platform SHALL capture sanitized evidence for each Key Vault synchronization gate. Evidence SHALL include eirctl task name, run ID, timestamp,
environment, sanitized inputs, pass/fail result, certificate fingerprint/serial/expiry, Key Vault object names and version identifiers, RBAC
validation results, audit/alert proof, and approver where required. Evidence SHALL NOT include PFX, PEM private key, Key Vault secret value, token,
client secret, or Kubernetes Secret data.

#### Scenario: Key Vault gate evidence is recorded

- **WHEN** a Key Vault synchronization, RBAC, version-integrity, forced-renewal, production, or cleanup gate completes
- **THEN** sanitized evidence MUST be stored in the approved pipeline/evidence location
- **AND** the evidence MUST be sufficient to map the gate to the exact Key Vault object versions validated

#### Scenario: evidence contains secret material

- **WHEN** compliance evidence includes PFX, PEM private key, Key Vault secret value, token, client secret, or Kubernetes Secret data
- **THEN** the evidence package MUST be rejected and regenerated with redaction before the gate can pass
