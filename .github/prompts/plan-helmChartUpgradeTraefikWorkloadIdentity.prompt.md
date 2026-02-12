# Plan: Migrate Helm Charts to Latest Versions with Traefik, Workload Identity, Key Vault, ESO & Secure Dashboard

Comprehensive upgrade of all Helm charts, replacing nginx-ingress with Traefik (secured dashboard via Key Vault + ESO), migrating to Azure Workload Identity with pre-created federated credentials, adding External Secrets Operator, inferring dashboard IP allowlist from VNet, and full migration documentation.

## Steps

1. **Create federated identity Terraform module in deploy/terraform/modules/azurerm-federated-identity/**: Create `main.tf` with `azurerm_federated_identity_credential` resource, `variables.tf` (inputs: `name`, `resource_group_name`, `user_assigned_identity_id`, `oidc_issuer_url`, `namespace`, `service_account_name`), `outputs.tf` (output: `federated_credential_id`).

2. **Update deploy/terraform/aks.tf for Workload Identity**: Pass `oidc_issuer_enabled = true` and `workload_identity_enabled = true` to AKS module. Instantiate federated identity module via `for_each` for: `external-secrets`, `external-dns`, `traefik`, `velero`, `grafana`, `prometheus`. Reference VNet address space for dashboard IP allowlist output.

3. **Add Traefik dashboard credentials to Key Vault in deploy/terraform/aks.tf**: Generate `random_password` resource, create bcrypt hash via `htpasswd` format (`admin:$apr1$...`), store in Key Vault secret `traefik-dashboard-auth`, output secret name for ESO reference.

4. **Add VNet-derived dashboard allowlist output**: Create `traefik_dashboard_allowed_cidrs` output derived from `module.aks_bootstrap.vnet_address_space` (the AKS VNet CIDR ranges), ensuring dashboard is only accessible from within the cluster network.

5. **Update deploy/terraform/variables.tf**: Add `oidc_issuer_enabled` (default: `true`), `workload_identity_enabled` (default: `true`), `traefik_dashboard_username` (default: `admin`), `federated_identity_service_accounts` map variable for extensibility.

6. **Update deploy/terraform/outputs.tf**: Add `aks_oidc_issuer_url`, `traefik_dashboard_secret_name`, `traefik_dashboard_allowed_cidrs`, federated credential IDs, identity client IDs (`external_secrets_identity_client_id`, `external_dns_identity_client_id`, `traefik_identity_client_id`, `velero_identity_client_id`, `grafana_identity_client_id`, `prometheus_identity_client_id`).

7. **Update deploy/helm/k8s_apps.yaml**: Remove `aad-pod-identity`, replace `ingress-nginx` with Traefik (v39.0.0), add External Secrets Operator (v0.9.13, repo: `https://charts.external-secrets.io`, namespace: `external-secrets`, enabled: `true`), fix typos, add version pins (kured→5.11.0, external-dns→1.20.0, argo-rollouts→2.40.5, grafana→10.5.15, velero→11.3.2, prometheus→28.7.0), add `rollout_checks` for ESO (`deployment/external-secrets`, 90s) and Traefik (`deployment/traefik`, 120s).

8. **Remove deprecated identity templates**: Delete deploy/helm/charts/cluster-setup/templates/azure-identity.yaml and deploy/helm/charts/cluster-setup/templates/azure-identity-binding.yaml.

9. **Create deploy/helm/values/external_secrets.yaml**: Configure `serviceAccount.annotations` with `azure.workload.identity/client-id: ${env:TFOUT_external_secrets_identity_client_id}`, `podLabels` with `azure.workload.identity/use: "true"`, enable webhook and cert-controller with Workload Identity.

10. **Create deploy/helm/values/traefik.yaml**: Configure Azure internal load balancer, `loadBalancerIP: ${env:TFOUT_aks_ingress_private_ip}`, `externalTrafficPolicy: Local`, forwarded headers, `ingressClass.enabled: true`, `ingressClass.isDefaultClass: false`, `api.dashboard: true`, `api.insecure: false`. Define `extraObjects` for: `ClusterSecretStore` pointing to Key Vault, `ExternalSecret` for `traefik-dashboard-auth`, `Middleware` for basicAuth and ipAllowList (using `${env:TFOUT_traefik_dashboard_allowed_cidrs}`), `IngressRoute` for dashboard with both middlewares.

11. **Update deploy/helm/values/external_dns.yaml**: Add `serviceAccount.annotations` with Workload Identity client ID, `podLabels` with `azure.workload.identity/use: "true"`, update to `provider.name: azure`, add `useWorkloadIdentityExtension: true`, remove legacy secret volume mounts.

12. **Update deploy/helm/values/cluster_setup.yaml**: Change certificate reflection namespace from `ingress-nginx` to `traefik`, remove legacy identity references.

13. **Create placeholder values files with Workload Identity**: Create deploy/helm/values/argo_rollouts.yaml, deploy/helm/values/grafana.yaml (with `serviceAccount.annotations` for `${env:TFOUT_grafana_identity_client_id}`), deploy/helm/values/velero.yaml (with `${env:TFOUT_velero_identity_client_id}` and `useWorkloadIdentityExtension`), deploy/helm/values/prometheus.yaml (with `${env:TFOUT_prometheus_identity_client_id}`), each with Workload Identity pod labels and TODO comments.

14. **Create migration guide docs/migration-workload-identity.adoc**: Document prerequisites (OIDC issuer, ESO deployed, Key Vault access), step-by-step annotation migration (`aadpodidbinding` → `azure.workload.identity/use`), service account patterns, federated credential Terraform module usage, ESO SecretStore/ExternalSecret configuration, validation commands, rollback procedure. Weight: 75.

15. **Create docs/ingress.adoc**: Document Traefik installation, explicit `ingressClassName: traefik` requirement, IngressRoute CRD patterns, middleware configuration (basicAuth, ipAllowList from VNet CIDR, headers), Azure internal load balancer, dashboard access (VNet-only + basicAuth via Key Vault/ESO), credential rotation procedure, nginx-ingress migration with annotation mapping table. Weight: 55.

16. **Update docs/helm.adoc**: Replace Ingress Nginx with Traefik, remove AAD Pod Identity, add External Secrets Operator entry (enabled by default), add Workload Identity section, add Key Vault integration section, add cross-references to `xref:ingress.adoc[Ingress Configuration]` and `xref:migration-workload-identity.adoc[Workload Identity Migration]`.

17. **Update docs/infrastructure.adoc**: Add federated identity module documentation, OIDC issuer outputs, Key Vault secret management, VNet-derived security patterns, cross-references to migration guides.

18. **Validate locally using eirctl**: Run `eirctl run lint:yaml` and `eirctl run lint:terraform:validate`, source `source ./local/envvar-azure-dev.sh`, run `eirctl run infra:init` → `eirctl run infra:plan` (verify 6 federated credentials, Key Vault secret, VNet CIDR output), run `eirctl run infra:apply`, run `eirctl run infra:helm:apply`, verify ESO with `kubectl get clustersecretstores`, verify Traefik with `kubectl get ingressclass` (confirm not default), verify ExternalSecret sync with `kubectl get externalsecrets -n traefik`, test dashboard access from within VNet with basicAuth.
