Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

# -------------------------------------------------------------------------------------------------------------------------------------

# #################################
# configuration
# #################################

# global configuration (environment variables)
[string] $PRODUCT_NAME_DEFAULT                     = "Default"
[string] $RELEASE_DIRECTORY_DEFAULT                = "C:\Releases"
[string] $GIT_PATH_DEFAULT                         = "C:\Program Files\Git\bin"
[string] $BUILD_CONFIGURATIONS_DEFAULT             = "Debug,Release"
[string] $BUILD_PLATFORMS_DEFAULT                  = "Any CPU,x86,x64"
[string] $USE_REPO_NUGET_CACHE_DEFAULT             = "false"

# ---------------------------------------------------------------------------------------------------------------------

if (Test-Path env:USE_REPO_NUGET_CACHE)
{
	Write-Host `
		-ForegroundColor "Green" `
		"Environment variable USE_REPO_NUGET_CACHE is set to: $env:USE_REPO_NUGET_CACHE"
}
else
{
	$env:USE_REPO_NUGET_CACHE = $USE_REPO_NUGET_CACHE_DEFAULT
	Write-Host `
		-ForegroundColor "Yellow" `
		"Environment variable USE_REPO_NUGET_CACHE is not set. Falling back to: $env:USE_REPO_NUGET_CACHE"
}

if ($env:USE_REPO_NUGET_CACHE -eq "true")
{
	$env:NUGET_PACKAGES = "$ScriptDir\..\_NuGetCache\packages"
	$env:NUGET_PACKAGES = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$env:NUGET_PACKAGES")
	Write-Host `
		-ForegroundColor "Green" `
		"Environment variable NUGET_PACKAGES is forced to $env:NUGET_PACKAGES"
}
elseif ($env:USE_REPO_NUGET_CACHE -eq "false")
{
	if (Test-Path env:NUGET_PACKAGES)
	{
		Write-Host `
			-ForegroundColor "Green" `
			"Environment variable NUGET_PACKAGES is set to: $env:NUGET_PACKAGES"
	}
	else
	{
		$env:NUGET_PACKAGES = "$env:USERPROFILE\.nuget\packages"
		$env:NUGET_PACKAGES = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$env:NUGET_PACKAGES")
		Write-Host `
			-ForegroundColor "Green" `
			"Environment variable NUGET_PACKAGES is not set. Falling back to: $env:NUGET_PACKAGES"
	}
}
else
{
	Write-Host `
		-ForegroundColor "Red"
		"Expecting USE_REPO_NUGET_CACHE to be 'true' or 'false'!"

	exit(-1)
}

$global:NugetCachePath = $env:NUGET_PACKAGES

# ---------------------------------------------------------------------------------------------------------------------

if (Test-Path env:PRODUCT_NAME)
{
	$env:PRODUCT_NAME = $env:PRODUCT_NAME.Trim()
	Write-Host `
		-ForegroundColor "Green" `
		"Environment variable PRODUCT_NAME is set to: $env:PRODUCT_NAME"
}
else
{
	$env:PRODUCT_NAME = $PRODUCT_NAME_DEFAULT
	Write-Host `
		-ForegroundColor "Yellow" `
		"Environment variable PRODUCT_NAME is not set. Falling back to: $env:PRODUCT_NAME"
}

$global:ProductName = $env:PRODUCT_NAME

# ---------------------------------------------------------------------------------------------------------------------

if (Test-Path env:RELEASE_DIRECTORY)
{
	$env:RELEASE_DIRECTORY = $env:RELEASE_DIRECTORY.Trim()
	Write-Host `
		-ForegroundColor "Green" `
		"Environment variable RELEASE_DIRECTORY is set to: $env:RELEASE_DIRECTORY"
}
else
{
	$env:RELEASE_DIRECTORY = $RELEASE_DIRECTORY_DEFAULT
	Write-Host `
		-ForegroundColor "Yellow" `
		"Environment variable RELEASE_DIRECTORY is not set. Falling back to: $env:RELEASE_DIRECTORY"
}

$global:ReleaseDirectory = $env:RELEASE_DIRECTORY

# ---------------------------------------------------------------------------------------------------------------------

if (Test-Path env:SOLUTION_PATH)
{
	$env:SOLUTION_PATH = $env:SOLUTION_PATH.Trim()
	Write-Host `
		-ForegroundColor "Green" `
		"Environment variable SOLUTION_PATH is set to: $env:SOLUTION_PATH"

	$global:SolutionPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($env:SOLUTION_PATH)
}

# ---------------------------------------------------------------------------------------------------------------------

if (Test-Path env:GIT_PATH)
{
	$env:GIT_PATH = $env:GIT_PATH.Trim()
	Write-Host `
		-ForegroundColor "Green" `
		"Environment variable GIT_PATH is set to: $env:GIT_PATH"
}
else
{
	$env:GIT_PATH = $GIT_PATH_DEFAULT
	Write-Host `
		-ForegroundColor "Yellow" `
		"Environment variable GIT_PATH is not set. Falling back to: $env:GIT_PATH"
}

$global:GitDirectoryPath = $env:GIT_PATH
$global:GitPath = "$global:GitDirectoryPath\git.exe"

# ---------------------------------------------------------------------------------------------------------------------

if (Test-Path env:MSBUILD_PATH)
{
	$env:MSBUILD_PATH = $env:MSBUILD_PATH.Trim()
	Write-Host `
		-ForegroundColor "Green" `
		"Environment variable MSBUILD_PATH is set to: $env:MSBUILD_PATH"
}
else
{
	# determine default location of msbuild.exe, if not specified explicitly
	# ---------------------------------------------------------------------------------------------
	[string[]] $MSBUILD_LOCATIONS = @( `
		'C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\bin', `
		'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin', `
		'C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin', `
		'C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin', `
		'C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\MSBuild\15.0\bin', `
		'C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\bin')

	[string] $MSBUILD_PATH_DEFAULT = ''
	foreach ($path in $MSBUILD_LOCATIONS)
	{
		if (Test-Path "$path\msbuild.exe") {
			$MSBUILD_PATH_DEFAULT = $path
			break
		}
	}

	$env:MSBUILD_PATH = $MSBUILD_PATH_DEFAULT
	Write-Host `
		-ForegroundColor "Yellow" `
		"Environment variable MSBUILD_PATH is not set. Falling back to: $env:MSBUILD_PATH"
}

$global:MsbuildDirectoryPath = $env:MSBUILD_PATH
$global:MsbuildPath = "$global:MsbuildDirectoryPath\msbuild.exe"

# push msbuild binary directory to PATH variable to ensure that nuget.exe finds the correct one
$env:PATH = "$global:MsbuildDirectoryPath;$env:PATH"

# ---------------------------------------------------------------------------------------------------------------------

if (Test-Path env:BUILD_CONFIGURATIONS)
{
	$env:BUILD_CONFIGURATIONS = $env:BUILD_CONFIGURATIONS.Trim()
	Write-Host `
		-ForegroundColor "Green" `
		"Environment variable BUILD_CONFIGURATIONS is set to: $env:BUILD_CONFIGURATIONS"
}
else
{
	$env:BUILD_CONFIGURATIONS = $BUILD_CONFIGURATIONS_DEFAULT
	Write-Host `
		-ForegroundColor "Yellow" `
		"Environment variable BUILD_CONFIGURATIONS is not set. Falling back to: $env:BUILD_CONFIGURATIONS"
}

# convert comma-separated list to powershell array
$global:BuildConfigurations = $env:BUILD_CONFIGURATIONS -split " *, *"

# ---------------------------------------------------------------------------------------------------------------------

if (Test-Path env:BUILD_PLATFORMS)
{
	$env:BUILD_PLATFORMS = $env:BUILD_PLATFORMS.Trim()
	Write-Host `
		-ForegroundColor "Green" `
		"Environment variable BUILD_PLATFORMS is set to: $env:BUILD_PLATFORMS"
}
else
{
	$env:BUILD_PLATFORMS = $BUILD_PLATFORMS_DEFAULT
	Write-Host `
		-ForegroundColor "Yellow" `
		"Environment variable BUILD_PLATFORMS is not set. Falling back to: $env:BUILD_PLATFORMS"
}

# convert comma-separated list to powershell array
$global:BuildPlatforms = $env:BUILD_PLATFORMS -split " *, *"
