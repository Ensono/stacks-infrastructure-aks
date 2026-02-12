## Plan: Migrate TLS Certificate Management to cert-manager with AKV Storage

Migrate from Terraform ACME-based certificate management to cert-manager using Let's Encrypt, storing wildcard certificates in a dedicated namespace with namespace-scoped replication, syncing to Azure Key Vault via External Secrets Operator, and configuring Application Gateway to consume certificates from AKV. Uses staging ACME server by default with variable override for production.

### Steps

1. **Add cert-manager Helm chart to [deploy/helm/k8s_apps.yaml](../../deploy/helm/k8s_apps.yaml)** with `installCRDs: true`, namespace `cert-manager`, Workload Identity labels (`azure.workload.identity/use: "true"`), and create values template at `deploy/helm/values/cert_manager.yaml`.

2. **Add External Secrets Operator Helm chart to [deploy/helm/k8s_apps.yaml](../../deploy/helm/k8s_apps.yaml)** with namespace `external-secrets`, enabling `PushSecret` CRD, and create values template at `deploy/helm/values/external_secrets.yaml`.

3. **Add Reflector Helm chart to [deploy/helm/k8s_apps.yaml](../../deploy/helm/k8s_apps.yaml)** (emberstack/reflector) to replicate the wildcard certificate secret from `cert-manager` namespace to consuming namespaces via `reflection-allowed-namespaces` annotation.
4. **Add `acme_server` variable to [deploy/terraform/variables.tf](../../deploy/terraform/variables.tf)** with type `string`, default `https://acme-staging-v02.api.letsencrypt.org/directory`, and description documenting staging vs production URLs. Add corresponding pipeline variable to [build/azDevOps/azure/pipeline-vars.yml](../../build/azDevOps/azure/pipeline-vars.yml).

5. **Create Terraform resources for cert-manager identity in [deploy/terraform/aks.tf](../../deploy/terraform/aks.tf)**: `azurerm_user_assigned_identity`, `azurerm_federated_identity_credential` for `system:serviceaccount:cert-manager:cert-manager`, and `azurerm_role_assignment` for DNS Zone Contributor on the DNS zone.

6. **Create Terraform resources for ESO identity**: `azurerm_user_assigned_identity` for External Secrets Operator, `azurerm_federated_identity_credential`, and `azurerm_role_assignment` for Key Vault Secrets Officer role on the Key Vault.

7. **Enable Key Vault creation** by setting `create_key_vault = true` default in [deploy/terraform/variables.tf](../../deploy/terraform/variables.tf), configure RBAC for Application Gateway managed identity with Key Vault Secrets User role, and enable Azure Key Vault certificate expiry notifications.

8. **Create ClusterIssuer manifest** in `deploy/helm/charts/cluster-setup/templates/cluster-issuer.yaml` for Let's Encrypt with `azureDNS` DNS-01 solver, using `${acme_server}` variable, Workload Identity `managedIdentity.clientID`, referencing `${dns_zone}`, `${dns_resource_group}`, and `${subscription_id}`.

9. **Create Certificate manifest** in `deploy/helm/charts/cluster-setup/templates/wildcard-certificate.yaml` for `*.${dns_zone}` in `cert-manager` namespace, referencing the ClusterIssuer, with Reflector annotations: `reflector.v1.k8s.emberstack.com/reflection-allowed: "true"` and `reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "ingress-nginx,default"`.

10. **Create SecretStore and PushSecret manifests** in `deploy/helm/charts/cluster-setup/templates/` for ESO to authenticate to Azure Key Vault using Workload Identity and push the wildcard certificate secret as PFX to AKV with appropriate content type.

11. **Update Application Gateway module in [deploy/terraform/ssl_app_gateway.tf](../../deploy/terraform/ssl_app_gateway.tf)** to use `key_vault_secret_id` referencing the synced certificate (versionless URI for auto-rotation), remove `create_ssl_cert`, `pfx_password`, and `acme_email` parameters, add user-assigned identity reference.

12. **Remove ACME provider and related resources**: delete ACME provider block from [deploy/terraform/provider.tf](../../deploy/terraform/provider.tf), remove `acme_email` and `pfx_password` variables from [deploy/terraform/variables.tf](../../deploy/terraform/variables.tf), remove `pkcs12` and `tls` provider dependencies, and clean up related outputs.

13. **Update pipeline variables in [build/azDevOps/azure/pipeline-vars.yml](../../build/azDevOps/azure/pipeline-vars.yml)**: remove `acme_email` and `pfx_password`, add `acme_server` (defaulting to staging), add Terraform outputs for `cert_manager_identity_client_id`, `external_secrets_identity_client_id`, and `key_vault_name` for Helm value templating.

14. **Update cluster-setup Helm values template** at `deploy/helm/values/cluster_setup.yaml` to accept templated values for `acmeServer`, `dnsZone`, `dnsResourceGroup`, `subscriptionId`, `certManagerIdentityClientId`, `esoIdentityClientId`, `keyVaultName`, and `reflectionAllowedNamespaces`.

### Task List

- [ ] Task 1: Add cert-manager Helm chart to k8s_apps.yaml
- [ ] Task 2: Add External Secrets Operator Helm chart to k8s_apps.yaml
- [ ] Task 3: Add Reflector Helm chart to k8s_apps.yaml
- [ ] Task 4: Add acme_server variable to Terraform variables and pipeline
- [ ] Task 5: Create cert-manager identity and RBAC in Terraform
- [ ] Task 6: Create ESO identity and RBAC in Terraform
- [ ] Task 7: Enable Key Vault and configure Application Gateway RBAC
- [ ] Task 8: Create ClusterIssuer manifest for Let's Encrypt
- [ ] Task 9: Create wildcard Certificate manifest with Reflector annotations
- [ ] Task 10: Create SecretStore and PushSecret manifests for ESO
- [ ] Task 11: Update Application Gateway to use Key Vault certificates
- [ ] Task 12: Remove ACME provider and related Terraform resources
- [ ] Task 13: Update pipeline variables configuration
- [ ] Task 14: Update cluster-setup Helm values template
