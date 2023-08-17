############################################
# AUTHENTICATION
############################################
# RELYING PURELY ON ENVIRONMENT VARIABLES as the user can control these from their own environment
############################################
# NAMING
############################################

variable "name_company" {
  type = string
}

variable "name_project" {
  type = string
}

variable "name_component" {
  type = string
}

variable "name_environment" {
  type = string
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

variable "resource_group_location" {
  type = string
}

variable "dns_zone" {
  type = string
}

variable "internal_dns_zone" {
  type = string
}

variable "pfx_password" {
  type = string
}

variable "dns_resource_group" {
  type = string
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

variable "create_user_identity" {
  type = bool
}

variable "cluster_version" {
  type = string
}

variable "create_acr" {
  type = bool
}

variable "acr_resource_group" {
  type = string
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

