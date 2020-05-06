Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"

#-------------------------------------------------------------------------------------------------------------------------------------

# Properties
[string] $ToolName = "PreBuildWizard"
[string] $ToolDownloadUrl = "https://github.com/GriffinPlus/PreBuildWizard/releases/download/v2.0.0/PreBuildWizard-portable-v2.0.0.zip"
[string] $ToolVersionHash = "BE8D36C8552B6C35F90E6E6451035D584164ABAA831329A5479B7ED485D2623D"

#-------------------------------------------------------------------------------------------------------------------------------------

function PreBuildWizard
{
	Param
	(
		[Parameter()][string] $SolutionPath = $global:SolutionPath,
		[Parameter()][string] $PreBuildWizardRelativeSourcePath,
		[Parameter()][switch] $PauseOnError
	)

	Try
	{
		$ToolDirectory = DownloadBuildTool $ToolName $ToolDownloadUrl $ToolVersionHash
		$SolutionDir = Split-Path -Path "$SolutionPath"
		$BaseIntermediateOutputPath = "$SolutionDir\_build\.obj"
		$PreBuildWizardToolPath = "$ToolDirectory\PreBuildWizard.dll"
		if (!(Test-Path $PreBuildWizardToolPath -PathType Leaf))
		{
			Write-Host -ForegroundColor "Red" "The PreBuildWizard could not be found under '$PreBuildWizardToolPath'. Stopping further processing..."
			if ($PauseOnError) 
			{
				Read-Host "Press ANY key..."
			}
			exit(-1)
		}

		Write-Host -ForegroundColor "Green" "Running PreBuildWizard..."
		
		if ($PreBuildWizardRelativeSourcePath)
		{
			$PreBuildWizardAbsoluteSourcePath = [System.IO.Path]::GetFullPath((Join-Path $SolutionDir $PreBuildWizardRelativeSourcePath))
			if ($PreBuildWizardAbsoluteSourcePath.StartsWith($SolutionDir))
			{
				EnvRunExec ( "dotnet.exe", "$PreBuildWizardToolPath", "-b", "$BaseIntermediateOutputPath", "$PreBuildWizardAbsoluteSourcePath", "$ScriptDir" )
			}
			else
			{
				throw "Path for patching files is outside repository structure."
			}
		}
		else
		{
			EnvRunExec ( "dotnet.exe", "$PreBuildWizardToolPath", "-b", "$BaseIntermediateOutputPath", "$SolutionDir" )
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