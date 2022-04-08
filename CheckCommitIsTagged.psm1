Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

function CheckCommitIsTagged
{
	Param
	(
		[Parameter()][string] $CommitHash,
		[Parameter()][switch] $PauseOnError
	)

	Try
	{
		# determine the current commit, if the commit hash is not specified explicitly
		if ( $CommitHash.Length -eq 0 )
		{
			$cmd = @($global:GitPath)
			$cmd += 'show'
			$cmd += '-s'
			$cmd += '--format="%H"'
			$CommitHash = (EnvRunExec $cmd) | Out-String
			$CommitHash = $CommitHash.Trim()
		}

		# the following command returns with 0, if the specified commit is tagged,
		# otherwise a non-zero error code is returned
		$cmd = @($global:GitPath)
		$cmd += "describe"
		$cmd += "--tags"
		$cmd += "--exact-match"
		$cmd += "$CommitHash"
		EnvRunExec $cmd -continueOnError
		if ($global:EnvRunExecLastError -ne 0)
		{
			Write-Host -ForegroundColor "Red" "The specified commit ($CommitHash) is not tagged. Aborting!"
			if ($PauseOnError) {
				Read-Host "Press ANY key..."
			}
			exit(-1)
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