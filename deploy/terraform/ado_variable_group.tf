# Create Variable groups in Azure DevOps for each of the environments that are being deployed
#
# Uses the local variables to determine which environments are being deployed

resource "azuredevops_variable_group" "vg" {

  for_each = var.create_ado_variable_group ? toset(local.environments) : []

  project_id = data.azuredevops_project.project[0].id

  # define the name of the variable group
  name = "${var.project}-${each.key}-outputs"

  # Create an entry in the variable group for each of the outputs
  dynamic "variable" {
    for_each = local.encoded_outputs[each.key]
    content {
      name  = variable.key
      value = variable.value
    }
  }

}