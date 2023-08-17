
[CmdletBinding()]
param (

    [string]
    # Prefix to look for in enviornment variables
    $prefix = "TF_VAR_*"
)

# configure hashtable of found variables
$tfvars = @{}

# Output the values of the enviornment variables
Get-ChildItem -Path env: | Where-Object name -like $prefix | % {

    # Get th name of the variable, without the prefix
    $name = $_.name -replace $prefix,""

    # set the value
    $value = $_.value # -replace "\`"", "\`""

    if (!($value -is [int]) -and !($value.StartsWith("{"))) {
        $value = "`"{0}`"" -f $value
    }

    $tfvars[$name.ToLower()] = $value

}

foreach ($item in $tfvars.GetEnumerator()) {
    Write-Output ("{0} = {1}" -f $item.name, $item.value)
}