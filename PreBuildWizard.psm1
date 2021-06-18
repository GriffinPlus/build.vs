Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Configuration.psm1"
Import-Module "$ScriptDir\Helper.psm1"

#-------------------------------------------------------------------------------------------------------------------------------------

# Properties
[string] $ToolName = "PreBuildWizard"
[string] $ToolDownloadUrl = "https://github.com/GriffinPlus/PreBuildWizard/releases/download/v3.0.0/PreBuildWizard-portable-v3.0.0.zip"
[string] $ToolVersionHash = "F083E47E8563650D8E690002DD72AC31DAE71E80CF9D7477AC7F2F73BA3943E4"

#-------------------------------------------------------------------------------------------------------------------------------------

function PreBuildWizard
{
	Param
	(
		[Parameter()][string] $SolutionPath = $global:SolutionPath,
		[Parameter()][string] $PreBuildWizardRelativeSourcePath = "src",
		[Parameter()][switch] $SkipNuGetConsistencyCheck,
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
		
		$PreBuildWizardAbsoluteSourcePath = [System.IO.Path]::GetFullPath((Join-Path $SolutionDir $PreBuildWizardRelativeSourcePath))
		if ($PreBuildWizardAbsoluteSourcePath.StartsWith($SolutionDir))
		{
			if ($SkipNuGetConsistencyCheck)
			{
				EnvRunExec ( "dotnet.exe", "$PreBuildWizardToolPath", "$PreBuildWizardAbsoluteSourcePath", "$ScriptDir" )
			}
			else
			{
				EnvRunExec ( "dotnet.exe", "$PreBuildWizardToolPath", "-b", "$BaseIntermediateOutputPath", "$PreBuildWizardAbsoluteSourcePath", "$ScriptDir" )
			}
		}
		else
		{
			throw "Path for patching files is outside repository structure.  SourcePath: $PreBuildWizardAbsoluteSourcePath"
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