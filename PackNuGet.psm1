Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

function PackNuGet
{
	Param
	(
		[Parameter()][string] $MsbuildVerbosity = 'minimal',
		[Parameter()][switch] $PauseOnError
	)

	Try
	{
		Write-Host -ForegroundColor "Green" "Packing NuGet packages..."
		$cmd = @($MsbuildPath)
		$cmd += "$ScriptDir\NuGet.msbuild"
		$cmd += "/property:NuGetPackageVersion={{GitVersion_NuGetVersionV2}}"
		$cmd += "/verbosity:$MsbuildVerbosity"
		$cmd += "/t:Pack"
		EnvRunExec ($cmd)

		# create empty file to work around issues when collecting build artifacts,
		# if no nuget packages have been created
		$deployFolder = "$ScriptDir\..\_deploy"
		New-Item "$deployFolder" -ItemType Directory -ErrorAction Ignore
		echo $null >> "$deployFolder\.nuget_deploy_folder"
	}
	Catch [Exception]
	{
		# tell the caller it has all gone wrong
		echo $_.Exception|format-list -force
		if ($PauseOnError) {
			Read-Host "Press ANY key..."
		}
		exit(-1)
	}
}