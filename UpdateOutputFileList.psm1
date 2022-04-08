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
		[Parameter()][string]   $SolutionPath = $global:SolutionPath,
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
			foreach ($Configuration in Get-ChildItem -Path "$ProjectPath" -Directory -Force -ErrorAction SilentlyContinue)
			{
				# enumerate all given combinations of platform and configuration for each project
				$ConfigurationPath = "$ProjectPath\$($Configuration.Name)"

				# clear index of files for specific project with given configuration
				Remove-Item -Recurse -Path "$OutputFilesListBasePath\$($Project.Name)\$($Configuration.Name)" -ErrorAction Ignore
				New-Item -Force -Path "$OutputFilesListBasePath" -Name "$($Project.Name)\$($Configuration.Name)" -ItemType "directory" | out-null

				# foreach given target framework exists a directory
				foreach ($Target in Get-ChildItem -Path "$ConfigurationPath" -Directory -Force -ErrorAction SilentlyContinue)
				{
					# compute index file for each target framework
					$TargetDirectoryPath = "$ConfigurationPath\$($Target.Name)"
					$OutputFilesListPath = "$OutputFilesListBasePath\$($Project.Name)\$($Configuration.Name)\$($Target.Name).files.txt"
					Write-Host "=> $OutputFilesListPath"
					Push-Location "$TargetDirectoryPath"
					Get-ChildItem -Recurse -Force -Attributes !Directory | Resolve-Path -Relative | Out-File -Encoding utf8 "$OutputFilesListPath"
					Pop-Location
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