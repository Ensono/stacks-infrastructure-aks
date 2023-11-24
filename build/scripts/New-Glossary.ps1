
<#

.SYNOPSIS
Analyse documentation for known acronyms and create glossary

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory = $true)]
    [string]
    # Path to file to update
    $path,

    [string]
    # Path to the directory holding the documents
    $docpath = "docs/",

    [string[]]
    # Extensions of docs that should be analysed
    $extensions = @("adoc", "md")
)

Write-Host "Creating glossary table of acronyms" -ForegroundColor yellow

# Define list of acroynms and expansions
$acronyms = @{
    "EDIR" = @{
        expansion = "Ensono Digital Independent Runner"
        description = "Pipeline runner that allows builds to be run locally and in CI/CD platforms"
    }
    "CRD" = @{
        expansion = "Custom Resource Definition"
        description = "Definitions deployed into Kubernetes that allow custom operations"
    }
    "TF" = @{
        expansion = "Terraform"
        desciption = "Tool used to deploy cloud based infrastructure"
    }
    "CI/CD" = @{
        expansion = "Continuous Integration / Continuous Deployment"
        description = "Tool to run pipeline that build code, deploy apps and infrastructure"
    }
    "ADO" = @{
        expansion = "Azure DevOps"
        description = "Microsoft based Build system"
    }
    "AKS" = @{
        expansion = "Azure Kubernetes Service"
        description = "Microsoft managed Kubernetes control plane"
    }
    "RBAC" = @{
        expansion = "Role Based Access Control"
        description = "Allow access to a resource with the appopriate level of control for a specific user or role"
    }
    "SKU" = @{
        expansion = "Stock Keeping Unit"
        description = "Used to denote the size of a resource to be deployed"
    }
}

# Ensure that the path for the document to append to exists
$dir = Split-Path -Path $path -Parent
if (!(Test-Path -Path $dir)) {
    New-Item -Type Directory -Path $dir | Out-Null
}

# remove the path if it already exists
if (Test-Path -Path $path) {
    Remove-Item -Path $path | Out-Null
}

# Find all the docs in the repo that are applicable
$include = @()
foreach ($ext in $extensions) {
    $include += "*.{0}" -f $ext
}

# create hashtable to add acronyms that have been found
$found = [Ordered]@{}

# Iterate around the acronyms
foreach ($item in $acronyms.GetEnumerator()) {

    # search the files for the current acronym
    $res = Get-ChildItem -Path $docpath -Include $include -File -Recurse | Select-String -Pattern ("\b{0}\b" -f $item.Name)

    if ($res.count -gt 0) {
        $found += @{$item.Name = $item.Value}
    }
}

# Create the AsciiDoc table
$table = [System.Text.StringBuilder]::new()
[void]$table.AppendLine('[cols="1,2,2",options="header",stripes=even]')
[void]$table.AppendLine('|===')
[void]$table.AppendLine('| Acroynm | Expansion | Description')

# iterate around the found items and add to the table
foreach ($item in $found.GetEnumerator()) {

    $row = "| {0} | {1} | {2}" -f $item.Name, $item.Value.expansion, $item.Value.description
    [void]$table.AppendLine($row)
}

[void]$table.AppendLine('|===')

Add-Content -Path $path -Value $table.ToString()
