# ESO Azure Key Vault PushSecret Support Proof

## Scope

This evidence covers tasks 1.1 and 1.2 for `cert-manager-akv-migration`: prove External Secrets Operator (ESO) can push
both required Azure Key Vault outputs before downstream migration work:

1. Application Gateway-compatible PFX Key Vault secret.
2. Azure Key Vault certificate object.

## Source

- External Secrets Operator Azure Key Vault provider documentation: <https://external-secrets.io/latest/provider/azure-key-vault>
- Fetched 2026-06-01.

## Findings

ESO Azure Key Vault provider supports `SecretStore`/`ClusterSecretStore` with `spec.provider.azurekv` and can push Kubernetes
Secret data into Azure Key Vault by using `PushSecret`.

Supported authentication includes Workload Identity. Recommended mode is referenced service account:

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: azure-store
spec:
  provider:
    azurekv:
      authType: WorkloadIdentity
      vaultUrl: https://example.vault.azure.net
      serviceAccountRef:
        name: external-secrets-akv
```

ESO Azure Key Vault object-type selection uses `remoteRef.remoteKey` prefixes for `PushSecret`:

| Target object | Prefix | Example |
| --- | --- | --- |
| Key Vault secret | `secret/` or no prefix | `secret/dev-wildcard-example-com-pfx` |
| Key Vault certificate | `cert/` | `cert/dev-wildcard-example-com-cert` |

## Required output 1: App Gateway-compatible PFX secret

ESO can push source Kubernetes Secret bytes to an Azure Key Vault secret via `PushSecret`. Azure Key Vault secret metadata supports `contentType`.

Planned shape:

```yaml
apiVersion: external-secrets.io/v1alpha1
kind: PushSecret
metadata:
  name: wildcard-pfx-secret
  namespace: cert-manager
spec:
  refreshInterval: 1h
  deletionPolicy: Delete
  secretStoreRefs:
    - name: azure-key-vault
      kind: SecretStore
  selector:
    secret:
      name: wildcard-tls
  template:
    engineVersion: v2
    data:
      tls.pfx: '{{ fullPemToPkcs12 (index . "tls.crt" | toString) (index . "tls.key" | toString) | b64dec }}'
  data:
    - match:
        secretKey: tls.pfx
      remoteRef:
        remoteKey: secret/dev-wildcard-example-com-pfx
      metadata:
        apiVersion: kubernetes.external-secrets.io/v1alpha1
        kind: PushSecretMetadata
        spec:
          contentType: application/x-pkcs12
          tags:
            managed-by: external-secrets
            migration: cert-manager-akv-migration
```

Notes:

- `contentType` is supported for PushSecret targeting Azure Key Vault secrets.
- `application/x-pkcs12` is the intended App Gateway-compatible PFX content type to validate in nonprod.
- ESO docs state omitting or empty `contentType` does not clear an existing content type; preflight/cutover validation must
  reject stale or wrong content type.

Required role/permission:

- Azure RBAC: Key Vault Secrets Officer for create/update/delete secret, scoped as narrowly as feasible; or access policy `Set`/`Delete` for secrets.

## Required output 2: Key Vault certificate object

ESO can push P12/PFX material to Azure Key Vault as certificate object by using `remoteRef.remoteKey: cert/<name>`.

Planned shape:

```yaml
apiVersion: external-secrets.io/v1alpha1
kind: PushSecret
metadata:
  name: wildcard-certificate-object
  namespace: cert-manager
spec:
  refreshInterval: 1h
  deletionPolicy: Delete
  secretStoreRefs:
    - name: azure-key-vault
      kind: SecretStore
  selector:
    secret:
      name: wildcard-tls
  template:
    engineVersion: v2
    data:
      cert.p12: '{{ fullPemToPkcs12 (index . "tls.crt" | toString) (index . "tls.key" | toString) | b64dec }}'
  data:
    - match:
        secretKey: cert.p12
      remoteRef:
        remoteKey: cert/dev-wildcard-example-com-cert
```

ESO docs state:

- P12/PKCS12/PFX is recommended for importing certificates to Azure Key Vault.
- P12 must contain both certificate and private key.
- Azure Key Vault does not support PKCS1 private keys for certificate import.
- Password-less P12 files are supported by ESO PushSecret certificate import path.
- cert-manager `Certificate.spec.privateKey.encoding` must be `PKCS8` because cert-manager defaults to PKCS1.

Required certificate template constraint:

```yaml
spec:
  privateKey:
    encoding: PKCS8
    algorithm: RSA
    size: 2048
```

Required role/permission:

- Azure RBAC: Key Vault Certificates Officer for certificate import/delete, scoped as narrowly as feasible; or access policy `Import`/`Delete` for certificates.

## Versioning behavior

Azure Key Vault object names remain stable while updates create new versions under same object name. Migration templates must
use deterministic object names:

- PFX secret: `<environment>-wildcard-<sanitized-dns-zone>-pfx`
- Certificate object: `<environment>-wildcard-<sanitized-dns-zone>-cert`

Separate names avoid collision with Key Vault certificate backing secrets. Preflight must check no existing Key Vault object
conflicts before enabling PushSecrets.

## Failure semantics and gates

Migration must stop or block cutover if any of these occur:

- ESO cannot authenticate through Workload Identity to Key Vault.
- PushSecret status does not report successful sync.
- PFX secret missing, wrong name, wrong content type, or missing new version after renewal.
- Certificate object missing, wrong name, or missing new version after renewal.
- cert-manager private key is PKCS1 instead of PKCS8.
- P12/PFX import fails because private key format, chain, or password handling is unsupported.
- ESO identity has broader-than-approved access to unrelated Key Vault objects, unless dedicated Key Vault is used.
- Existing Key Vault object name collision is detected.

## Conclusion

Task 1.1 is proven at documentation/provider level: ESO Azure Key Vault PushSecret supports both required target object types:

- PFX Key Vault secret through `remoteRef.remoteKey: secret/<name>` with `PushSecretMetadata.spec.contentType`.
- Key Vault certificate object through `remoteRef.remoteKey: cert/<name>` with P12/PFX generated from cert-manager TLS Secret using `fullPemToPkcs12`.

Downstream implementation may proceed, but must preserve the above constraints in Terraform/Helm/eirctl validation tasks and
verify behavior in nonprod before App Gateway cutover.
