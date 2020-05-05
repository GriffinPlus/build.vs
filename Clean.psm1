Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

function Clean
{
	Param
	(
		[Parameter()][string[]] $OutputPaths,
		[Parameter()][switch]   $PauseOnError
	)

	Try
	{
		Write-Host -Foreground "Green" "Removing old build output..."

		foreach($path in $OutputPaths)
        {
            if (Test-Path $path -PathType Container)
            {
                Write-Host -ForegroundColor "Green" "Removing everything under '$path'..."
                Remove-Item "$path" -Recurse -ErrorAction Ignore
            }
            else
            {
                Write-Host -ForegroundColor "Green" "Specified '$path' is not a folder or not existing"
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