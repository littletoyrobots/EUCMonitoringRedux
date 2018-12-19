Function Get-XdSessionInfo {
    <#   
.SYNOPSIS   
    Returns Stats of the XenDesktop Sessions
.DESCRIPTION 
    Returns Stats of the XenDesktop Sessions
.PARAMETER Broker 
    XenDesktop Broker to use for the checks

.NOTES
    Current Version:        1.0
    Creation Date:          29/03/2018
.CHANGE CONTROL
    Name                    Version         Date                Change Detail
    David Brett             1.0             29/03/2018          Function Creation
    Adam Yarborough         1.1             07/06/2018          Update to new object model
    Adam Yarborough         1.2             20/06/2018          Session Information
.EXAMPLE
    None Required
#>
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$Broker,
        [string]$SiteName,
        [string]$ZoneName,
        [string]$CatalogName,
        [string]$DeliveryGroupName,
        [int]$DurationLength = 600
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
    }

    Process { 
        $Results = @()
        
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting session details: $ZoneName / $CatalogName / $DeliveryGroupName"
        $Results = @()
        
        
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting session durations: $ZoneName / $CatalogName / $DeliveryGroupName"
        # Throw in try catch loop 
        try {          
            $params = @{
                AdminAddress     = $Broker;
                CatalogName      = $CatalogName;
                DesktopGroupName = $DeliveryGroupName;
                #SessionState     = "Active";
                Maxrecordcount   = 99999
            }
            $TotalSessions = (Get-BrokerSession @params).Count

            if ($TotalSessions -gt 0) {                        
                $params = @{
                    AdminAddress     = $Broker;
                    CatalogName      = $CatalogName;
                    DesktopGroupName = $DeliveryGroupName;
                    SessionState     = "Active";
                    Maxrecordcount   = 99999
                }
                $Sessions = Get-BrokerSession @params
                $TimeSpan = New-TimeSpan -Seconds (-1 * $DurationLength)
                $BrokeringDurationAvg = ($Sessions | `
                        Where-Object BrokeringTime -gt ((get-date) + $TimeSpan) | `
                        Select-Object -ExpandProperty BrokeringDuration | Measure-Object -Average).Average
                $BrokeringDurationMax = ($Sessions | `
                        Where-Object BrokeringTime -gt ((get-date) + $TimeSpan) | `
                        Select-Object -ExpandProperty BrokeringDuration | Measure-Object -Maximum).Maximum
                $EstablishmentDurationAvg = ($Sessions | `
                        Where-Object BrokeringTime -gt ((get-date) + $TimeSpan) | `
                        Select-Object -ExpandProperty EstablishmentDuration | Measure-Object -Average).Average
                $EstablishmentDurationMax = ($Sessions | `
                        Where-Object BrokeringTime -gt ((get-date) + $TimeSpan) | `
                        Select-Object -ExpandProperty EstablishmentDuration | Measure-Object -Maximum).Maximum

                # If one gets a value, all should.  
                if ($null -ne $BrokeringDurationAvg) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] BrokeringDurationAvg = $BrokeringDurationAvg, BrokeringDurationMax = $BrokeringDurationMax"
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] EstablishmentDurationAvg = $EstablishmentDurationAvg, EstablishmentDurationMax = $EstablishmentDurationMax"

                    $Results += [PSCustomObject]@{
                        Series                     = "XdSessionDuration"
                        'SiteName'                 = $SiteName   
                        'ZoneName'                 = $ZoneName
                        'CatalogName'              = $CatalogName
                        'DeliveryGroupName'        = $DeliveryGroupName
                        'BrokeringDurationAvg'     = $BrokeringDurationAvg
                        'BrokeringDurationMax'     = $BrokeringDurationMax
                        'EstablishmentDurationAvg' = $EstablishmentDurationAvg
                        'EstablishmentDurationMax' = $EstablishmentDurationMax
                    }
                }
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No new sessions"
                }  
            }
        }
        catch {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Problem getting session info"
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"
            $Results += [PSCustomObject]@{
                Series                     = "XdSessionDuration"
                'SiteName'                 = $SiteName   
                'ZoneName'                 = $ZoneName
                'CatalogName'              = $CatalogName
                'DeliveryGroupName'        = $DeliveryGroupName
                'BrokeringDurationAvg'     = -1
                'BrokeringDurationMax'     = -1
                'EstablishmentDurationAvg' = -1
                'EstablishmentDurationMax' = -1
            }
        }
        return $Results
    }

    End { 
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}