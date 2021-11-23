Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"
[String]$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Import-Module "$ScriptDir\Helper.psm1"
Import-Module "$ScriptDir\Configuration.psm1"

# -------------------------------------------------------------------------------------------------------------------------------------

function CombineOutputBinaries
{
	Param
	(
		[Parameter()][string]   $SolutionPath = $global:SolutionPath,
		[Parameter()][switch]   $PauseOnError
	)

	Try
	{
		$SolutionDirectoryPath = Split-Path -Path "$SolutionPath"
		$OutputPath = "$SolutionDirectoryPath\_build\.out"
		$OutputBinariesBasePath = "$SolutionDirectoryPath\_build\.combined"

		# clear old combined output folder if it exists
		Remove-Item -Recurse -Path "$OutputBinariesBasePath" -ErrorAction Ignore

		# consider all projects under '_build'
		Write-Host -ForegroundColor "Green" "Combine output binaries into base path '$OutputBinariesBasePath' for all projects..."

		foreach ($Project in Get-ChildItem -Path "$OutputPath" -Directory -Force -ErrorAction SilentlyContinue)
		{
			Push-Location "$OutputPath\$($Project.Name)"

			foreach ($BinaryPath in Get-ChildItem -Recurse -Force -Attributes !Directory | Resolve-Path -Relative)
			{
				$OutputBinaryPath = [IO.Path]::GetFullPath([IO.Path]::Combine($OutputBinariesBasePath, $BinaryPath))

				if (Test-Path "$OutputBinaryPath" -PathType Leaf)
				{
					# binary exist --> compare if existing binary is the same
					if ((Get-FileHash $BinaryPath).Hash -ne (Get-FileHash $OutputBinaryPath).Hash)
					{
						# files are not the same --> throw exception
						throw "Found binary incompatibility for '$BinaryPath' in project '$($Project.Name)'..."
					}
					Write-Host "EXISTS:    Project: $($Project.Name), File: $BinaryPath"
				}
				else
				{
					# binary does not exist --> copy and continue with next one
					$OutputDirectory = [IO.Path]::GetDirectoryName("$OutputBinaryPath")
					if (!(Test-Path "$OutputDirectory" -PathType Container))
					{
						New-Item -Force -Path "$OutputDirectory" -ItemType "directory" | out-null
					}

					Copy-Item -Path "$BinaryPath" -Destination "$OutputBinaryPath"
					Write-Host "COPIED:    Project: $($Project.Name), File: $BinaryPath"
				}
			}

			Pop-Location
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