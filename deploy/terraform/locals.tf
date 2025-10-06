locals {

  # Determine if this is a production subscription or the override is being used
  is_prod_subscription = contains(["prod"], data.azurerm_subscription.current.tags) || var.is_prod_subscription
  deploy_all_envs      = contains(["override"], data.azurerm_subscription.current.tags) || var.deploy_all_environments

  # Obtain a list of environments from the variables
  # This is a comma separated list which also has a flag to state if it is for the production subscription or not
  environments_all = { for env_definition in split(",", var.environments) :
    "${split(":", env_definition)[0]}" =>
    {
      is_prod = "${split(":", env_definition)[1]}" == "true" ? true : false
    }
  }


  # Create a list of the envs to deploy
  # This list determines if the environment is for a production subscription or not
  # and returns the appropriate list
  #
  # For example, if the variable `is_prod_subscription` is set to false
  #
  # ["test", "uat"]
  #
  #
  environments = flatten([for name, detail in local.environments_all : [
    name
  ] if detail.is_prod == var.is_prod_subscription || var.deploy_all_environments])

  resource_outputs = { for envname in local.environments : envname => {
    resource_group_name = module.aks_bootstrap.resource_group_name
    }
  }

  outputs = { for envname in local.environments : envname => {
    acr_registry_name                   = module.aks_bootstrap.acr_registry_name
    acr_resource_group_name             = module.aks_bootstrap.acr_resource_group_name
    aks_cluster_name                    = module.aks_bootstrap.aks_cluster_name
    aks_default_user_identity_client_id = var.create_user_identity ? module.aks_bootstrap.aks_default_user_identity_client_id : ""
    aks_default_user_identity_id        = var.create_user_identity ? module.aks_bootstrap.aks_default_user_identity_id : ""
    aks_default_user_identity_name      = var.create_user_identity ? module.aks_bootstrap.aks_default_user_identity_name : ""
    aks_ingress_private_ip              = cidrhost(cidrsubnet(var.vnet_cidr.0, 4, 0), -3)
    aks_ingress_public_ip               = module.aks_bootstrap.aks_ingress_public_ip
    aks_node_resource_group             = module.aks_bootstrap.aks_node_resource_group
    aks_resource_group_name             = module.aks_bootstrap.aks_resource_group_name
    aks_system_identity_principal_id    = module.aks_bootstrap.aks_system_identity_principal_id
    app_gateway_ip                      = module.ssl_app_gateway.app_gateway_ip
    app_gateway_name                    = module.ssl_app_gateway.app_gateway_name
    app_gateway_public_ip_name          = module.ssl_app_gateway.app_gateway_ip_name
    app_gateway_resource_group_name     = module.ssl_app_gateway.app_gateway_resource_group_name
    app_insights_id                     = module.aks_bootstrap.app_insights_id
    app_insights_key                    = module.aks_bootstrap.app_insights_key
    app_insights_name                   = module.aks_bootstrap.app_insights_name
    app_insights_resource_group_name    = module.aks_bootstrap.app_insights_resource_group_name
    certificate_pem                     = module.ssl_app_gateway.certificate_pem
    create_acr                          = var.create_acr
    create_aksvnet                      = var.create_aksvnet
    create_dns_zone                     = var.create_dns_zone
    create_key_vault                    = var.create_key_vault
    create_user_identity                = var.create_user_identity
    create_valid_cert                   = var.create_valid_cert
    dns_base_domain                     = module.aks_bootstrap.dns_base_domain
    dns_base_domain_internal            = module.aks_bootstrap.dns_base_domain_internal
    dns_internal_resource_group_name    = module.aks_bootstrap.dns_internal_resource_group_name
    dns_resource_group_name             = module.aks_bootstrap.dns_resource_group_name
    issuer_pem                          = module.ssl_app_gateway.issuer_pem
    kubernetes_version                  = var.cluster_version
    resource_group_id                   = module.aks_bootstrap.resource_group_id
    resource_group_name                 = module.aks_bootstrap.resource_group_name
    vnet_address_id                     = var.create_aksvnet ? module.aks_bootstrap.vnet_address_id : ""
    vnet_address_space                  = var.create_aksvnet ? module.aks_bootstrap.vnet_address_space : []
    vnet_name                           = var.create_aksvnet ? module.aks_bootstrap.vnet_name : ""

    }
  }


  company_short_name = lower(substr(var.company, 0, 3))


  # Create the tags that need to be added to each of the resources
  tags = {
    "created_by"   = data.azurerm_client_config.current.client_id
    "created_date" = timestamp()
    "team"         = var.tag_team_owner
  }
}
