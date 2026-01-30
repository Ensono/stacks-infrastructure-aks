<#
.SYNOPSIS
    Clears the Terraform state lock from Azure Storage if it exists.

.DESCRIPTION
    This script checks if a Terraform state lock file exists in the Azure Storage backend
    and removes it if present. This is useful for handling cases where Terraform operations
    are cancelled mid-execution, leaving the state in a locked condition.

.PARAMETER StorageAccountName
    The name of the Azure Storage account containing the Terraform state.

.PARAMETER ContainerName
    The name of the blob container containing the Terraform state.

.PARAMETER StateKey
    The key/path to the Terraform state file in the container.

.PARAMETER ResourceGroupName
    The resource group containing the storage account.

.EXAMPLE
    .\Clear-TerraformStateLock.ps1 -StorageAccountName "mystorageaccount" `
        -ContainerName "tfstate" -StateKey "mystate.tfstate" `
        -ResourceGroupName "my-rg"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerName,

    [Parameter(Mandatory = $true)]
    [string]$StateKey,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Checking for Terraform state lock..."
    Write-Host "Storage Account: $StorageAccountName"
    Write-Host "Container: $ContainerName"
    Write-Host "State Key: $StateKey"

    # Get the storage account context
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    $storageContext = $storageAccount.Context

    # Construct the lock file path (.tflock)
    $lockFilePath = "$StateKey.tflock"

    Write-Host "Lock file path: $lockFilePath"

    # Check if lock file exists
    $lockFile = Get-AzStorageBlob -Container $ContainerName -Blob $lockFilePath -Context $storageContext -ErrorAction SilentlyContinue

    if ($lockFile) {
        Write-Host "State lock file found. Removing lock..."

        # Remove the lock file
        $lockFile | Remove-AzStorageBlob -Force -Confirm:$false

        Write-Host "✓ Terraform state lock has been successfully removed."
        exit 0
    }
    else {
        Write-Host "✓ No Terraform state lock file found. State is not locked."
        exit 0
    }
}
catch {
    Write-Error "Error while attempting to clear Terraform state lock: $_"
    Write-Host "This may indicate the state is not locked or there's an authentication issue."
    # Don't fail the pipeline on lock removal errors - log and continue
    exit 0
}
