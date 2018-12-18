Function Test-XdSessionInfo {
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
        [parameter]$SiteName,
        [parameter]$ZoneName,
        [parameter]$CatalogName,
        [parameter]$DeliveryGroupName
    )

    Begin { 
        $ctxsnap = Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue
        $ctxsnap = Get-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Citrix Broker Powershell Snapin Load Failed"
            Write-Error "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Cannot Load Citrix Broker Powershell SDK"
            Return 
        }
        else {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Citrix Broker Powershell SDK Snapin Loaded"
        }

        $ctxsnap = Add-PSSnapin Citrix.Configuration.Admin.* -ErrorAction SilentlyContinue
        $ctxsnap = Get-PSSnapin Citrix.Configuration.Admin.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] XenDesktop Powershell Snapin Load Failed"
            Write-Error "Cannot Load XenDesktop Powershell SDK"
            Return 
        }
        else {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] XenDesktop Powershell SDK Snapin Loaded"
        }
    }

    Process { 
        $Results = @()
        
        
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting session details: $ZoneName / $CatalogName / $DeliveryGroupName"
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

                $ActiveSessions = ($Sessions | Where-Object IdleDuration -lt 00:00:01).Count
                $IdleSessions = ($Sessions | Where-Object IdleDuration -gt 00:00:00).Count
                $params = @{
                    AdminAddress     = $Broker;
                    DesktopGroupName = $DeliveryGroupName;
                    SessionState     = "Disconnected";
                    Maxrecordcount   = 99999
                }
                $DisconnectedSessions = (Get-BrokerSession @params).Count
                # $OtherSessions = $TotalSessions - ($ActiveSessions + $IdleSessions + $DisconnectedSessions)
                        
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Total: $TotalSessions, Active: $ActiveSessions"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Idle: $IdleSessions, Disconnected: $DisconnectedSessions"
                # Add Session Totals to Results
                $Results += [PSCustomObject]@{
                    Series               = "XdSessionInfo"
                    Host                 = $Broker
                    SiteName             = $SiteName   
                    ZoneName             = $ZoneName
                    CatalogName          = $CatalogName
                    DeliveryGroupName    = $DeliveryGroupName
                    TotalSessions        = $TotalSessions
                    ActiveSessions       = $ActiveSessions
                    IdleSessions         = $IdleSessions
                    DisconnectedSessions = $DisconnectedSessions
                }

                $BrokeringDurationAvg = ($Sessions | `
                        Where-Object BrokeringTime -gt ((get-date) + (New-TimeSpan -Hours -1)) | `
                        Select-Object -ExpandProperty BrokeringDuration | Measure-Object -Average).Average
                $BrokeringDurationMax = ($Sessions | `
                        Where-Object BrokeringTime -gt ((get-date) + (New-TimeSpan -Hours -1)) | `
                        Select-Object -ExpandProperty BrokeringDuration | Measure-Object -Maximum).Maximum
                $EstablishmentDurationAvg = ($Sessions | `
                        Where-Object BrokeringTime -gt ((get-date) + (New-TimeSpan -Hours -1)) | `
                        Select-Object -ExpandProperty EstablishmentDuration | Measure-Object -Average).Average
                $EstablishmentDurationMax = ($Sessions | `
                        Where-Object BrokeringTime -gt ((get-date) + (New-TimeSpan -Hours -1)) | `
                        Select-Object -ExpandProperty EstablishmentDuration | Measure-Object -Maximum).Maximum
                    
                # If one gets a value, all should.  
                if ($null -ne $BrokeringDurationAvg) {
                    Write-Verbose "BrokeringDurationAvg     = $BrokeringDurationAvg"
                    Write-Verbose "BrokeringDurationMax     = $BrokeringDurationMax"
                    Write-Verbose "EstablishmentDurationAvg = $EstablishmentDurationAvg"
                    Write-Verbose "EstablishmentDurationMax = $EstablishmentDurationMax"

                    $Results += [PSCustomObject]@{
                        Series                     = "XdSessionInfo"
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
                   
            }
        

            return $Results
        }
        catch {
            
        }
    }

    End { }
}