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
		[Parameter()][switch]   $PauseOnError
	)

	Try
	{
		$SolutionDirectoryPath = Split-Path -Path "$SolutionPath"
		$SolutionName = (Get-Item "$SolutionPath").BaseName

		foreach ($configuration in $MsbuildConfigurations)
		{
			foreach ($platform in $MsbuildPlatforms)
			{
				Write-Host -ForegroundColor "Green" "Writing list of files in output directory for platform '$platform' in configuration '$configuration'..."
				$BuildDirectoryPath = "$SolutionDirectoryPath\_build\$SolutionName.$platform.$configuration"
				$OutputFilesListPath = "$SolutionDirectoryPath\$SolutionName.$platform.$configuration.files.txt"
				Push-Location "$BuildDirectoryPath"
				Get-ChildItem -Recurse -Force -Attributes !Directory | Resolve-Path -Relative | Out-File -Encoding utf8 "$OutputFilesListPath"
				Pop-Location
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