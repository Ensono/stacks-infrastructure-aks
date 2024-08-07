[CmdletBinding()]
param (
	[string]
	# Path to the configuration file stating which charts should be deployed
	$Path = $env:HELM_CHARTS,

	[string[]]
	# Names of charts that should be deployed.
	# This does not override the enabled flag, but allows a subset of enabled chartts
	# to be deployed
	$Names,

	[string]
	# Path to temporary directory for writing out templates
	$Tempdir = "tmp/",

	[string]
	# Cloud provider being targeted
	$Provider = $env:CLOUD_PROVIDER,

	[string]
	[Alias("ResourceGroup")]
	# Identifier for finding the cluster
	# In the case of Azure this is the resource group name
	$Identifier,

	[string]
	[Alias("aksname")]
	# Name of the cluster
	$ClusterName,

	[bool]
	$K8sAuthRequired = $true,

	[switch]
	# Specify a dryrun, which will output the helm command to run
	$Dryrun
)

# Set defaults on undefined parameters
if ([String]::IsNullOrEmpty($Path))
{
	$path = [IO.Path]::Join("deploy", "helm", "k8s_apps.yaml")
}

# Check to see if the path exists
if (! (Test-Path -Path $path))
{
	Write-Error ("Specified file cannot be located: {0}" -f $path)
	return
}

# Determine if the tempdir path exists, if not create it
if (! (Test-Path -Path $Tempdir))
{
	Write-Information ("Creating temporary dir: {0}" -f $Tempdir)
	New-Item -Type Directory -Path $Tempdir | Out-Null
}

# Read in the configuration, replacing parameters as necessary
$template_name = Split-Path -Path $path -Leaf
$target = [IO.Path]::Join($Tempdir, $template_name)

# Expand the template for the values
$template = Get-Content -Path $path -Raw
if ([String]::IsNullOrEmpty($template))
{
	New-Item -Type File -Path $target -Force | Out-Null
}
else
{
	Expand-Template -Template $template -Target $target
}

$helm = Get-Content -Path $target -Raw | ConvertFrom-Yaml

Write-Host $(Get-Content -Path $target -Raw)

# Iterate around all the charts in the object
foreach ($chart in $helm.charts)
{
	# if any names have been specified only run if the current chart is in that list
	if ($Names.length -gt 0 -and $Names -notcontains $chart.name)
	{
		Write-Warning -Message ("Skipping chart due to names list: {0} not in [{1}]" -f $chart.name, ($Names -join ","))
	}

	# Skip the chart if not enabled
	if (! $chart.enabled)
	{
		Write-Warning -Message ("Chart is not enabled, skpping: {0}" -f $chart.name)
		continue
	}

	# Skip chart if it is not for this current cloud platform
	if ($chart.clouds.length -gt 0 -and $chart.clouds -notcontains $env:CLOUD_PLATFORM)
	{
		Write-Warning -Message ("Chart is not for this cloud platform: {0}" -f $env:CLOUD_PLATFORM)
		continue
	}

	# Check if the values_template file exists
	if (! [String]::IsNullOrEmpty($chart.values_template) -and !(Test-Path -Path $chart.values_template))
	{
		Write-Warning -Message ("Values template file cannnot be found: {0}" -f $chart.values_template)
		continue
	}

	$namespace = "default"
	if (! [String]::IsNullOrEmpty($chart.namespace))
	{
		$namespace = $chart.namespace
	}

	# If a repo has been set, run the command to add the repo to helm
	if (! [String]::IsNullOrEmpty($chart.repo))
	{
		$command = "Invoke-Helm -Repo -RepositoryName {0} -RepositoryUrl {1}" -f $chart.location, $chart.repo

		if ($Dryrun)
		{
			Write-Host $command
		}
		else
		{
			Invoke-Expression $command
		}
	}

	# if `wrap_raw_yaml` is true then download YAML file and wrap in a dummy chart
	if (! [String]::IsNullOrEmpty($chart.wrap_raw_yaml) -and $chart.wrap_raw_yaml -eq $true)
	{
		if (Test-Path -Path "${Tempdir}/$($chart.name)")
		{
			Remove-Item -Path "${Tempdir}/$($chart.name)" -Recurse
		}

		New-Item -ItemType "Directory" -Path $Tempdir -Name $chart.name
		New-Item -ItemType "Directory" -Path "${Tempdir}/$($chart.name)" -Name templates
		$chartYaml = @"
apiVersion: v2
name: $($chart.name)
description: A chart wrapper for single raw YAML files. Check the deployed resources for more information.

type: application

version: 0.0.1
"@
		Add-Content -Path "${Tempdir}/$($chart.name)/Chart.yaml" -Value $chartYaml
		Add-Content -Path "${Tempdir}/$($chart.name)/values.yaml" -Value ""
		Invoke-WebRequest $chart.location -OutFile "${Tempdir}/$($chart.name)/templates/main.yaml"

		$chart.location = $Tempdir
		$chart.values_template = "${Tempdir}/$($chart.name)/values.yaml"
	}

	$authToK8s = $K8sAuthRequired

	# Configure an array to hold the pareameters for the helm cmdlet
	$helm_args = @()
	$helm_args += "-install"
	$helm_args += "-chartpath `"{0}/{1}`"" -f $chart.location, $chart.name
	$helm_args += "-identifier {0}" -f $Identifier
	$helm_args += "-target {0}" -f $ClusterName
	$helm_args += "-namespace {0}" -f $namespace
	$helm_args += "-provider {0}" -f $Provider
	$helm_args += "-k8sauthrequired `${0}" -f $authToK8s

	# Only Auth to K8s once
	if ($true -eq $authToK8s)
	{
		$authToK8s = $false
	}

	if (! [String]::IsNullOrEmpty($chart.version))
	{
		$helm_args += "-chartversion {0}" -f $chart.version
	}

	# Determine the release name
	$release_name = $chart.release_name
	if ([String]::IsNullOrEmpty($release_name))
	{
		$release_name = $chart.name
	}
	$release_name = ($release_name -replace " |_", "-").ToLower()
	$helm_args += "-releasename {0}" -f $release_name

	# Determime the path for the rendered template
	# Only if a values template has been specified
	if (! [String]::IsNullOrEmpty($chart.values_template))
	{
		$template_name = Split-Path -Path $chart.values_template -Leaf
		$target = [IO.Path]::Join($Tempdir, $template_name)

		# Expand the template for the values
		$template = Get-Content -Path $chart.values_template -Raw
		if ([String]::IsNullOrEmpty($template))
		{
			New-Item -Type File -Path $target -Force | Out-Null
		}
		else
		{
			Expand-Template -Template $template -Target $target
		}

		$helm_args += "-valuepath {0}" -f $target
	}

	# Build up the command to run
	$command = "Invoke-Helm {0}" -f ($helm_args -join " ")

	Write-Host ("DEPLOYING: '{0}/{1}'" -f $chart.location, $chart.name)

	if ($Dryrun)
	{
		Write-Host $command
	}
	else
	{
		Invoke-Expression $command
	}

	if (! [String]::IsNullOrEmpty($chart.rollout_checks))
	{
		# Build up Rollout Status checks command to run
		$rolloutBaseCommand = "kubectl rollout status -n {0} --timeout {1} {2}"

		foreach ($rolloutCheck in $chart.rollout_checks)
		{
			$namespace = [String]::IsNullOrEmpty($rolloutCheck.namespace) ? $chart.namespace : $rolloutCheck.namespace
			$timeout = [String]::IsNullOrEmpty($rolloutCheck.timeout) ? '60s' : $rolloutCheck.timeout
			$rolloutCommand = $rolloutBaseCommand -f $namespace, $timeout, $rolloutCheck.name

			if ($Dryrun)
			{
				Write-Host $rolloutCommand
			}
			else
			{
				Invoke-Expression $rolloutCommand

				if ($LASTEXITCODE -ne 0)
				{
					throw "DEPLOYING FAILED: Failed to run command '${rolloutCommand}' in the rollout status checks for '{0}{1}'..." -f $chart.location, $chart.name
				}
			}
		}
	}

	Write-Host ("DEPLOYING FINISHED: '{0}/{1}'`n`n" -f $chart.location, $chart.name)
}
