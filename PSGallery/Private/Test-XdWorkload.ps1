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
        [int]$LoadThreshold = 8000,
        [int]$DiskSpaceThreshold = 80,
        [int]$DiskQueueThreshold = 5,
        [switch]$All,

        [string]$ErrorLog
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Loading Citrix Broker Powershell Snapin"
        $ctxsnap = Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue
        $ctxsnap = Get-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Broker Snapin Load Failed"
            if ($ErrorLog) {
                Write-EUCError -Path $ErrorLog "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] XenDesktop Broker Snapin Load Failed"
            }
            throw "Cannot Load XenDesktop Powershell SDK"
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Broker Snapin Loaded"
        }

        $ctxsnap = Add-PSSnapin Citrix.Configuration.Admin.* -ErrorAction SilentlyContinue
        $ctxsnap = Get-PSSnapin Citrix.Configuration.Admin.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Configuration Snapin Load Failed"
            if ($ErrorLog) {
                Write-EUCError -Path $ErrorLog "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] XenDesktop Configuration Snapin Load Failed"
            }
            throw "Cannot Load XenDesktop Powershell SDK"
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Configuration Snapin Loaded"
        }
    } #BEGIN

    Process {
        $Results = @()

        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Querying Delivery Groups for type $Workload"
        if (-Not (Test-Connection -ComputerName $Broker -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
            if ($ErrorLog) {
                Write-EUCError -Path $ErrorLog "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Connection Failure to Broker: $Broker"
            }
            throw "Connection Failure to Broker: $Broker"
        }

        try {
            if ($Workload -match "Server") {
                $DeliveryGroups = Get-BrokerDesktopGroup -AdminAddress $Broker | Where-Object {$_.SessionSupport -eq "MultiSession"}
            }
            elseif ($Workload -match "Desktop") {
                $DeliveryGroups = Get-BrokerDesktopGroup -AdminAddress $Broker | Where-Object {$_.SessionSupport -eq "SessionSession"}
            }
            else {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure Unknown workload type"
                if ($ErrorLog) {
                    Write-EUCError -Path $ErrorLog "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure Unknown workload type"
                }
                throw "Unable to determine the workload type."
            }

            $SiteName = (Get-BrokerSite -AdminAddress $Broker).Name
            $ZoneNames = (Get-ConfigZone -AdminAddress $Broker).Name

            foreach ($ZoneName in $ZoneNames) {
                $CatalogNames = (Get-BrokerCatalog -AdminAddress $Broker -ZoneName $ZoneName).Name
                foreach ($CatalogName in $CatalogNames) {
                    foreach ($DeliveryGroup in $DeliveryGroups) {
                        $DeliveryGroupName = $DeliveryGroup.Name
                        $DGMaintMode = $DeliveryGroup.InMaintenanceMode
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

                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalSessions: $TotalSessions, ActiveSessions: $ActiveSessions"
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] IdleSessions: $IdleSessions, DisconnectedSessions: $DisconnectedSessions"
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
                                OtherSessions        = $TotalSessions - ($ActiveSessions + $IdleSessions + $DisconnectedSessions)
                            }

                            if ($WorkerHealth -or $All) {
                                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Fetching worker health count"
                                # Only test machines that aren't off, in delivery groups not in maint mode
                                $Workers = $Machines | Where-Object { ($_.PowerState -ne "Off") }

                                if (($null -ne $Workers) -and (-Not $DGMaintMode)) {
                                    $Params = @{
                                        Broker             = $Broker;
                                        Workload           = $Workload;
                                        SiteName           = $SiteName;
                                        ZoneName           = $ZoneName;
                                        CatalogName        = $CatalogName;
                                        DeliveryGroupName  = $DeliveryGroupName;
                                        Machines           = $Workers;
                                        BootThreshold      = $BootThreshold;
                                        LoadThreshold      = $LoadThreshold;
                                        DiskSpaceThreshold = $DiskSpaceThreshold;
                                        DiskQueueThreshold = $DiskQueueThreshold;
                                        ErrorLog           = $ErrorLog
                                    }
                                    $Results += Get-XdWorkerHealth @Params
                                }
                                else {
                                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Skipping XdWorkerHealth"
                                }
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
            # Will only get here if errors on return values, not nulls.
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Error Occured"
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"

            if ($ErrorLog) {
                Write-EUCError -Path $ErrorLog "[$(Get-Date)] [XdWorker] Exception: $_"
            }

            if ($null -eq $SiteName) { $SiteName = "ERROR" }
            if ($null -eq $ZoneName) { $ZoneName = "ERROR"}
            if ($null -eq $CatalogName) { $CatalogName = "ERROR" }
            if ($null -eq $DeliveryGroupName) { $DeliveryGroupName = "ERROR" }

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
                OtherSessions        = -1
            }
        }

        if ($Results.Count -gt 0) {
            return , $Results
        }
        else {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No results to return"
        }
    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}