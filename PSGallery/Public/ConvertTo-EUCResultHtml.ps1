function New-EUCHtmlReport {
    [cmdletbinding(ConfirmImpact = "High")]
    Param (
        [Object[]]$Results,
        [string]$FilePath,
        [string]$ErrorLog, 
        [int]$RefreshDuration = 300
    )

    Begin { 
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
    }
    Process { 
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)]"
        
        # If outfile exists - delete it
        if (test-path $HTMLOutputFileFull) {
            Remove-Item $HTMLOutputFileFull
        }


        # Write HTML Header Information
        "<html>" | Out-File $HTMLOutputFileFull -Append
        "<head>" | Out-File $HTMLOutputFileFull -Append

        # Write CSS Style
        "<style>" | Out-File $HTMLOutputFileFull -Append
        $CSSData = Get-Content $CSSFile
        $CSSData | Out-File $HTMLOutputFileFull -Append
        "</style>" | Out-File $HTMLOutputFileFull -Append

        '<meta http-equiv="refresh" content="' + $RefreshDuration + '" >' | Out-File $HTMLOutputFileFull -Append
    }

    End { 
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}