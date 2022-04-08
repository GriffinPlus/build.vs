Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

function ConvertMarkdown2Html
{
    Param
    (
        [Parameter()][string] $InputFilePath,
        [Parameter()][string] $OutputFilePath,
        [Parameter()][string] $StyleSheetPath = "$ScriptDir\GithubStyle.css",
        [Parameter()][string] $DocumentTitle = "",
        [Parameter()][switch] $GenerateTableOfContents,
        [Parameter()][switch] $SkipIfNotInstalled,
        [Parameter()][switch] $PauseOnError
    )

    Try
    {
        Write-Host -ForegroundColor "Green" "Converting Markdown to HTML..."

        # check whether the conversion tool is installed
        if (!(Test-Path "$PandocPath" -PathType Leaf))
        {
            if ($SkipIfNotInstalled)
            {
                Write-Host -ForegroundColor "Yellow" "The converting tool 'Pandoc' is not installed. Skipping conversion..."
                return
            }
            else
            {
                Write-Host -ForegroundColor "Red" "The converting tool 'Pandoc' is not installed!"
                throw "The converting tool 'Pandoc' is not installed!"
            }
        }

        $InputFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$InputFilePath")
        $OutputFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$OutputFilePath")
        $StyleSheetPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$StyleSheetPath")

        # check whether the given parameters are valid

        # InputFilePath
        if ([string]::IsNullOrWhiteSpace($InputFilePath))
        {
            throw "The parameter 'InputFilePath' contains null, only whitespaces or is empty! Define a path to the markdown file to convert."
        }
        if (!(Test-Path "$InputFilePath" -PathType Leaf))
        {
            throw "The file for parameter 'InputFilePath' does not exists!"
        }
        if ([IO.Path]::GetExtension($InputFilePath) -ne ".md")
        {
            throw "The file given for parameter 'InputFilePath' is not a Markdown file!"
        }

        Write-Host "Conversion: Input file '$InputFilePath' is valid."

        # OutputFilePath
        if ([string]::IsNullOrWhiteSpace($OutputFilePath))
        {
            throw "The parameter 'OutputFilePath' contains null, only whitespaces or is empty! Define a path where to store the HTML file."
        }
        if ([IO.Path]::GetExtension($OutputFilePath) -ne ".html")
        {
            throw "The file given for parameter 'OutputFilePath' is not a HTML file!"
        }
        # create folder, if it does not exist, yet
        $OutputFileDir = Split-Path $OutputFilePath
		if (!(Test-Path $OutputFileDir -PathType Container)) {
			New-Item -Path $OutputFileDir -ItemType Directory -Force | Out-Null
		}

        Write-Host "Conversion: Output file '$OutputFilePath' is valid."

        $IsStyleSheetIncluded = $true
        # StyleSheetPath
        if ([string]::IsNullOrWhiteSpace($StyleSheetPath))
        {
            $IsStyleSheetIncluded = $false
            Write-Host -ForegroundColor "Yellow" "Conversion: Style sheet is not included."
        }
        if ($IsStyleSheetIncluded)
        {
            if (!(Test-Path "$StyleSheetPath" -PathType Leaf))
            {
                throw "The file for parameter 'StyleSheetPath' does not exists!"
            }
            if ([IO.Path]::GetExtension($StyleSheetPath) -ne ".css")
            {
                throw "The file given for parameter 'StyleSheetPath' is not a CSS file!"
            }
            Write-Host "Conversion: Style sheet '$StyleSheetPath' is valid."
        }



        # create command for pandoc.exe with given parameters
        $cmd = @($PandocPath, "-f", "gfm", "-t", "html5", "--self-contained")
        if ($GenerateTableOfContents)
        {
            $cmd += "--toc"
            Write-Host "Conversion: Generate table of contents."
        }
        if (![string]::IsNullOrWhiteSpace($DocumentTitle))
        {
            $cmd += "--metadata"
            $cmd += "title=""$DocumentTitle"""
            Write-Host "Conversion: Add title '$DocumentTitle' to document metadata."
        }
        if ($IsStyleSheetIncluded)
        {
            $cmd += "--css"
            $cmd += "$StyleSheetPath"
        }

        $cmd += "$InputFilePath"
        $cmd += "-o"
        $cmd += "$OutputFilePath"

        EnvRunExec ($cmd)
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