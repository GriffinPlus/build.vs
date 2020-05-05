Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

function Build
{
	Param
	(
		[Parameter()][string]   $SolutionPath          = $global:SolutionPath,
		[Parameter()][string]   $MsbuildVerbosity      = 'minimal',
		[Parameter()][string[]] $MsbuildConfigurations = $global:BuildConfigurations,
		[Parameter()][string[]] $MsbuildPlatforms      = $global:BuildPlatforms,
		[Parameter()][string]   $MsbuildProperties,
		[Parameter()][switch]   $PauseOnError,
		[Parameter()][switch]   $SkipConsistencyCheck
	)

	$SolutionDirectoryPath = Split-Path -Path "$SolutionPath"
	$SolutionName = (Get-Item "$SolutionPath").BaseName

	Try
	{
		foreach ($configuration in $MsbuildConfigurations)
		{
			foreach ($platform in $MsbuildPlatforms)
			{
				# build solution for the selected platform/configuration
				Write-Host -ForegroundColor "Green" "Building solution for platform '$platform' in configuration '$configuration'..."
				$cmd = @($MsbuildPath)
				$cmd += "$SolutionPath"
				$cmd += "/property:Configuration=$configuration"
				$cmd += "/property:Platform=$platform"
				$cmd += "/property:SolutionConfiguration=$configuration"
				$cmd += "/property:SolutionPlatform=$platform"
				if ($MsbuildProperties) { $cmd += "/property:$MsbuildProperties" }
				$cmd += "/verbosity:$MsbuildVerbosity"
				$cmd += "/t:Build"
				EnvRunExec $cmd

				# write list of files in output directory
				Write-Host -ForegroundColor "Green" "Writing list of files in output directory for platform '$platform' in configuration '$configuration'..."
				$BuildDirectoryPath = "$SolutionDirectoryPath\_build\$SolutionName.$platform.$configuration"
				$OutputFilesListPath = "$SolutionDirectoryPath\$SolutionName.$platform.$configuration.files.txt"
				Push-Location "$BuildDirectoryPath"
				Get-ChildItem -Recurse -Force -Attributes !Directory | Resolve-Path -Relative | Out-File -Encoding utf8 "$OutputFilesListPath"
				Pop-Location

				# Check consistency of build output
				if (!$SkipConsistencyCheck)
				{
					Write-Host -ForegroundColor "Green" "Checking consistency of files in output directory for platform '$platform' in configuration '$configuration'..."
					$cmd = @($GitPath)
					$cmd += "diff"
					$cmd += "--"
					$cmd += Resolve-Path -Relative "$OutputFilesListPath"
					$diff = (EnvRunExec $cmd) | Out-String
					if ($diff.Length -ne 0)
					{
						Write-Host -ForegroundColor "Red" "Encountered a diff for '$OutputFilesListPath'. Check build output for new assemblies..."
						Write-Host -ForegroundColor "Red" "$diff"
						if ($PauseOnError) {
							Read-Host "Press ANY key..."
						}
						exit(-1)
					}
				}
			}
		}
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