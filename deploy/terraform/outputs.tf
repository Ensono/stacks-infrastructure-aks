output "vnet_name" {
  description = "Created VNET name.\nName can be deduced however it's better to create a direct dependency"
  value       = var.create_aksvnet ? module.aks_bootstrap.vnet_name : ""
}

output "vnet_address_space" {
  description = "Specified VNET address space"
  value       = var.create_aksvnet ? module.aks_bootstrap.vnet_address_space : []
}

output "vnet_address_id" {
  description = "Specified VNET Id"
  value       = var.create_aksvnet ? module.aks_bootstrap.vnet_address_id : ""
}

output "resource_group_name" {
  description = "Created resource group Name"
  value       = module.aks_bootstrap.resource_group_name
}

output "resource_group_id" {
  description = "Created resource group Id"
  value       = module.aks_bootstrap.resource_group_id
}

output "aks_node_resource_group" {
  value = module.aks_bootstrap.aks_node_resource_group
}

output "aks_system_identity_principal_id" {
  value = module.aks_bootstrap.aks_system_identity_principal_id
}

output "aks_resource_group_name" {
  value = module.aks_bootstrap.aks_resource_group_name
}

output "aks_cluster_name" {
  value = module.aks_bootstrap.aks_cluster_name
}

output "acr_resource_group_name" {
  value = module.aks_bootstrap.acr_resource_group_name
}

output "acr_registry_name" {
  value = module.aks_bootstrap.acr_registry_name
}

### Identity ###
output "aks_default_user_identity_name" {
  value = var.create_user_identity ? module.aks_bootstrap.aks_default_user_identity_name : ""
}

output "aks_default_user_identity_id" {
  value = var.create_user_identity ? module.aks_bootstrap.aks_default_user_identity_id : ""
}

output "aks_default_user_identity_client_id" {
  value = var.create_user_identity ? module.aks_bootstrap.aks_default_user_identity_client_id : ""
}

output "aks_ingress_private_ip" {
  description = "Private IP to be used for the ingress controller inside the cluster"
  value       = cidrhost(cidrsubnet(var.vnet_cidr.0, 4, 0), -3)
}

output "aks_ingress_public_ip" {
  description = "Public IP to be used for the ingress controller inside the cluster"
  value       = module.aks_bootstrap.aks_ingress_public_ip
}

output "certificate_pem" {
  description = "PEM key of certificate, can be used internally"
  value       = module.ssl_app_gateway.certificate_pem
  sensitive   = true
}

output "issuer_pem" {
  description = "PEM key of certificate, can be used internally together certificate to create a full cert"
  value       = module.ssl_app_gateway.issuer_pem
  sensitive   = true
}

output "app_gateway_resource_group_name" {
  description = "Resource group of the Application Gateway"
  value       = module.ssl_app_gateway.app_gateway_resource_group_name
}

output "app_gateway_name" {
  description = "Name of the Application Gateway"
  value       = module.ssl_app_gateway.app_gateway_name
}

output "app_gateway_ip" {
  description = "Application Gateway public IP. Should be used with DNS provider at a top level. Can have multiple subs pointing to it - e.g. app.sub.domain.com, app-uat.sub.domain.com. App Gateway will perform SSL termination for all "
  value       = module.ssl_app_gateway.app_gateway_ip
}

output "app_gateway_public_ip_name" {
  description = "The Public IP associated to the Application Gateway"
  value       = module.ssl_app_gateway.app_gateway_ip_name
}

output "dns_resource_group_name" {
  description = "Resource group name for the DNS zones"
  value       = module.aks_bootstrap.dns_resource_group_name
}

output "dns_internal_resource_group_name" {
  description = "Resource group name for the internal DNS zones"
  value       = module.aks_bootstrap.dns_internal_resource_group_name
}

output "dns_base_domain" {
  description = "Base domain for the applications"
  value       = module.aks_bootstrap.dns_base_domain
}

output "dns_base_domain_internal" {
  description = "Base internal domain for the applications"
  value       = module.aks_bootstrap.dns_base_domain_internal
}

output "app_insights_resource_group_name" {
  description = "Resource group for Application Insights"
  value       = module.aks_bootstrap.app_insights_resource_group_name
}

output "app_insights_name" {
  description = "Name of the Application Insights instance"
  value       = module.aks_bootstrap.app_insights_name
}

output "app_insights_id" {
  description = "ID of the Application Insights instance"
  value       = module.aks_bootstrap.app_insights_id
}

output "app_insights_key" {
  description = "Shared key of the Application Insights instance"
  value       = module.aks_bootstrap.app_insights_key
  sensitive   = true
}

# Output the create flags so that they can be used in the tests
output "create_dns_zone" {
  value = var.create_dns_zone
}

output "create_aksvnet" {
  value = var.create_aksvnet
}

output "create_user_identity" {
  value = var.create_user_identity
}

output "create_acr" {
  value = var.create_acr
}

output "create_key_vault" {
  value = var.create_key_vault
}

output "create_valid_cert" {
  value = var.create_valid_cert
}

output "kubernetes_version" {
  value = var.cluster_version
}
