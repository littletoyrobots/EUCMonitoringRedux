Function Test-XdWorkload {
    [cmdletbinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Broker, 
        [string]$Workload,
        #        [switch]$SessionInfo, 
        #        [switch]$SessionDuration,
        #        [int]$DurationLength = 600, 
        
        [switch]$WorkerHealth,
        [int]$BootThreshold = 7,
        [int]$HighLoad = 8000,

        [switch]$All
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Loading Citrix Broker Powershell Snapin"
        $ctxsnap = Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue
        $ctxsnap = Get-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Broker Snapin Load Failed"
            throw "Cannot Load XenDesktop Powershell SDK"
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Broker Snapin Loaded"
        }

        $ctxsnap = Add-PSSnapin Citrix.Configuration.Admin.* -ErrorAction SilentlyContinue
        $ctxsnap = Get-PSSnapin Citrix.Configuration.Admin.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Configuration Snapin Load Failed"
            Write-Error "Cannot Load XenDesktop Powershell SDK"
            Return 
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Configuration Snapin Loaded"
        }
    } #BEGIN
		
    Process { 
        $Results = @()

        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Querying Delivery Groups for type $Workload"
        $SiteName = (Get-BrokerSite -AdminAddress $Broker).Name
        $ZoneNames = (Get-ConfigZone -AdminAddress $Broker).Name

        if ($Workload -match "Server") {
            $DeliveryGroups = Get-BrokerDesktopGroup -AdminAddress $Broker | Where-Object {$_.SessionSupport -eq "MultiSession"} 
        }
        elseif ($Workload -match "Desktop") {
            $DeliveryGroups = Get-BrokerDesktopGroup -AdminAddress $Broker | Where-Object {$_.SessionSupport -eq "SessionSession"}
        }
        else {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure Unknown workload type" 
            throw "Unable to determine the workload type."
        }
        try { 
            foreach ($ZoneName in $ZoneNames) {
                $CatalogNames = (Get-BrokerCatalog -AdminAddress $Broker -ZoneName $ZoneName).Name
                foreach ($CatalogName in $CatalogNames) {
                    foreach ($DeliveryGroupName in $DeliveryGroups.Name) {
                        $Params = @{
                            AdminAddress     = $Broker;
                            ZoneName         = $ZoneName;
                            CatalogName      = $CatalogName;
                            DesktopGroupName = $DeliveryGroupName;
                            MaxRecordCount   = 99999
                        }
                        $Machines = Get-BrokerMachine @Params

                        if ($null -ne $Machines) {
                            $MachineCount = $Machines.Count

                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Worker Details: $ZoneName / $CatalogName / $DeliveryGroupName - Count: $MachineCount"

                            $Registered = ($Machines | Where-Object {($_.RegistrationState -eq "Registered" -and $_.PowerState -ne "Off")}).Count
                            $Unregistered = ($Machines | Where-Object {($_.RegistrationState -eq "Unregistered" -and $_.PowerState -ne "Off")}).Count                       
                            $InMaintenance = ($Machines | Where-Object {(($_.InMaintenanceMode -eq $true) -and ($_.PowerState -ne "Off"))}).Count
                            $FaultState = ($Machines | Where-Object {($_.FaultState -ne "None")}).Count
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Registered: $Registered, Unregistered: $Unregistered"
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] InMaintenance: $InMaintenance, FaultState: $FaultState"

                            $PowerOn = ($Machines | Where-Object {($_.PowerState -eq "On")}).Count
                            $PowerOff = ($Machines | Where-Object {($_.PowerState -eq "Off")}).Count
                            $PowerOther = ($Machines | Where-Object {($_.PowerState -ne "On") -and ($_.PowerState -ne "Off")}).Count
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] PowerOn: $PowerOn, PowerOff: $PowerOff, PowerOther: $PowerOther"

                            $LoadIndexAvg = ($Machines.LoadIndex | Measure-Object -Average).Average
                            $LoadIndexMax = ($Machines.LoadIndex | Measure-Object -Maximum).Maximum
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] LoadIndexAvg: $LoadIndexAvg, LoadIndexMax: $LoadIndexMax"

                            $params = @{
                                AdminAddress     = $Broker;
                                CatalogName      = $CatalogName;
                                DesktopGroupName = $DeliveryGroupName;
                                #SessionState     = "Active";
                                Maxrecordcount   = 99999
                            }
                            $TotalSessions = (Get-BrokerSession @params).Count
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

                            $Results += [PSCustomObject]@{
                                Series               = "XdWorker"
                                Type                 = $Workload
                                Host                 = $Broker
                                SiteName             = $SiteName
                                ZoneName             = $ZoneName
                                CatalogName          = $CatalogName
                                DeliveryGroupName    = $DeliveryGroupName
                                MachineCount         = $MachineCount
                                Registered           = $Registered
                                Unregistered         = $Unregistered
                                PowerOn              = $PowerOn
                                PowerOff             = $PowerOff
                                PowerOther           = $PowerOther
                                InMaintenence        = $InMaintenance
                                LoadIndexAvg         = $LoadIndexAvg
                                LoadIndexMax         = $LoadIndexMax
                                TotalSessions        = $TotalSessions
                                ActiveSessions       = $ActiveSessions
                                IdleSessions         = $IdleSessions
                                DisconnectedSessions = $DisconnectedSessions    
                            }
                                
                            if ($WorkerHealth -or $All) {
                                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Fetching worker health count"
                                $Params = @{
                                    Broker            = $Broker;
                                    Workload          = $Workload;
                                    SiteName          = $SiteName;
                                    ZoneName          = $ZoneName;
                                    CatalogName       = $CatalogName;
                                    DeliveryGroupName = $DeliveryGroupName;
                                    Machines          = $Machines;
                                    BootThreshold     = $BootThreshold;
                                    HighLoad          = $HighLoad
                                }
                                $Results += Get-XdWorkerHealth @Params
                                #Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Not fully implemented"
                            }


                            if ($SessionInfo -or $All) {
                                <#
                                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Fetching session info"
                                $Params = @{
                                    Broker            = $Broker;
                                    SiteName          = $SiteName;
                                    ZoneName          = $ZoneName;
                                    CatalogName       = $CatalogName;
                                    DeliveryGroupName = $DeliveryGroupName;
                                    #    Machines         = $Machines
                                }
                                $Results += Get-XdSessionInfo @Params
                                #>
                                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] SessionInfo not fully implemented"
                                
                            }

                        
                        }
                    }
                }
            }
        }
        catch {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Error Occured"
            Write-Warning "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"
            $Results += [PSCustomObject]@{
                Series               = "XdWorker"
                Type                 = $Workload
                Host                 = $Broker
                SiteName             = $SiteName
                ZoneName             = $ZoneName
                CatalogName          = $CatalogName
                DeliveryGroupName    = $DeliveryGroupName
                MachineCount         = -1
                Registered           = -1
                Unregistered         = -1
                PowerOn              = -1
                PowerOff             = -1
                PowerOther           = -1
                InMaintenence        = -1
                LoadIndexAvg         = -1
                LoadIndexMax         = -1
                TotalSessions        = -1
                ActiveSessions       = -1
                IdleSessions         = -1
                DisconnectedSessions = -1    
            }
        }

        if ($Results.Count -gt 0) {
            return $Results
        }
        else {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No results to return"
        }
    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}