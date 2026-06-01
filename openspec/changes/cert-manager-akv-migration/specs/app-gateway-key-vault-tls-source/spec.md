## ADDED Requirements

### Requirement: Application Gateway SHALL use Key Vault as certificate source

The platform SHALL configure Application Gateway to use a Key Vault-backed certificate source with a versionless secret URI pointing at the
synchronized PFX Key Vault secret.

#### Scenario: Listener references Key Vault certificate source

- **WHEN** Application Gateway configuration is applied in `key_vault` certificate mode
- **THEN** the HTTPS listener MUST reference the configured versionless Key Vault secret URI instead of inline certificate material

### Requirement: Application Gateway SHALL use managed identity access for Key Vault reads

The platform SHALL attach or reuse a UserAssigned managed identity for Application Gateway and grant the minimum required Key Vault read permissions
at the narrowest feasible scope.

#### Scenario: Existing App Gateway identity is reused

- **WHEN** the App Gateway module exposes or supports an existing suitable UserAssigned identity
- **THEN** the migration MUST reuse that identity for Key Vault certificate reads

#### Scenario: Dedicated App Gateway identity is created when absent

- **WHEN** no suitable App Gateway UserAssigned identity exists
- **THEN** the migration MAY create a dedicated UserAssigned identity for Application Gateway Key Vault reads

#### Scenario: Gateway can retrieve certificate from Key Vault

- **WHEN** the managed identity is assigned and scoped RBAC is in place
- **THEN** Application Gateway MUST successfully provision and serve HTTPS using the Key Vault-backed certificate

### Requirement: Application Gateway TLS policy SHALL require TLS 1.2 or newer

The platform SHALL configure and validate Application Gateway/frontend TLS policy so TLS 1.0 and TLS 1.1 are not enabled during or after Key
Vault-backed certificate cutover.

#### Scenario: TLS policy is valid during cutover

- **WHEN** Application Gateway is configured to use the Key Vault-backed certificate
- **THEN** eirctl validation MUST confirm the listener/frontend TLS policy allows TLS 1.2 or newer only
- **AND** TLS 1.0 and TLS 1.1 MUST NOT be enabled

#### Scenario: TLS policy is too weak

- **WHEN** Application Gateway validation detects TLS 1.0 or TLS 1.1 is enabled
- **THEN** cutover, production activation, and cleanup MUST be blocked

### Requirement: Certificate rotation SHALL not require Terraform value changes

The platform SHALL support certificate rotation without changing the configured Key Vault URI in Terraform inputs.

#### Scenario: New certificate version is consumed without URI change

- **WHEN** a new certificate version is synchronized to the same Key Vault object name
- **THEN** Terraform plan MUST show no required change to `key_vault_secret_id` input values for steady-state operation

### Requirement: Nonprod forced renewal SHALL validate App Gateway and reflected-secret rotation

The platform SHALL force nonprod certificate renewal/reissue before production cutover and validate that Application Gateway serves the renewed
certificate through the same versionless Key Vault URI after Key Vault version integrity and reflected-secret propagation checks pass.

#### Scenario: Forced renewal is served by Application Gateway

- **WHEN** nonprod renewal is forced through eirctl and Key Vault receives a new PFX secret version
- **THEN** Application Gateway MUST continue to reference the same versionless Key Vault secret URI
- **AND** Key Vault version integrity checks MUST pass for the renewed version
- **AND** Application Gateway MUST serve the renewed certificate chain after synchronization completes

### Requirement: Cutover failure SHALL trigger automatic eirctl rollback

The platform SHALL provide an eirctl-driven rollback path that restores the legacy Application Gateway certificate source if Key Vault-backed cutover
validation fails.

#### Scenario: App Gateway Key Vault cutover fails validation

- **WHEN** Application Gateway cannot retrieve or serve the Key Vault-backed certificate during cutover validation
- **THEN** an eirctl rollback task MUST revert Application Gateway to the legacy certificate source
- **AND** cert-manager, external-secrets, and reflector SHOULD remain installed for diagnosis

#### Scenario: Rollback contract is defined before cutover

- **WHEN** Application Gateway cutover work is ready to begin
- **THEN** rollback eirctl task names, inputs, idempotency behavior, timeout/retry behavior, failure detection criteria, automatic pipeline invocation
  point, expected Terraform state transition, and post-rollback listener certificate-chain validation MUST already be defined

#### Scenario: Rollback completes successfully

- **WHEN** rollback is invoked after failed Key Vault-backed cutover validation
- **THEN** Application Gateway MUST serve the legacy certificate chain again within the configured timeout
- **AND** eirctl MUST report rollback validation success

### Requirement: Application Gateway certificate operations SHALL be audited and monitored

The platform SHALL verify monitoring, alerting, and audit coverage for Application Gateway certificate retrieval and listener health before production
activation.

#### Scenario: App Gateway monitoring is enabled

- **WHEN** App Gateway uses the Key Vault-backed certificate source
- **THEN** eirctl validation MUST prove certificate retrieval failures, listener health failures, and rollback invocations are monitored or alertable

#### Scenario: App Gateway monitoring is missing

- **WHEN** eirctl cannot verify App Gateway certificate-read or listener-health monitoring coverage
- **THEN** production activation and cleanup MUST be blocked

### Requirement: Production cutover SHALL require production-specific gates

The platform SHALL not proceed to production Application Gateway cutover until production certificate and Key Vault state have been validated with
explicit approval.

#### Scenario: Production gates pass

- **WHEN** nonprod gates have passed and production approval is recorded
- **THEN** production ClusterIssuer MUST be Ready
- **AND** production Certificate MUST be Ready
- **AND** the certificate chain MUST come from the expected production issuer, not the staging issuer
- **AND** production Key Vault object versions MUST pass integrity validation
- **AND** Application Gateway MUST serve the expected production certificate chain from the versionless Key Vault secret URI
- **AND** TLS 1.2+ policy, monitoring/audit proof, and sanitized compliance evidence MUST be captured

### Requirement: Legacy certificate path SHALL remain until production stabilization gates pass

The platform SHALL retain legacy ACME provider, variables, and certificate path until nonprod issuance, sync, App Gateway, forced renewal, rollback
readiness, production cutover, production stabilization, and regression validation gates pass.

#### Scenario: Legacy path remains before cleanup

- **WHEN** production stabilization gates have not all passed
- **THEN** ACME-era Terraform provider, variables, and rollback wiring MUST remain available

#### Scenario: Legacy certificate outputs are removed after stabilization

- **WHEN** nonprod gates, production cutover, production stabilization, forced-renewal or approved rotation proof, rollback rehearsal/dry-run, and
  regression gates pass
- **THEN** legacy certificate outputs `certificate_pem` and `issuer_pem` MUST be removed
- **AND** obsolete `pfx_password` and ACME-era pipeline/docs requirements MUST be removed
