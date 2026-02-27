data "azurerm_client_config" "current" {}

# Get data about the current subscription
# This is used to determine if there are any tags to denote if the subscription
# is a prod or nonprod sub or it should be overridden
data "azurerm_subscription" "current" {}

# Validate subscription environment tag to fail fast on misconfiguration
resource "null_resource" "validate_subscription_tag" {
  lifecycle {
    precondition {
      condition     = contains(["prod", "override", ""], lookup(data.azurerm_subscription.current.tags, "environment", ""))
      error_message = "Invalid 'environment' subscription tag value '${lookup(data.azurerm_subscription.current.tags, "environment", "")}'. Allowed values are: prod, override, or empty."
    }
  }
}

# Validate ACR configuration when using existing ACR
resource "null_resource" "validate_acr_config" {
  lifecycle {
    precondition {
      condition     = var.create_acr || (var.acr_resource_group != "" && var.acr_name != "")
      error_message = "When create_acr is false, both acr_resource_group and acr_name must be provided to use an existing ACR."
    }
  }
}

# Validate subscription environment tag to fail fast if misconfigured
resource "terraform_data" "subscription_tag_validation" {
  lifecycle {
    precondition {
      condition     = contains(["prod", "override", ""], local.subscription_environment_tag)
      error_message = "Invalid 'environment' subscription tag value '${local.subscription_environment_tag}'. Allowed values are: prod, override, or empty."
    }
  }
}

# Validate that min_count <= max_count when autoscaling is enabled
resource "terraform_data" "validate_node_pool_min_max" {
  lifecycle {
    precondition {
      condition     = !var.aks_default_node_pool_autoscaling || var.aks_default_node_pool_min_count <= var.aks_default_node_pool_max_count
      error_message = "When autoscaling is enabled, aks_default_node_pool_min_count (${var.aks_default_node_pool_min_count}) must be less than or equal to aks_default_node_pool_max_count (${var.aks_default_node_pool_max_count})."
    }
  }
}

# Get details about the ADO project, this is required so that Terraform
# can create the variable group in the correct project and an ID is required for that
data "azuredevops_project" "project" {
  count = var.create_ado_variable_group && local.has_ado_pat ? 1 : 0
  name  = var.ado_project_name
}
