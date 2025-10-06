locals {

  template_files = [
    {
      filename = "envvars.bash.tpl",
      type     = "bash"
    },
    {
      filename = "envvars.ps1.tpl",
      type     = "powershell"
    }
    ,
    {
      filename = "inputs.auto.tfvars.tpl",
      type     = "terraform"
    }
  ]

  # Define the outputs for this module
  # outputs = merge(jsondecode(var.outputs), { "module_path" : path.module })
  outputs = jsondecode(var.outputs)

  # Iterate around the envrionments and the outputs and encode as required, e.g. quotes around strings
  # and encode anything else
  #encoded_outputs = {
  #  for name in var.environments : name => {
  #    for key, value in local.outputs[name] : key => jsonencode(value)
  #  }
  #}

  encoded_outputs = tomap({
    for name in var.environments : name => {
      for k, v in local.outputs[name] :
      replace(k, "-", "_") => (
        // This will be true for lists (arrays)
        can([for x in v : x]) ||
        // This will be true for maps/objects
        can(keys(v)) ?

        jsonencode(v) :
        tostring(v)
      )
    }
  })

  # Create a local object for the template mapping so that the script files can be generated
  template_items = flatten([
    for template_file in local.template_files : [
      for name in var.environments : {
        envname      = name
        tf_workspace = terraform.workspace
        file         = template_file.filename
        items        = local.encoded_outputs[name]
        path         = "${path.module}/../templates/${template_file.filename}"
      }
    ]
  ])

  # Simplify the naming module and extend for unsupported naming types
  naming_map = {
    for comp_k, comp_v in module.azure_naming : comp_k => merge({
      for res_k, res_v in comp_v : res_k => {
        name = res_v.name_unique
      } if can(res_v.name_unique)
    }, lookup(local.extended_naming_map, comp_k, {}))
  }

  extended_naming_map = {
    for comp_k, comp_v in module.azure_naming : comp_k => {
      "fabric_capacity" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique),
          "fc"
        )
      },
      "fabric_workspace" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "resource_group", {}).name_unique,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "resource_group", {}).name_unique),
          "fwks"
        )
      },
      "fabric_lakehouse" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique),
          "fl"
        )
      },
      "fabric_environment" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "resource_group", {}).name_unique,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "resource_group", {}).name_unique),
          "fenv"
        )
      },
      "frontdoor_firewall_policy" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique),
          "fdfwp"
        )
      },
      "frontdoor_endpoint" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "resource_group", {}).name_unique,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "resource_group", {}).name_unique),
          "fde"
        )
      },
      "frontdoor_security_policy" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "resource_group", {}).name_unique,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "resource_group", {}).name_unique),
          "fdsp"
        )
      },
      "private_dns_zone_virtual_network_link" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "resource_group", {}).name,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "resource_group", {}).name),
          "pdzvl"
        )
      },
      "ai_services" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "resource_group", {}).name_unique,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "resource_group", {}).name_unique),
          "ais"
        )
      },
      "ai_foundry" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique),
          "aif"
        )
      },
      "ai_foundry_project" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique),
          "aifp"
        )
      },
      "key_vault_v2" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "storage_account", {}).name_unique),
          "kv"
        )
      },
      "managed_identity" = {
        name = replace(
          lookup(module.azure_naming[comp_k], "resource_group", {}).name,
          regex("^.{2}", lookup(module.azure_naming[comp_k], "resource_group", {}).name),
          "mi"
        )
      },
    }
  }
}
