Function Test-XdWorker {
    [cmdletbinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Broker, 
        [string]$Workload,
        [switch]$SessionInfo,
        
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
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Powershell Snapin Load Failed"
            throw "Cannot Load XenDesktop Powershell SDK"
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Powershell SDK Snapin Loaded"
        }
    } #BEGIN
		
    Process { 
        $Results = @()

        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Querying Delivery Groups for type $Workload"
        $SiteName = (Get-BrokerSite -AdminAddress $Broker).Name
        $ZoneNames = (Get-ConfigZone -AdminAddress $Broker).Name

        if ($Workload -match "server") {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
            $DeliveryGroups = Get-BrokerDesktopGroup -AdminAddress $Broker | Where-Object {$_.SessionSupport -eq "MultiSession"} 
        }
        elseif ($Workload -match "desktop") {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
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
                            $Count = $Machines.Count
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Worker Details: $ZoneName / $CatalogName / $DeliveryGroupName - Count: $Count"

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

                            $Results += [PSCustomObject]@{
                                Series            = "XdWorker"
                                Type              = $Workload
                                Host              = $Broker
                                SiteName          = $SiteName
                                ZoneName          = $ZoneName
                                CatalogName       = $CatalogName
                                DeliveryGroupName = $DeliveryGroupName
                                Count             = $Count
                                Registered        = $Registered
                                Unregistered      = $Unregistered
                                PowerOn           = $PowerOn
                                PowerOff          = $PowerOff
                                PowerOther        = $PowerOther
                                InMaintenence     = $InMaintenance
                                LoadIndexAvg      = $LoadIndexAvg
                                LoadIndexMax      = $LoadIndexMax
                            }
                                
                            if ($WorkerHealth -or $All) {
                                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Fetching worker health count"
                                $Params = @{
                                    Broker           = $Broker;
                                    SiteName         = $SiteName;
                                    ZoneName         = $ZoneName;
                                    CatalogName      = $CatalogName;
                                    DesktopGroupName = $DeliveryGroupName;
                                    Machines         = $Machines
                                }
                                $Results += Get-XdWorkerHealth @Params
                            }

                            if ($SessionInfo -or $All) {
                                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Fetching worker health count"
                                $Params = @{
                                    Broker           = $Broker;
                                    SiteName         = $SiteName;
                                    ZoneName         = $ZoneName;
                                    CatalogName      = $CatalogName;
                                    DesktopGroupName = $DeliveryGroupName;
                                    #    Machines         = $Machines
                                }
                                $Results += Get-XdSessionInfo @Params
                            }
                        }
                    }
                }
            }
        }
        catch {
            $Results += [PSCustomObject]@{
                Series            = "XdWorker"
                Type              = $Workload
                Host              = $Broker
                SiteName          = $SiteName
                ZoneName          = $ZoneName
                CatalogName       = $CatalogName
                DeliveryGroupName = $DeliveryGroupName
                Count             = -1
                Registered        = -1
                Unregistered      = -1
                PowerOn           = -1
                PowerOff          = -1
                PowerOther        = -1
                InMaintenence     = -1
                LoadIndexAvg      = -1
                LoadIndexMax      = -1
            }
        }

        if ($Results.Count -gt 0) {
            return $Results
        }
    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}