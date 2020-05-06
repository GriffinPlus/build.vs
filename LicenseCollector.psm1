Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"

#-------------------------------------------------------------------------------------------------------------------------------------

# Properties
[string] $ToolName = "LicenseCollector"
[string] $ToolDownloadUrl = "https://github.com/GriffinPlus/LicenseCollector/releases/download/v1.0.0/LicenseCollector-portable-v1.0.0.zip"
[string] $ToolVersionHash = "0CBAD527557AFE4FE093156267D69C6920CA8BA1950F66E811BF196CECEBBF54"

#-------------------------------------------------------------------------------------------------------------------------------------

function LicenseCollector
{
	Param
	(
		[Parameter()][string] $SolutionPath = $global:SolutionPath,
		[Parameter()][string] $Configuration,
		[Parameter()][string] $Platform,
		[Parameter()][string] $SearchPattern = "*.License",
		[Parameter()][string] $TemplatePath = "",
		[Parameter()][string] $OutputPath,
		[Parameter()][switch] $IsVerbose,
		[Parameter()][switch] $PauseOnError
	)

	Try
	{
		$ToolDirectory = DownloadBuildTool $ToolName $ToolDownloadUrl $ToolVersionHash
		$LicenseCollectorToolPath = "$ToolDirectory\LicenseCollector.dll"
		if (!(Test-Path $LicenseCollectorToolPath -PathType Leaf))
		{
			Write-Host -ForegroundColor "Red" "The LicenseCollector could not be found under '$LicenseCollectorToolPath'. Stopping further processing..."
			if ($PauseOnError) 
			{
				Read-Host "Press ANY key..."
			}
			exit(-1)
		}

		Write-Host -ForegroundColor "Green" "Collecting licenses for ($Configuration|$Platform) build..."
		
		$cmd = @("dotnet.exe")
		$cmd += $LicenseCollectorToolPath
		if ($IsVerbose)
		{
			$cmd += "-v"
		}
		$cmd += "-s"
		$cmd += "$SolutionPath"
		$cmd += "-c"
		$cmd += "$Configuration"
		$cmd += "-p"
		$cmd += "$Platform"
		$cmd += "--searchPattern"
		$cmd += "$SearchPattern"
		$cmd += "--licenseTemplatePath"
		$cmd += "$TemplatePath"
		$cmd += "$OutputPath"
		
		Write-Host "Cmd: $cmd"

		EnvRunExec $cmd
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