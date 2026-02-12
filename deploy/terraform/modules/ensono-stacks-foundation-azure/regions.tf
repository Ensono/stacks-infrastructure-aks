/*
  Returns multiple regions containing available zones and paired regions

  use:
  module.azure_regions.regions_by_name[var.azure_location].geo_code
  module.azure_regions.regions_by_name[var.azure_location].zones
  module.azure_regions.regions_by_name[var.azure_location].paired_region_name

*/

module "azure_regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.5.0"

  enable_telemetry   = var.enable_avm_telemetry
  geography_filter   = var.region_geography
  recommended_filter = var.region_recommend_filter
}
