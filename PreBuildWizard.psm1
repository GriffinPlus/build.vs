Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"

#-------------------------------------------------------------------------------------------------------------------------------------

# Properties
[string] $ToolName = "PreBuildWizard"
[string] $ToolDownloadUrl = "https://github.com/GriffinPlus/PreBuildWizard/releases/download/v2.0.1/PreBuildWizard-portable-v2.0.0.zip"
[string] $ToolVersionHash = "88039C1B5E18ED32E1DB61E3E9D04353C15F080E93B274F18C0F3993F98EAB55"

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
		$PreBuildWizardToolPath = "$ToolDirectory\PreBuildWizard.exe"
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
				EnvRunExec ( "$PreBuildWizardToolPath", "-b", "$BaseIntermediateOutputPath", "$PreBuildWizardAbsoluteSourcePath", "$ScriptDir" )
			}
			else
			{
				throw "Path for patching files is outside repository structure."
			}
		}
		else
		{
			EnvRunExec ( "$PreBuildWizardToolPath", "-b", "$BaseIntermediateOutputPath", "$SolutionDir" )
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