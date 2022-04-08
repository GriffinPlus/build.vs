Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"
Import-Module "$ScriptDir\UpdateOutputFileList.psm1"

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
		foreach ($Configuration in $MsbuildConfigurations)
		{
			foreach ($Platform in $MsbuildPlatforms)
			{
				# build solution for the selected platform/configuration
				Write-Host -ForegroundColor "Green" "Building solution for platform '$Platform' in configuration '$Configuration'..."
				$cmd = @($MsbuildPath)
				$cmd += "$SolutionPath"
				$cmd += "/property:Configuration=$Configuration"
				$cmd += "/property:Platform=$Platform"
				if ($MsbuildProperties) { $cmd += "/property:$MsbuildProperties" }
				$cmd += "/verbosity:$MsbuildVerbosity"
				$cmd += "/t:Build"
				EnvRunExec $cmd
			}
		}

		# Update output files for given configurations
		UpdateOutputFileList `
			-SolutionPath "$SolutionPath" `
			-PauseOnError:$PauseOnError

		# Check consistency of build output
		if (!$SkipConsistencyCheck)
		{
			$OutputFilesListBasePath = "$SolutionDirectoryPath\out-index"

			Write-Host -ForegroundColor "Green" "Checking consistency of files in output directories..."
			$cmd = @($GitPath)
			$cmd += "diff"
			$cmd += "--"
			$cmd += Resolve-Path -Relative "$OutputFilesListBasePath"
			$diff = (EnvRunExec $cmd) | Out-String
			if ($diff.Length -ne 0)
			{
				Write-Host -ForegroundColor "Red" "Encountered a diff for '$OutputFilesListBasePath'. Check build output for new assemblies..."
				Write-Host -ForegroundColor "Red" "$diff"
				if ($PauseOnError) {
					Read-Host "Press ANY key..."
				}
				exit(-1)
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