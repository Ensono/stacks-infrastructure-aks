

# Deploy an AKS cluster for each of the environments that have been specified
module "aks_bootstrap" {
  source = "git::https://github.com/Ensono/stacks-terraform//azurerm/modules/azurerm-aks?ref=v8.0.19"

  resource_namer                    = module.naming.names[var.project].resource_group.name
  resource_group_location           = var.location
  spn_object_id                     = data.azurerm_client_config.current.object_id
  tenant_id                         = data.azurerm_client_config.current.tenant_id
  cluster_version                   = var.cluster_version
  cluster_sku_tier                  = var.cluster_sku_tier
  name_environment                  = length(local.environments) > 0 ? local.environments[0] : ""
  name_project                      = var.project
  name_company                      = var.company
  name_component                    = var.component
  create_dns_zone                   = var.create_dns_zone
  dns_parent_zone                   = var.dns_parent_zone
  dns_parent_resource_group         = coalesce(var.dns_parent_resource_group, var.dns_parent_zone_resource_group)
  dns_create_parent_zone_ns_records = var.dns_create_parent_zone_ns_records
  dns_resource_group                = var.dns_resource_group
  dns_zone                          = var.dns_zone
  internal_dns_zone                 = var.internal_dns_zone

  # ACR doesn't need to exist across environments - ensure you pass create_acr = false in other core environments
  create_acr         = var.create_acr
  acr_resource_group = var.acr_resource_group == "" ? module.naming.names[var.project].resource_group.name : var.acr_resource_group
  acr_registry_name  = var.acr_name == "" ? replace(module.naming.names[var.project].container_registry.name, "-", "") : var.acr_name

  # creating multiple would break the build once deploy multiple times same binary principle
  create_aksvnet          = var.create_aksvnet
  vnet_name               = module.naming.names[var.project].virtual_network.name
  vnet_cidr               = var.vnet_cidr
  subnet_front_end_prefix = cidrsubnet(var.vnet_cidr.0, 4, 3)
  subnet_prefixes         = [cidrsubnet(var.vnet_cidr.0, 4, 0)]
  subnet_names            = ["k8s1"]
  aks_ingress_private_ip  = cidrhost(cidrsubnet(var.vnet_cidr.0, 4, 0), -3)
  create_user_identity    = var.create_user_identity
  enable_auto_scaling     = true
  log_application_type    = "Node.JS"
  key_vault_name          = substr(var.key_vault_name, 0, 24)
  create_key_vault        = var.create_key_vault
  aks_node_pools          = var.aks_node_pools
  resource_group_tags     = local.tags
}
