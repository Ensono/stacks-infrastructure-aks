module "ssl_app_gateway" {
  source                    = "git::https://github.com/Ensono/stacks-terraform//azurerm/modules/azurerm-app-gateway?ref=v2.0.23"
  resource_namer            = module.default_label.id
  resource_group_name       = module.aks_bootstrap.resource_group_name
  resource_group_location   = var.resource_group_location
  dns_resource_group        = var.dns_resource_group
  create_ssl_cert           = true
  vnet_name                 = module.aks_bootstrap.vnet_name
  vnet_cidr                 = var.vnet_cidr
  dns_zone                  = var.dns_zone
  pfx_password              = var.pfx_password
  aks_resource_group        = module.aks_bootstrap.aks_node_resource_group
  aks_ingress_ip            = var.is_cluster_private ? module.aks_bootstrap.aks_ingress_private_ip : module.aks_bootstrap.aks_ingress_public_ip
  subnet_front_end_prefix   = cidrsubnet(var.vnet_cidr.0, 4, 3)
  subnet_backend_end_prefix = cidrsubnet(var.vnet_cidr.0, 4, 4)
  subnet_names              = ["k8s1"]
  acme_email                = var.acme_email
  create_valid_cert         = var.create_valid_cert

  ssl_policy = {
    "policy_type" = "Predefined",
    "policy_name" = "AppGwSslPolicy20170401S",
  }
}
