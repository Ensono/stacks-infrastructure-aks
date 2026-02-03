#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate Inspec input file for infrastructure tests

.DESCRIPTION
    Creates /eirctl/inspec_inputs.yml with Terraform outputs, Azure service versions,
    node pool information, and Key Vault details for use in Inspec tests.

.EXAMPLE
    ./Set-InspecInputs.ps1
#>

[CmdletBinding()]
param()

# Require TF_FILE_LOCATION to be pre-set for consistency with other tasks
if ([string]::IsNullOrEmpty($env:TF_FILE_LOCATION)) {
    Write-Error "TF_FILE_LOCATION is not set. Please set TF_FILE_LOCATION (for example to '/eirctl/deploy/terraform') before running this task, or configure it in the environment setup step."
    exit 1
}

# Fail-fast validation for required environment variables
$requiredVars = @('TF_VAR_stage', 'TF_VAR_location', 'ARM_CLIENT_ID', 'ARM_CLIENT_SECRET', 'ARM_TENANT_ID', 'ARM_SUBSCRIPTION_ID')
$missing = $requiredVars | Where-Object { [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($_)) }
if ($missing.Count -gt 0) {
    Write-Error "Missing required environment variables: $($missing -join ', '). Run 'source ./.eirctl/envvar-azure-dev.sh' or set these variables before running tests."
    exit 1
}

Import-Module Az.Aks
Import-Module Az.KeyVault -ErrorAction SilentlyContinue
Invoke-Terraform -Workspace -Arguments $env:TF_VAR_stage -Path $env:TF_FILE_LOCATION
Invoke-Terraform -Output -Path $env:TF_FILE_LOCATION | /eirctl/build/scripts/Set-EnvironmentVars.ps1 -prefix "TFOUT" -key "value" -passthru | ConvertTo-Yaml | Out-File -Path /eirctl/inspec_inputs.yml
Get-AzureServiceVersions -service aks -client_id $env:ARM_CLIENT_ID -client_password $env:ARM_CLIENT_SECRET -tenant_id $env:ARM_TENANT_ID -location $env:TF_VAR_location | ConvertTo-Yaml | Out-File -Path /eirctl/inspec_inputs.yml -Append
Add-Content -Path /eirctl/inspec_inputs.yml -Value "region: $($env:TF_VAR_location)"
Add-Content -Path /eirctl/inspec_inputs.yml -Value "kubernetes_private_cluster: $($env:TF_VAR_is_cluster_private)"
Add-Content -Path /eirctl/inspec_inputs.yml -Value "subscription_id: $($env:ARM_SUBSCRIPTION_ID)"
Add-Content -Path /eirctl/inspec_inputs.yml -Value "azure_application_id: $($env:ARM_CLIENT_ID)"

$nodePools = @{}
if ($env:TF_VAR_aks_node_pools -and $env:TF_VAR_aks_node_pools.Trim() -ne "" -and $env:TF_VAR_aks_node_pools.Trim() -ne "{}") {
  $nodePools = $env:TF_VAR_aks_node_pools | ConvertFrom-Json
}
$additionalPoolCount = 0
if ($nodePools -is [System.Collections.IDictionary]) {
  $additionalPoolCount = $nodePools.Keys.Count
}
elseif ($nodePools -is [System.Array]) {
  $additionalPoolCount = $nodePools.Count
}
else {
  $additionalPoolCount = $nodePools.PSObject.Properties.Count
}
$nodePoolCount = 1 + [int]$additionalPoolCount
Add-Content -Path /eirctl/inspec_inputs.yml -Value "node_pool_count: $nodePoolCount"

$publicIpSku = "Standard"
if ($env:TFOUT_app_gateway_public_ip_name -and $env:TFOUT_app_gateway_resource_group_name) {
    $publicIp = Get-AzPublicIpAddress -Name $env:TFOUT_app_gateway_public_ip_name -ResourceGroupName $env:TFOUT_app_gateway_resource_group_name -ErrorAction SilentlyContinue
    if ($publicIp -and $publicIp.Sku -and $publicIp.Sku.Name) {
        $publicIpSku = $publicIp.Sku.Name
    }
}
Add-Content -Path /eirctl/inspec_inputs.yml -Value "public_ip_sku: $publicIpSku"

$keyVaults = @()
if ($env:TFOUT_resource_group_name) {
  $keyVaultsRaw = Get-AzKeyVault -ResourceGroupName $env:TFOUT_resource_group_name -ErrorAction SilentlyContinue
  foreach ($kv in @($keyVaultsRaw)) {
    $skuName = $kv.Sku.Name
    if (-not $skuName) {
      $skuName = "standard"
    }
    $keyVaults += [pscustomobject]@{
      name = $kv.VaultName
      sku  = $skuName
    }
  }
}
@{ key_vault = @($keyVaults) } | ConvertTo-Yaml | Out-File -Path /eirctl/inspec_inputs.yml -Append
