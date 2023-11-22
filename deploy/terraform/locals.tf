locals {

  # Each region must have corresponding a shortend name for resource naming purposes
  location_name_map = {
    northeurope   = "eun"
    westeurope    = "euw"
    uksouth       = "uks"
    ukwest        = "ukw"
    eastus        = "use"
    eastus2       = "use2"
    westus        = "usw"
    eastasia      = "ase"
    southeastasia = "asse"
  }

  # Create the tags that need to be added to each of the resources
  tags = {
    "created_by"   = data.azurerm_client_config.current.client_id
    "created_date" = timestamp()
    "team"         = var.tag_team_owner
  }
}
