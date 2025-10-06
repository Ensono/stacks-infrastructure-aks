

variable "enable_avm_telemetry" {
  description = <<DESCRIPTION
Allow Microsoft to collect telemetry about the Azure Verified Modules are being used.
https://aka.ms/avm/telemetryinfo has more information.
DESCRIPTION
  type        = bool
  default     = false
}

variable "avm_region_version" {
  description = <<DESCRIPTION
Set the version of the Azure Verified Module to use.
DESCRIPTION
  type        = string
  default     = "0.5.0"
}

variable "region_recommend_filter" {
  description = <<DESCRIPTION
State if the module should only return regions as recommended by the Azure locations API
DESCRIPTION
  type        = bool
  default     = true
}

variable "region_geography" {
  description = <<DESCRIPTION
If provided the regions returned will only be from the specified geography.
DESCRIPTION
  type        = string
  default     = null
}

variable "outputs" {
  description = <<DESCRIPTION
Outputs that need to be turned into environment files for local development
This should be a JSON string that has been passed to the module from the consuming file.
DESCRIPTION
  type        = string
  default     = null
}

variable "location" {
  description = "Location of where the resources should be deployed"
}

variable "company_name_short" {
  description = "Short version of the company name"
}

variable "project" {
  type        = set(string)
  description = "Name of the project"
}

variable "output_path" {
  description = "Path to where generated files should be saved"
  default     = "../../outputs"
}

variable "environments" {
  description = "List of environments being deployed"
}

variable "generate_env_files" {
  description = "State if the environment files should be generated"
  default     = false
}

variable "stage_name" {
  description = "Name of the terraform stage being deployed"
}
