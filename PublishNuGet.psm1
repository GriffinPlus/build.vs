Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

function PublishNuGet
{
	Param
	(
		[Parameter()][string] $MsbuildVerbosity = 'minimal',
		[Parameter()][switch] $PauseOnError
	)

	Try
	{
		Write-Host -ForegroundColor "Green" "Publishing NuGet packages..."
		$cmd = @($MsbuildPath)
		$cmd += "$ScriptDir\NuGet.msbuild"
		$cmd += "/verbosity:$MsbuildVerbosity"
		$cmd += "/t:Publish"
		EnvRunExec ($cmd)
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

function PublishNuGetToDeveloperFeed
{
	Param
	(
		[Parameter()][string] $MsbuildVerbosity = 'minimal',
		[Parameter()][switch] $PauseOnError
	)

	$OldNuGetFeedPath = $env:GP_DEV_BUILD_NUGETFEED_PATH

	Try
	{
		$env:GP_DEV_BUILD_NUGETFEED_PATH = "%USERPROFILE%\AppData\Local\Griffin+ Developer NuGet Feed"

		Write-Host -ForegroundColor "Green" "Publishing NuGet packages on local feed '$env:GP_DEV_BUILD_NUGETFEED_PATH'..."
		$cmd = @($MsbuildPath)
		$cmd += "$ScriptDir\NuGet.msbuild"
		$cmd += "/verbosity:$MsbuildVerbosity"
		$cmd += "/t:PublishLocal"
		EnvRunExec ($cmd)
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
	Finally
	{
		$env:GP_DEV_BUILD_NUGETFEED_PATH = $OldNuGetFeedPath
	}
}