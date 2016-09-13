<#
	.SYNOPSIS
		Outputs the contents of a file as a hex dump.
	.DESCRIPTION
		ToDo
	.PARAMETER Path
		Path to the file, which should be formatted as hex dump.
#>
function Merge-XCF([parameter(Position=0,Mandatory=$TRUE)][String] $FilesFile, [parameter(Position=1,Mandatory=$TRUE)][String] $XCFFile)
	{	if ( -not (Test-Path -LiteralPath $FilesFile) )
			{	Write-Error "Path to *.files file '$FilesFile' not found." -Category ObjectNotFound
				exit
			}
#        if ( -not (Test-Path -LiteralPath $XCFFile) )
#			{	Write-Error "Path to *.files file '$XCFFile' not found." -Category ObjectNotFound
#				exit
#			}

        $XCFRootPath = "D:\git\PoC-Examples\xcf"
        $OutFileContent = ""

        $FilesContent = Get-Content -Path $FilesFile
        foreach ($FilesLine in $FilesContent)
		    {	if ($FilesLine -and (-not $FilesLine.StartsWith('#')))
                    {
                        $XCFFilePath = $XCFRootPath + "\" + $FilesLine
                        Write-Host ("Line: " + $XCFFilePath) -ForegroundColor Yellow

                        $XCFContent = Get-Content -Path $XCFFilePath
                        foreach ($XCFLine in $XCFContent)
                            {
                                Write-Host ("  " + $XCFLine)
                                $OutFileContent += $XCFLine + "`n"
                            }
                    }
            }

        $OutFileContent | Out-File -FilePath $XCFFile
    }
