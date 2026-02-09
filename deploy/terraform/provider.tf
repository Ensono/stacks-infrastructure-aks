terraform {

  backend "azurerm" {
  }

  required_providers {
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }

    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 0.1"
    }
  }
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuredevops" {
  org_service_url       = var.ado_org_service_url != "" ? var.ado_org_service_url : "https://dev.azure.com"
  personal_access_token = var.ado_personal_access_token != "" ? var.ado_personal_access_token : null
}
