Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"

#-------------------------------------------------------------------------------------------------------------------------------------

# Tools
[string] $7ZipToolPath = "$ScriptDir\bin\7zip\7z.exe"

# Properties
[string] $LicenseCollectorDownloadUrl = "https://github.com/GriffinPlus/LicenseCollector/releases/download/v1.0.0-rc5/LicenseCollector-portable-v1.0.0-rc.5.zip"
[string] $ToolVersionHash = "04C0EC46B59CF3F0240A30EB06340705DE7D66C0B037E204C1D5A71FFE39DA38"
[string] $ToolName = "LicenseCollector"

[string] $TemporaryFolder = [System.IO.Path]::GetTempPath()
[string] $ToolArchive = "$TemporaryFolder\build-tools\$ToolVersionHash.zip"
[string] $ToolDirectory = "$TemporaryFolder\build-tools\$ToolVersionHash"

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
        Write-Host -ForegroundColor "Green" "Check if $ToolName in version '$ToolVersionHash' already exists..."

        if (!(Test-Path $ToolArchive -PathType Leaf))
        {
            Write-Host -ForegroundColor "Green" "$ToolName is missing and is now downloaded from '$LicenseCollectorDownloadUrl'..."

			New-Item -Itemtype directory -Force $(Split-Path $ToolArchive) | Out-Null

            [Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
            $wc = [System.Net.WebClient]::new()
            $wc.DownloadFile($LicenseCollectorDownloadUrl, $ToolArchive)
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

        # extract zip archive and store path to the license collector executable
        Write-Host -ForegroundColor "Green" "Extracting zip archive of $ToolName..."
        EnvRunExec ("$7ZipToolPath", "x", "$ToolArchive", "-o$ToolDirectory", "-y")

        $LicenseCollectorToolPath = "$ToolDirectory\LicenseCollector.exe"
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
        
        $cmd = @($LicenseCollectorToolPath)
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