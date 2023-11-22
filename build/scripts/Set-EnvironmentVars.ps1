
[CmdletBinding()]
param (

    [Parameter(
        Mandatory=$true,
        ValueFromPipeline=$true
    )]
    [string]
    [Alias("data")]
    # JSON data to set as environment variables
    $json,

    [string]
    # Prefix for environment variables
    $prefix,

    [string]
    # Key which holds the value foe the enviornment variable, if
    # the value is nested
    $key,

    [switch]
    # State if the variables should be displayed on screen
    $show,

    [string[]]
    # List of variables to exclude
    $exclude = @(),

    [string[]]
    # List of variables that should be included
    $include = @(),

    [switch]
    # Allows the values to be passed thru the pipeline
    $passthru,

    [switch]
    # Prevent the environment variables from being created
    $noenv
)

# Convert the data into a hashtable
$data = $json | ConvertFrom-Json -AsHashtable

# Create array to hold the data to pass on the pipeline if specified
$pipeline = @{}

# If a prefix has been set, ensure that it has an underscore appended
if (![String]::IsNullOrEmpty($prefix)) {
    $prefix += "_"
}

# Iterate around the data using an enumerator
foreach ($item in $data.GetEnumerator()) {

    # if the name of the variable is in the exclude list then skip
    if ($exclude -contains $item.Name) {
        Write-Debug ("Skipping variable: {0}" -f $item.Name)
        continue
    }

    if ($include.length -gt 0 -and $include -notcontains $item.Name) {
        Write-Debug ("Variable has not be included for export: {0}" -f $item.Name)
        continue
    }

    # Create the name of the environment variable
    $name = "{0}{1}" -f $prefix, $item.Name

    # Get the value to assign to the variable
    # This depends on whether a key has been specified as it might be a nested value
    if ([String]::IsNullOrEmpty($key)) {
        $value = $item.Value
    } else {
        $value = $item.Value[$key]
    }

    # update the data object with name and value
    $pipeline[$item.Name] = $value

    # Display the var if specified
    if ($show) {
        Write-Host ("{0} - {1}" -f $name, $value)
    }

    # Create the environment variable
    if (!$noenv) {
        New-Item -Path Env:\${name} -Value $value -Force | Out-Null
    }
}

# Output the data if passthru is enabled
if ($passthru) {
    $pipeline
}