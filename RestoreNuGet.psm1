Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

# Tools
[string] $NugetToolPath = "$ScriptDir\bin\nuget.exe"

# -------------------------------------------------------------------------------------------------------------------------------------

function RestoreNuGet
{
	Param
	(
		[Parameter()][string] $SolutionPath = $global:SolutionPath,
		[Parameter()][switch] $PauseOnError
	)

	Try
	{
		Write-Host -Foreground "Green" "Restoring NuGet packages..."
		EnvRunExec ( "$NugetToolPath", "restore", "$SolutionPath" )
		New-Item "$global:NugetCachePath" -ItemType Directory -ErrorAction Ignore
		echo $null >> "$global:NugetCachePath\.nuget_package_cache"
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