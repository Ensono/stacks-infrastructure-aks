
output "names" {
  value = module.azure_naming
}

output "extended_names" {
  value = local.extended_naming_map
}

output "regions" {
  value = module.azure_regions
}

output "computed_outputs" {
  value = local.outputs
}

output "encoded_outputs" {
  value = local.encoded_outputs
}

# Set an output that has the current user from the environment
output "current_user" {
  value = try(data.external.current_user.result.username, "unknown")
}
