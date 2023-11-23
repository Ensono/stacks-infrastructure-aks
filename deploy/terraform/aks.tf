
module "aks_bootstrap" {
  source                  = "git::https://github.com/Ensono/stacks-terraform//azurerm/modules/azurerm-aks?ref=v2.0.23"
  resource_namer          = module.default_label.id
  resource_group_location = var.resource_group_location
  spn_object_id           = data.azurerm_client_config.current.object_id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  cluster_version         = var.cluster_version
  name_environment        = var.name_environment
  name_project            = var.name_project
  name_company            = var.name_company
  name_component          = var.name_component
  create_dns_zone         = var.create_dns_zone
  dns_resource_group      = var.dns_resource_group
  dns_zone                = var.dns_zone
  internal_dns_zone       = var.internal_dns_zone
  # ACR doesn't need to exist across environments - ensure you pass create_acr = false in other core environments
  create_acr         = var.create_acr
  acr_resource_group = var.acr_resource_group == "" ? module.default_label.id : var.acr_resource_group
  acr_registry_name  = var.acr_name == "" ? replace(module.default_label.id, "-", "") : var.acr_name
  # creating multiple would break the build once deploy multiple times same binary principle
  create_aksvnet          = var.create_aksvnet
  vnet_name               = module.default_label.id
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
