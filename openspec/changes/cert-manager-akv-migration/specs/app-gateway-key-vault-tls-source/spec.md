## ADDED Requirements

### Requirement: Application Gateway SHALL use Key Vault as certificate source

The platform SHALL configure Application Gateway to use a Key Vault-backed certificate source with a versionless secret/certificate URI.

#### Scenario: Listener references Key Vault certificate source

- **WHEN** Application Gateway configuration is applied in key_vault certificate mode
- **THEN** the HTTPS listener MUST reference the configured Key Vault URI instead of inline certificate material

### Requirement: Application Gateway SHALL use managed identity access for Key Vault reads

The platform SHALL attach a UserAssigned managed identity to Application Gateway and grant the minimum required Key Vault read permissions.

#### Scenario: Gateway can retrieve certificate from Key Vault

- **WHEN** the managed identity is assigned and RBAC is in place
- **THEN** Application Gateway MUST successfully provision and serve HTTPS using the Key Vault-backed certificate

### Requirement: Certificate rotation SHALL not require Terraform value changes

The platform SHALL support certificate rotation without changing the configured Key Vault URI in Terraform inputs.

#### Scenario: New certificate version is consumed without URI change

- **WHEN** a new certificate version is synchronized to the same Key Vault object name
- **THEN** Terraform plan MUST show no required change to key_vault_secret_id input values for steady-state operation
