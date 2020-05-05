Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

# -------------------------------------------------------------------------------------------------------------------------------------

# global configuration (environment variables)
[string] $env:ENVRUN_DATABASE = "$ScriptDir\..\_build\EnvRun.db"

# Tools
[string]  $EnvRunToolPath = "$ScriptDir\bin\envrun.exe"

# -------------------------------------------------------------------------------------------------------------------------------------

# ###############################################################################################################################
# Helper functions
# ###############################################################################################################################

$global:EnvRunExecLastError = 0

function Exec
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=1)][scriptblock] $cmd,
		[Parameter()][string]                            $errorMessage = ("Error executing command {0}" -f $cmd),
		[Parameter()][switch]                            $continueOnError
	)
	& $cmd
	if (!$continueOnError -And $lastexitcode -ne 0) {
		throw ("Exec: " + $errorMessage)
	}

	$global:EnvRunExecLastError = $lastexitcode
}

function EnvRunExec
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=1)][string[]] $cmd,
		[Parameter()][switch]                         $continueOnError
	)
	$cmd = '''' + ($cmd -join ''', ''') + ''''
	$scriptCode = "& ""$EnvRunToolPath"" ($cmd)"
	$script = [scriptblock]::Create($scriptCode)
	# echo "SCRIPT: $script"
	if ($continueOnError) {
		Exec $script -continueOnError
	} else {
		Exec $script
	}

	# read environment variables captured by envrun to make them available in powershell
	LoadCapturedEnvRunVariables
}

function LoadCapturedEnvRunVariables
{
	# read captured environment variables and make them available in powershell
	# (otherwise only new processes within envrun can consume them)
	$regex = "^(?<name>\w+) = '(?<value>.*)'$"
	foreach($line in Get-Content "$env:ENVRUN_DATABASE") {
		if($line -match $regex){
			[Environment]::SetEnvironmentVariable($Matches.name, $Matches.value, "Process")
		}
	}
}

function ExecBlock
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=1)][scriptblock] $cmd,
		[Parameter()][string]                            $errorMessage = ("Error executing command {0}" -f $cmd)
	)

	Try
	{
		& $cmd
	}
	Catch [Exception]
	{
		echo $_.Exception|format-list -force
		exit(-1)
	}
}

# -------------------------------------------------------------------------------------------------------------------------------------

# load envrun.db, if available to make captured environment variables available
if (Test-Path "$env:ENVRUN_DATABASE")
{
	LoadCapturedEnvRunVariables
}

# -------------------------------------------------------------------------------------------------------------------------------------
