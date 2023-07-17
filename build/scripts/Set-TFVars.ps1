
[CmdletBinding()]
param (

    [string]
    # Prefix to look for in enviornment variables
    $prefix = "TF_VAR_*"
)

$tfvars =  [System.Text.StringBuilder]::new()


# Output the values of the enviornment variables
Get-ChildItem -Path env: | Where-Object name -like $prefix | % {

    # Get th name of the variable, without the prefix
    $name = $_.name -replace $prefix,""

    # set the value
    $value = $_.value # -replace "\`"", "\`""

    if (!($value -is [int]) -and !($value.StartsWith("{"))) {
        $value = "`"{0}`"" -f $value
    }

    $line = '{0} = {1}' -f $name, $value
    [void]$tfvars.AppendLine($line)

}

$tfvars.ToString()