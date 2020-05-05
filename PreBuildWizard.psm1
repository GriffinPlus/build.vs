Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"

#-------------------------------------------------------------------------------------------------------------------------------------

# Tools
[string] $7ZipToolPath = "$ScriptDir\bin\7zip\7z.exe"

# Properties
[string] $PreBuildWizardDownloadUrl = "https://github.com/GriffinPlus/PreBuildWizard/releases/download/v2.0.0/PreBuildWizard-v2.0.0.zip"
[string] $ToolVersionHash = "88039C1B5E18ED32E1DB61E3E9D04353C15F080E93B274F18C0F3993F98EAB55"
[string] $ToolName = "PreBuildWizard"

[string] $TemporaryFolder = [System.IO.Path]::GetTempPath()
[string] $ToolArchive = "$TemporaryFolder\build-tools\$ToolVersionHash.zip"
[string] $ToolDirectory = "$TemporaryFolder\build-tools\$ToolVersionHash"

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
        Write-Host -ForegroundColor "Green" "Check if $ToolName in version '$ToolVersionHash' already exists..."

        if (!(Test-Path $ToolArchive -PathType Leaf))
        {
            Write-Host -ForegroundColor "Green" "$ToolName is missing and is now downloaded from '$PreBuildWizardDownloadUrl'..."

			New-Item -Itemtype directory -Force $(Split-Path $ToolArchive) | Out-Null

            [Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
            $wc = [System.Net.WebClient]::new()
            $wc.DownloadFile($PreBuildWizardDownloadUrl, $ToolArchive)
            $wc.Dispose()
        }
        
        Write-Host -ForegroundColor "Green" "Checking hash of '$ToolArchive'..."
        $FileHash = $(Get-FileHash -Algorithm SHA256 $ToolArchive).Hash
		Write-Host -ForegroundColor "Green" "Hash is '$FileHash'."

        # interrupt processing if hash values do not match
        if ($FileHash -ne $ToolVersionHash)
        {
            Write-Host -ForegroundColor "Red" "Hash of downloaded '$ToolArchive' does not match. Stopping further processing..."
			
            if ($PauseOnError) 
            {
                Read-Host "Press ANY key..."
            }
            exit(-1)
        }

        # extract zip archive and store path to the executable
        Write-Host -ForegroundColor "Green" "Extracting zip archive of $ToolName..."
        EnvRunExec ("$7ZipToolPath", "x", "$ToolArchive", "-o$ToolDirectory", "-y")

		$SolutionDir = Split-Path -Path "$SolutionPath"
		$BaseIntermediateOutputPath = "$SolutionDir\_build\.obj"
        $PreBuildWizardToolPath = "$ToolDirectory\portable\PreBuildWizard.exe"
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