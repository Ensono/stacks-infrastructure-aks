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

# Validate that Application Gateway is paired with an internal ingress target.
#
# nginx-ingress in this stack is ALWAYS deployed as an internal Azure Load Balancer:
# aks_ingress_private_ip is unconditionally passed to the AKS module (aks.tf), which
# causes nginx-ingress to request a static private IP from Azure CNI.
# The App Gateway must therefore always target that internal IP, which only happens
# when internal_ingress_enabled=true.  Setting internal_ingress_enabled=false causes the gateway
# to target aks_ingress_public_ip — a different (or non-existent) endpoint — producing
# a permanently unhealthy backend pool and 502 responses.
resource "terraform_data" "validate_ingress_gateway_mode" {
  lifecycle {
    precondition {
      condition = !var.create_ssl_gateway || var.internal_ingress_enabled
      error_message = join(" ", [
        "create_ssl_gateway=true requires internal_ingress_enabled=true.",
        "The nginx-ingress controller is always deployed as an internal Azure Load Balancer",
        "at the statically computed private IP ${cidrhost(cidrsubnet(var.vnet_cidr[0], 4, 0), -3)}.",
        "Setting internal_ingress_enabled=false causes Application Gateway to target the public ingress IP,",
        "which is not the live ingress endpoint and produces a 502 Bad Gateway.",
        "Set TF_VAR_internal_ingress_enabled=true for all environments that use this App Gateway topology."
      ])
    }
  }
}

# Validate that ACME certificate prerequisites are satisfied before attempting issuance.
#
# When create_valid_cert=true but acme_email, dns_zone, or dns_resource_group are missing,
# the upstream azurerm-app-gateway module silently falls back to a self-signed certificate
# and persists it in Terraform state.  Subsequent applies do not re-issue, leaving the
# gateway permanently serving a certificate that Java (and any standard TLS client) will
# reject with PKIX path building failed / SunCertPathBuilderException.
resource "terraform_data" "validate_cert_prerequisites" {
  lifecycle {
    precondition {
      condition = (
        !var.create_ssl_gateway ||
        !var.create_valid_cert ||
        (trimspace(var.acme_email) != "" && trimspace(var.dns_zone) != "" && trimspace(var.dns_resource_group) != "")
      )
      error_message = join(" ", [
        "create_ssl_gateway=true and create_valid_cert=true require acme_email, dns_zone,",
        "and dns_resource_group to all be non-empty after trimming whitespace.",
        "Missing values cause ACME certificate issuance to fail and the gateway to fall back",
        "to a self-signed certificate. Set TF_VAR_acme_email, TF_VAR_dns_zone, and",
        "TF_VAR_dns_resource_group before applying infrastructure."
      ])
    }
  }
}

# Get details about the ADO project, this is required so that Terraform
# can create the variable group in the correct project and an ID is required for that
data "azuredevops_project" "project" {
  count = var.create_ado_variable_group && local.has_ado_pat ? 1 : 0
  name  = var.ado_project_name
}
