Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Import-Module "$ScriptDir\Helper.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

# Tools
[string]  $GitVersionToolPath = "$ScriptDir\bin\GitVersion\GitVersion.exe"

# -------------------------------------------------------------------------------------------------------------------------------------

function GitVersion
{
	Param
	(
		[Parameter()][switch] $PauseOnError
	)

	Try
	{
		Write-Host -ForegroundColor "Green" "Determining version from the git history..."
		Copy-Item "$ScriptDir\GitVersion.yml" -Destination "$ScriptDir\.."
		$WorkingDirectory = Get-Location
		Set-Location -Path "$ScriptDir\.."
		EnvRunExec ( "$GitVersionToolPath", "/output", "buildserver" )
		Set-Location -Path "$WorkingDirectory"
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