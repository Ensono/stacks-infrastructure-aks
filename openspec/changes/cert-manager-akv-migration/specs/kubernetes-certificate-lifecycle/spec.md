## ADDED Requirements

### Requirement: Wildcard certificate SHALL be issued by cert-manager using DNS-01

The platform SHALL issue a wildcard certificate for the configured DNS zone using cert-manager and an ACME ClusterIssuer configured for DNS-01 challenge validation.

#### Scenario: Successful wildcard issuance

- **WHEN** the ClusterIssuer is configured with valid ACME server, DNS zone settings, and workload identity credentials
- **THEN** cert-manager MUST report the wildcard Certificate as Ready

### Requirement: Wildcard certificate SHALL be replicated only to approved namespaces

The platform SHALL replicate the wildcard certificate secret from the cert-manager namespace only to namespaces explicitly allowed by configuration.

#### Scenario: Allowed namespace receives mirrored certificate secret

- **WHEN** a namespace is listed in reflectionAllowedNamespaces
- **THEN** the mirrored certificate secret MUST exist in that namespace

#### Scenario: Unlisted namespace does not receive mirrored certificate secret

- **WHEN** a namespace is not listed in reflectionAllowedNamespaces
- **THEN** the wildcard certificate secret MUST NOT be reflected into that namespace
