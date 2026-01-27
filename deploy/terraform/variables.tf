############################################
# AUTHENTICATION
############################################
# RELYING PURELY ON ENVIRONMENT VARIABLES as the user can control these from their own environment
############################################
# NAMING
############################################

variable "company" {
  type = string
}

variable "project" {
  type = string
}

variable "component" {
  type = string
}

# variable "environment" {
#   type = string
# }

variable "environments" {
  description = "List of environments that need to be created"
  default     = "dev:false,test:false,prod:true"
}

variable "stage" {
  type = string
}

variable "attributes" {
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

############################################
# AZURE INFORMATION
############################################

variable "location" {
  type = string
}

variable "dns_zone" {
  type = string
}

variable "dns_parent_zone" {
  type    = string
  default = ""
}

variable "dns_parent_zone_resource_group" {
  type    = string
  default = ""
}

variable "internal_dns_zone" {
  type = string
}

variable "pfx_password" {
  type = string
}

variable "dns_resource_group" {
  type    = string
  default = ""
}

variable "aks_node_pools" {
  type = map(object({
    vm_size      = string,
    auto_scaling = bool,
    min_nodes    = number,
    max_nodes    = number
  }))
  description = "Additional node pools as required by the platform"
  default     = {}
}

# ###########################
# # CONDITIONALS
# ##########################
variable "create_dns_zone" {
  type = bool
}

variable "create_aksvnet" {
  type = bool
}

variable "vnet_name_resource_group" {
  type    = string
  default = ""
}

variable "create_user_identity" {
  type = bool
}

variable "is_prod_subscription" {
  type        = bool
  default     = false
  description = "Flag to state if the subscription being deployed to is the production subscription or not. This so that the environments are created properly."
}

variable "deploy_all_environments" {
  type        = bool
  default     = false
  description = "If true, all environments will be deployed regardless of subscription type, e.g. nonprod or prod"
}

variable "cluster_version" {
  type    = string
  default = "1.34.1"
}

variable "cluster_sku_tier" {
  description = "The Control Plane SKU Tier"
  type        = string

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.cluster_sku_tier)
    error_message = "Must be one of Free, Standard, or Premium."
  }
}

variable "create_acr" {
  type = bool
}

variable "acr_resource_group" {
  type    = string
  default = ""
}

variable "acr_name" {
  type    = string
  default = ""
}

variable "is_cluster_private" {
  type        = bool
  description = "Set cluster private - API only accessible over internal network"
}

variable "log_application_type" {
  type    = string
  default = "other"
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault name - if not specificied will default to computed naming convention"
  default     = ""
}

variable "create_key_vault" {
  type        = bool
  description = "States if the AKS module should create a Key Vault or not"
  default     = false
}

variable "create_valid_cert" {
  type        = bool
  description = "Denote if a certificate should be created on the gateway. Useful if DNS is not yet configured"
  default     = true
}

variable "acme_email" {
  type        = string
  description = "Email for Acme registration, must be a valid email"
}

# if you do not set the
# `service_cidr`
# `dns_service_ip`
# `docker_bridge_cidr`
# AKS will default to ==> 10.0.0.0/16
variable "vnet_cidr" {
  default = ["10.1.0.0/16"]
}

variable "tag_team_owner" {
  default = ""
}

#######################################################
# Azure DevOps Settings
#######################################################

variable "ado_org_service_url" {
  description = "The URL of the Azure DevOps organization service"
  type        = string
}

variable "ado_project_name" {
  description = "The name of the Azure DevOps project"
  type        = string
}

variable "ado_personal_access_token" {
  description = "The personal access token for Azure DevOps authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "create_ado_variable_group" {
  description = "Flag to indicate if a variable group should be created in Azure DevOps"
  type        = bool
  default     = true
}


#######################################################
# Local development settings
#######################################################

variable "create_env_files" {
  description = "Flag to indicate if environment files should be created for local development"
  type        = bool
  default     = false
}
