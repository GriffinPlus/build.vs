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


function DownloadBuildTool_Internal
{
	Param
	(
		[Parameter()][string] $ToolName,
		[Parameter()][string] $ToolDownloadUrl,
		[Parameter()][string] $ToolVersionHash
	)

	$7ZipToolPath = "$ScriptDir\bin\7zip\7z.exe"
	$TemporaryDirectory = [System.IO.Path]::GetTempPath()
	$ToolArchive = "$TemporaryDirectory\build-tools\$ToolVersionHash.zip"
	$ToolDirectory = "$TemporaryDirectory\build-tools\$ToolVersionHash"

	Write-Host -ForegroundColor "Green" "Check if $ToolName in version '$ToolVersionHash' already exists..."

	if (!(Test-Path $ToolDirectory -PathType Container))
	{
		Write-Host -ForegroundColor "Green" "$ToolName is missing and is now downloaded from '$ToolDownloadUrl'..."

		$TempFile = [System.IO.Path]::GetTempFileName()
		Try
		{
			New-Item -Itemtype directory -Force $(Split-Path $ToolArchive) | Out-Null
			[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
			$wc = [System.Net.WebClient]::new()
			$wc.DownloadFile($ToolDownloadUrl, $TempFile)
			$wc.Dispose()

			# check hash
			Write-Host -ForegroundColor "Green" "Checking hash of '$ToolArchive'..."
			$FileHash = $(Get-FileHash -Algorithm SHA256 $TempFile).Hash
			Write-Host -ForegroundColor "Green" "Hash is '$FileHash'."
			
			# interrupt processing if hash values do not match
			if ($FileHash -ne $ToolVersionHash)
			{
				Write-Host -ForegroundColor "Red" "Hash of downloaded '$ToolArchive' does not match. Stopping further processing..."
				throw "Processing aborted. Please see log for further details..."
			}

			Try
			{
				# extract zip archive and store path to the executable
				Write-Host -ForegroundColor "Green" "Extracting zip archive of $ToolName..."
				EnvRunExec ("$7ZipToolPath", "x", "$TempFile", "-o$ToolDirectory", "-y")
				Write-Host -ForegroundColor "Green" "Extracting zip archive succeeded."
			}
			Catch
			{
				Remove-Item -Recurse $ToolDirectory
				throw
			}
		}
		Finally
		{
			Remove-Item -Force $TempFile
		}
	}
	
	Write-Output ""  # ensures that DownloadBuildTool() works with its [-1]
	Write-Output "$ToolDirectory"
}

function DownloadBuildTool
{
	Param
	(
		[Parameter()][string] $ToolName,
		[Parameter()][string] $ToolDownloadUrl,
		[Parameter()][string] $ToolVersionHash
	)
	
	$(DownloadBuildTool_Internal $ToolName $ToolDownloadUrl $ToolVersionHash)[-1]
}