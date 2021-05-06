Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

function UpdateOutputFileList
{
	Param
	(
		[Parameter()][string]   $SolutionPath          = $global:SolutionPath,
		[Parameter()][string[]] $MsbuildConfigurations = $global:BuildConfigurations,
		[Parameter()][string[]] $MsbuildPlatforms      = $global:BuildPlatforms,
		[Parameter()][switch]   $IsToolVersionProject,
		[Parameter()][switch]   $PauseOnError
	)

	Try
	{
		$SolutionDirectoryPath = Split-Path -Path "$SolutionPath"
		$OutputFilesListBasePath = "$SolutionDirectoryPath\out-index"
		$OutputPath = "$SolutionDirectoryPath\_build\.out"

		# write list of files in output directories
		Write-Host -ForegroundColor "Green" "Writing list of files in output directories..."
		foreach ($Project in Get-ChildItem -Path "$OutputPath" -Directory -Force -ErrorAction SilentlyContinue)
		{
			# enumerate projects under '_build/.out' directory
			$ProjectPath = "$OutputPath\$($Project.Name)"
			foreach ($Configuration in $MsbuildConfigurations)
			{
				foreach ($Platform in $MsbuildPlatforms)
				{
					# enumerate all given combinations of '$Platform.$Configuration' for each project
					$ConfigurationPath = "$ProjectPath\$Platform.$Configuration"
					if (!(Test-Path "$ConfigurationPath" -PathType Container))
					{
						Write-Host -ForegroundColor "Yellow" "Expected build directory '$ConfigurationPath' does not exist. Skip this configuration for project."
						continue
					}

					# clear index of files for specific project with given configuration
					Remove-Item -Recurse -Path "$OutputFilesListBasePath\$($Project.Name)\$Platform.$Configuration" -ErrorAction Ignore
					New-Item -Force -Path "$OutputFilesListBasePath" -Name "$($Project.Name)\$Platform.$Configuration" -ItemType "directory" | out-null

					if ($IsToolVersionProject)
					{
						# the binaries are directly under the '$ConfigurationPath'
						$OutputFilesListPath = "$OutputFilesListBasePath\$($Project.Name)\$Platform.$Configuration\.files.txt"
						Write-Host "=> $OutputFilesListPath"
						Push-Location "$ConfigurationPath"
						Get-ChildItem -Recurse -Force -Attributes !Directory | Resolve-Path -Relative | Out-File -Encoding utf8 "$OutputFilesListPath"
						Pop-Location
					}
					else
					{
						# foreach given target framework exists a directory
						foreach ($Target in Get-ChildItem -Path "$ConfigurationPath" -Directory -Force -ErrorAction SilentlyContinue)
						{
							# compute index file for each target framework
							$TargetDirectoryPath = "$ConfigurationPath\$($Target.Name)"
							$OutputFilesListPath = "$OutputFilesListBasePath\$($Project.Name)\$Platform.$Configuration\$($Target.Name).files.txt"
							Write-Host "=> $OutputFilesListPath"
							Push-Location "$TargetDirectoryPath"
							Get-ChildItem -Recurse -Force -Attributes !Directory | Resolve-Path -Relative | Out-File -Encoding utf8 "$OutputFilesListPath"
							Pop-Location
						}
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