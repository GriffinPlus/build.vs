Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

function CopyFilesFromListToFolder
{
	Param
	(
		[Parameter(Mandatory=$true)][string]   $FileListPath,
		[Parameter(Mandatory=$true)][string]   $FromDirectoryPath,
		[Parameter(Mandatory=$true)][string]   $ToDirectoryPath,
		[Parameter()][string]                  $ExcludeWildCardPattern,
		[Parameter()][switch]                  $PauseOnError
	)

	$FileListPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$FileListPath")
	$FromDirectoryPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$FromDirectoryPath")
	$ToDirectoryPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$ToDirectoryPath")

	Try
	{
		Write-Host -Foreground "Green" "-----------------------------------------------------------------------------------------------------------------------"
		Write-Host -Foreground "Green" "Copying files"
		Write-Host -Foreground "Green" "  From: $FromDirectoryPath"
		Write-Host -Foreground "Green" "  To:   $ToDirectoryPath"
		Write-Host -Foreground "Green" "-----------------------------------------------------------------------------------------------------------------------"

		foreach($relPath in Get-Content "$FileListPath")
		{
			if ($ExcludeWildCardPattern -and ($relPath -like $ExcludeWildCardPattern))
			{
				Write-Host "  SKIPPED: $relPath"
				continue
			}

			$sourceFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$FromDirectoryPath\$relPath")
			$targetFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$ToDirectoryPath\$relPath")
			$targetfolder = Split-Path $targetFilePath -Parent

			# create folder, if it does not exist, yet
			if (!(Test-Path $targetfolder -PathType Container)) {
				New-Item -Path $targetfolder -ItemType Directory -Force | Out-Null
			}

			# copy file
			Write-Host "COPIED:    $relPath"
			Copy-Item -Path "$sourceFilePath" -Destination "$targetFilePath"
		}

		Write-Host -Foreground "Green" "-----------------------------------------------------------------------------------------------------------------------"
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