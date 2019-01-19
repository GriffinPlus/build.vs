Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

# -------------------------------------------------------------------------------------------------------------------------------------

# #####################################################################################################################################
# configuration
# #####################################################################################################################################

# global configuration (environment variables)
# ---------------------------------------------------------------------------------------------
[string] $PRIVATE_NUGETFEED_PATH_DEFAULT  = "C:\Griffin+ NugetFeed"
[string] $env:ENVRUN_DATABASE             = "$ScriptDir\..\_build\EnvRun.db"

# determine default location of msbuild.exe, if not specified explicitly
# ---------------------------------------------------------------------------------------------
[string[]] $MSBUILD_LOCATIONS = @( `
	'C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\MSBuild\15.0\bin', `
	'C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\bin')

[string] $MSBUILD_15_PATH_DEFAULT = ''
foreach ($path in $MSBUILD_LOCATIONS)
{
	if (Test-Path "$path\msbuild.exe") {
		$MSBUILD_15_PATH_DEFAULT = $path
		break;
	}
}

# Tools
# ---------------------------------------------------------------------------------------------
[string]  $EnvRunToolPath         = "$ScriptDir\bin\envrun.exe"
[string]  $GitVersionToolPath     = "$ScriptDir\bin\GitVersion\GitVersion.exe"
[string]  $PreBuildWizardToolPath = "$ScriptDir\bin\PreBuildWizard\PreBuildWizard.exe"
[string]  $NugetToolPath          = "$ScriptDir\bin\nuget.exe"

# -------------------------------------------------------------------------------------------------------------------------------------

# use environment variables, if set - otherwise fall back to defaults

if (-not (Test-Path env:PRIVATE_NUGETFEED_PATH))
{
	$env:PRIVATE_NUGETFEED_PATH = $PRIVATE_NUGETFEED_PATH_DEFAULT
	Write-Host `
		-ForegroundColor "Yellow" `
		"Environment variable PRIVATE_NUGETFEED_PATH is not set. Falling back to: $env:PRIVATE_NUGETFEED_PATH"
}

if (-not (Test-Path env:MSBUILD_15_PATH))
{
	$env:MSBUILD_15_PATH = $MSBUILD_15_PATH_DEFAULT
	Write-Host `
		-ForegroundColor "Yellow" `
		"Environment variable MSBUILD_15_PATH is not set. Falling back to: $env:MSBUILD_15_PATH"
}

# push msbuild binary directory to PATH variable to ensure that nuget.exe finds the correct one
$env:PATH = "$env:MSBUILD_15_PATH;$env:PATH"

# generate path to msbuild.exe
$msbuild = "$env:MSBUILD_15_PATH\msbuild.exe"

# -------------------------------------------------------------------------------------------------------------------------------------

function Build
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $SolutionPath,
		[Parameter()][string] $MsbuildVerbosity = 'minimal',
		[Parameter()][string[]] $MsbuildConfigurations = @('Debug', 'Release'),
		[Parameter()][string[]] $MsbuildPlatforms = @('Any CPU', 'x86', 'x64'),
		[Parameter()][string] $MsbuildProperties,
		[Parameter()][switch] $PauseOnError
	)

	$SolutionDir = Split-Path -Path "$SolutionPath"

	Try
	{
		# let gitversion determine the version number from the git history via tags
		Write-Host -ForegroundColor "Green" "Determining version from the git history..."
		Copy-Item "$ScriptDir\GitVersion.yml" -Destination "$ScriptDir\.."
		$WorkingDirectory = Get-Location
		Set-Location -Path "$ScriptDir\.."
		EnvRunExec ( "$GitVersionToolPath", "/output", "buildserver" )
		Set-Location -Path "$WorkingDirectory"

		# remove old build output
		Write-Host -ForegroundColor "Green" "Removing old build output..."
		foreach ($configuration in $MsbuildConfigurations)
		{
			foreach ($platform in $MsbuildPlatforms)
			{
				$cmd = @($msbuild)
				$cmd += "$SolutionPath"
				$cmd += "/property:Configuration=$configuration;Platform=$platform"
				if ($MsbuildProperties) { $cmd += "/property:$MsbuildProperties" }
				$cmd += "/verbosity:$MsbuildVerbosity"
				$cmd += "/t:Clean"
				EnvRunExec $cmd
			}
		}

		# restoring nuget packages
		Write-Host -ForegroundColor "Green" "Restoring NuGet packages..."
		EnvRunExec ( "$NugetToolPath", "restore", "$SolutionPath" )

		# patch templates and assembly infos with current version number
		# check consistency of NuGet packages
		Write-Host -ForegroundColor "Green" "Patching version information into source code and checking consistency of NuGet packages..."
		EnvRunExec ( "$PreBuildWizardToolPath", "$SolutionDir" )

		# build projects
		foreach ($configuration in $MsbuildConfigurations)
		{
			foreach ($platform in $MsbuildPlatforms)
			{
				Write-Host -ForegroundColor "Green" "Building solution for platform '$platform' in configuration '$configuration'..."
				$cmd = @($msbuild)
				$cmd += "$SolutionPath"
				$cmd += "/property:Configuration=$configuration;Platform=$platform"
				if ($MsbuildProperties) { $cmd += "/property:$MsbuildProperties" }
				$cmd += "/verbosity:$MsbuildVerbosity"
				$cmd += "/t:Build"
				EnvRunExec $cmd
			}
		}

		# pack nuget packages
		Write-Host -ForegroundColor "Green" "Packing NuGet packages..."
		$cmd = @($msbuild)
		$cmd += "$ScriptDir\NuGet.msbuild"
		$cmd += "/property:NuGetPackageVersion={{GitVersion_NuGetVersionV2}}"
		$cmd += "/verbosity:$MsbuildVerbosity"
		$cmd += "/t:Pack"
		EnvRunExec ($cmd)
	}
	Catch [Exception]
	{
		# tell the caller it has all gone wrong
		echo $_.Exception|format-list -force
		if ($PauseOnError) {
			Read-Host "Press ANY key..."
		}
		$host.SetShouldExit(-1)
		throw
	}
}


# ###############################################################################################################################
# Helper functions
# ###############################################################################################################################


function Exec
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=1)][scriptblock]$cmd,
		[Parameter(Position=1,Mandatory=0)][string]$errorMessage = ("Error executing command {0}" -f $cmd)
	)
	& $cmd
	if ($lastexitcode -ne 0) {
		throw ("Exec: " + $errorMessage)
	}
}

function EnvRunExec
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=1)][string[]]$cmd
	)
	$cmd = '''' + ($cmd -join ''', ''') + ''''
	$scriptCode = "& ""$EnvRunToolPath"" ($cmd)"
	$script = [scriptblock]::Create($scriptCode)
	# echo "SCRIPT: $script"
	Exec $script
}