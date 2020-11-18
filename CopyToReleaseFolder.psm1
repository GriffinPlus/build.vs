Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

# Tools
[string] $7ZipToolPath = "$ScriptDir\bin\7zip\7z.exe"

# -------------------------------------------------------------------------------------------------------------------------------------

function CopyToReleaseFolder
{
	Param
	(
		[Parameter(mandatory=1)][string] $SourcePath,
		[Parameter()][string]            $DestinationPath = $global:ReleaseDirectory,
		[Parameter()][switch]            $PauseOnError
	)

	$ZipArchivePath = "$DestinationPath\$env:GitVersion_MajorMinorPatch$env:GitVersion_PreReleaseTagWithDash.zip"
	$SourcePathAbsolute = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SourcePath)

	Try
	{
		Write-Host -Foreground "Green" "Zip content of folder ($SourcePath) to archive ($ZipArchivePath)..."
		EnvRunExec ("$7ZipToolPath", "a", "$ZipArchivePath", "$SourcePathAbsolute\*")
	}
	Catch
	{
		# tell the caller it has all gone wrong
		echo $_.Exception|format-list -force
		if ($PauseOnError) {
			Read-Host "Press ANY key..."
		}
		exit(-1)
	}
}