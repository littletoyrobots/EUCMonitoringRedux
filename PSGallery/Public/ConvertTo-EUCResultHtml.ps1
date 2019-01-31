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

        if ( $RefreshDuration -ne 0 ) {
            '<meta http-equiv="refresh" content="' + $RefreshDuration + '" >' | Out-File $HTMLOutputFileFull -Append
        }

        #################
        # Title Section #
        #################
        $Title = "EUCMonitoring"
        $LogoFile = "EUCMonitoring.png"
        "<table border='0' width='100%'' cellspacing='0' cellpadding='0'>" | Out-File $HTMLOutputFileFull -Append
        "<tr>" | Out-File $HTMLOutputFileFull -Append
        "<td class='title-info'>" | Out-File $HTMLOutputFileFull -Append
        $title | Out-File $HTMLOutputFileFull -Append
        "</td>" | Out-File $HTMLOutputFileFull -Append
        "<td width='40%' align=right valign=top>" | Out-File $HTMLOutputFileFull -Append
        "<img src='$LogoFile'>" | Out-File $HTMLOutputFileFull -Append
        "</td>" | Out-File $HTMLOutputFileFull -Append
        "</tr>" | Out-File $HTMLOutputFileFull -Append
        "</table>" | Out-File $HTMLOutputFileFull -Append

        ##########################
        # Infrastructure Section #
        ##########################

        # Write Infrastructure Table Header
        "<table border='0' width='100%'' cellspacing='0' cellpadding='0'>" | Out-File $HTMLOutputFileFull -Append
        "<tr>" | Out-File $HTMLOutputFileFull -Append

        $Height = 50
        $Width = 50
        $UpColor = "rgba(221, 70, 70, 0.9)"
        $DownColor = "rgba(67, 137, 203, 0.95)"

        $InfraData = ""

        # List of Series you don't want in the infrastructure section
        $NonInfraSeriesNames = @(
            "XdWorker", "XdWorkerHealth", 
            "RdsWorker", "RdsWorkerHealth", 
            "XdLicense", "RdsLicense", # These are the license numbers, not services
            "CitrixADClbvserver", "CitrixADCcsvserver", "CitrixADCgatewayusers" # ADC Stats, not up/down
        )

        $InfraSeriesResults = $Results | Where-Object { $_.Series -notcontains $NonInfraSeriesNames } 
        $InfraResultNames = $InfraSeriesResults | Select-Object -ExpandProperty Series -Unique
        
        $TotalInf = $InfraResultNames.Count
        if ($TotalInf -gt 0) { 
            # Bug Fix #57 -> Alex Spicola
            if ($TotalInf -gt 1) { $TotalInf-- } else { $TotalInf = 1 }
            $ColumnPercent = 100 / [int]$totalinf
        }

        foreach ($Name in $InfraSeriesNames) {

            $Up = 0
            $Down = 0

            $SeriesResults = $InfraSeriesResults | Where-Object { $_.Series -eq $Name }

            $SeriesResults.PSObject.Properties | ForEach-Object {
                if ($null -eq $_.Value) { }
                elseif ($_.Name -eq "Series") {  }
                # If its a string, we'll treat it as a tag
                elseif ($_.Value -is [string]) { }
                else {
                    if ( $_.Value -eq 1 ) { $Up++ } 
                    elseif ( $_.Value -eq 0 ) { $Down++ }
                    else { } # Discard other values. 
                }
            }

            # Renames
            switch ($Name) {
                "Xenserver" { $SeriesName = "Citrix HV"; break }
                "Storefront" { $SeriesName = "StoreFront"; break }
                "XdLicensing" { $SeriesName = "Citrix Licensing"; break }
                "RdsLicensing" { $SeriesName = "RDS Licensing"; break }
                "NetScaler" { $SeriesName = "Citrix ADC"; break }
                default { $SeriesName = $Name; break }
            }

            $Params = @{
                Height          = $Height;
                Width           = $Width;
                DonutGoodColour = $UpColor;
                DonutBadColour  = $DownColor;
                DonutStroke     = $DonutStroke;
                SeriesName      = $SeriesName;
                SeriesUpCount   = $Up;
                SeriesDownCount = $Down;
                Worker          = $false;
                SiteName        = $null
            }
            Get-DonutHTML @Params | Out-File $HTMLOutputFileFull -Append

        }


        "</tr>" | Out-File $HTMLOutputFileFull -Append
        "</table>" | Out-File $HTMLOutputFileFull -Append

        ##################
        # Worker Objects #
        ##################



        # Last Run Details
        "<table>" | Out-File $HTMLOutputFileFull -Append
        "<tr>" | Out-File $HTMLOutputFileFull -Append
        "<div class='info-text'>" | Out-File $HTMLOutputFileFull -Append
        $LastRun = Get-Date
        "Last Run Date: $LastRun" | Out-File $HTMLOutputFileFull -Append
        "</div>" | Out-File $HTMLOutputFileFull -Append
        "</tr>" | Out-File $HTMLOutputFileFull -Append

        # Write the Worker Table Footer
        "</table>" | Out-File $HTMLOutputFileFull -Append
    
        # Write HTML Footer Information
        "</body>" | Out-File $HTMLOutputFileFull -Append
        "</html>" | Out-File $HTMLOutputFileFull -Append
    }

    End { 
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}