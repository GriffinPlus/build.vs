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
				if ($MsbuildProperties) { $cmd += "/property:$MsbuildProperties" }
				$cmd += "/verbosity:$MsbuildVerbosity"
				$cmd += "/t:Build"
				EnvRunExec $cmd
			}
		}

		# clear index of files in output directories
		$OutputFilesListBasePath = "$SolutionDirectoryPath\out-index"
		Remove-Item -Recurse -Path "$OutputFilesListBasePath" -ErrorAction Ignore

		# write list of files in output directorys
		Write-Host -ForegroundColor "Green" "Writing list of files in output directories..."
		$BuildPath = "$SolutionDirectoryPath\_build"
		foreach ($Project in Get-ChildItem -Path "$BuildPath" -Directory -Exclude .* -Force -ErrorAction SilentlyContinue)
		{
			$ProjectPath = "$BuildPath\$($Project.Name)"
			foreach ($Configuration in Get-ChildItem -Path "$ProjectPath" -Directory -Force -ErrorAction SilentlyContinue)
			{
				$ConfigurationPath = "$ProjectPath\$($Configuration.Name)"
				foreach ($Target in Get-ChildItem -Path "$ConfigurationPath" -Directory -Force -ErrorAction SilentlyContinue)
				{
					$TargetDirectoryPath = "$ConfigurationPath\$($Target.Name)"
					$OutputFilesListPath = "$OutputFilesListBasePath\$($Project.Name)\$($Configuration.Name)\$($Target.Name).files.txt"
					New-Item -Force -Path "$OutputFilesListBasePath" -Name "$($Project.Name)\$($Configuration.Name)" -ItemType "directory" | out-null
					Write-Host "=> $OutputFilesListPath"
					Push-Location "$TargetDirectoryPath"
					Get-ChildItem -Recurse -Force -Attributes !Directory | Resolve-Path -Relative | Out-File -Encoding utf8 "$OutputFilesListPath"
					Pop-Location
				}
			}
		}

		# Check consistency of build output
		if (!$SkipConsistencyCheck)
		{
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