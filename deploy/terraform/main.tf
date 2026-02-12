module "naming" {
  source = "./modules/ensono-stacks-foundation-azure"

  stage_name = var.stage

  outputs = jsonencode(local.outputs)

  location           = var.location
  company_name_short = local.company_short_name
  project            = [var.project]
  output_path        = "${path.module}/../../../outputs"
  generate_env_files = var.create_env_files
  environments       = local.environments
}
