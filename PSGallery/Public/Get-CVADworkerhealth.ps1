Function Get-CVADworkerhealth {
    <#
    .SYNOPSIS
    Gets basic stats on worker health of Citrix Virtual Apps and Desktops

    .DESCRIPTION
    Get basic stats on Citrix Virtual Apps and Desktops, including Boot Threshold, Load Threshold, Disk Space
    and Disk Queue thresholds, connectivity errors, etc.

    .PARAMETER Broker
    Alias: CloudConnector, DeliveryController, AdminAddress
    These are the Citrix VAD Brokers you want to test against. These are the delivery controllers, or cloud
    connectors, typically invoked in the Citrix PSSnapin as AdminAddress.

    .PARAMETER SiteName
    Alias: Site
    Allows you to specify the name of the Sites you want queried.  If not specified, will query
    against all Sites for the broker.

    .PARAMETER ZoneName
    Alias: Zone
    Allows you to specify the name of the Zones you want queried.  If not specified, will query
    against all Zones for the broker

    .PARAMETER CatalogName
    Alias: Catalog
    Allows you to specify the name of the Machine Catalogs you want queried.  If not specified, will query
    against all catalogs for the broker

    .PARAMETER DesktopGroupName
    Alias: DeliveryGroup
    Also known as DeliveryGroup, this specifies the group of machines

    .PARAMETER SingleSession
    Alias: Desktop
    Single session delivery groups, usually desktops

    .PARAMETER MultiSession
    Alias: Server
    Return values for multi session delivery groups, usually applications

    .PARAMETER ActiveOnly
    Only test machines that are not in maintenance mode.

    .PARAMETER AllSessionTypes
    Return values for all session types.

    .PARAMETER BootThreshold
    Number of days since machine boot.  If the boot time of a machine is greater than this
    value, it will be considered to have failed this health check

    .PARAMETER LoadThreshold
    Machine Load threshold, from 0 - 10000.  If the CVAD LoadIndex of a machines is greater than this value,
    it will be considered to have failed this health check.

    .PARAMETER DiskSpaceThreshold
    Percentage used of system drive.  If the used percentage for a system drive of a machine is greater than
    this value, it will be considered to have failed this health check

    .PARAMETER DiskQueueThreshold
    Percentage used of system drive.  If the used percentage for a system drive of a machine is greater than
    this value, it will be considered to have failed this health check

    .PARAMETER ErrorLog
    Parameter description

    .EXAMPLE
    Get-CVADworkerhealth -A

    .NOTES
    Need to have the permissions to run Get-BrokerSite, Get-BrokerMachine, Get-BrokerDesktopGroup against
    Delivery Controllers you intend to query
    Need to have the permissions to run Get-CimInstance against all endpoints you intend to query.
    #>

    [cmdletbinding()]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("CloudConnector", "DeliveryController", "AdminAddress")]
        [string[]]$Broker,

        [Alias("Site")]
        [string[]]$SiteName,

        [Alias("Zone")]
        [string[]]$ZoneName,

        [Alias("DeliveryGroupName")]
        [string[]]$DesktopGroupName,

        [Alias("Catalog")]
        [string[]]$CatalogName,

        [Alias("Desktop")]
        [switch]$SingleSession,

        [Alias("Server")]
        [switch]$MultiSession,

        [switch]$ActiveOnly,

        [switch]$AllSessionTypes,

        # Tests
        #    [switch]$ConnectivityTests,

        [int]$BootThreshold,

        [int]$LoadThreshold,

        [int]$DiskSpaceThreshold,

        [int]$DiskQueueThreshold,

        #    [switch]$AllSessionTypes, # AllSessionsTypes, AllTests

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias("LogPath")]
        [string]$ErrorLog
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Loading Citrix Powershell Snapins"
        $Snapins = "Citrix.Broker.Admin.V2", "Citrix.Configuration.Admin.V2"
        foreach ($Snapin in $Snapins) {
            if ($null -eq (Get-PSSnapin | Where-Object { $_.Name -eq $Snapin })) {
                Add-PSSnapin $Snapin -ErrorAction Stop
                Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] $Snapin loaded successfully"
            }
            else {
                Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] $Snapin already loaded"
            }
        }
    }

    Process {
        $ResultCount = 0

        try {
            $PrevSuccess = $false
            foreach ($AdminAddress in $Broker) {
                # Skip if previously successful
                if ($PrevSuccess) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Previous collection success, skipping $AdminAddress"
                    continue
                }
                # Skip if broker not pingable
                if (-Not (Test-Connection -ComputerName $AdminAddress -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
                    if ($ErrorLog) {
                        Write-EUCError -Path $ErrorLog "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Connection Failure to Broker: $AdminAddress"
                    }
                    else {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Connection Failure to Broker: $AdminAddress"
                    }
                    continue
                }

                # Fetch the basic values if not previously specified.
                if ($null -eq $SiteName) { $SiteName = (Get-BrokerSite -AdminAddress $AdminAddress).Name }
                if ($null -eq $ZoneName) { $ZoneName = (Get-ConfigZone -AdminAddress $AdminAddress).Name }

                # We want to default to everything unless otherwise specified
                if ($null -eq $DesktopGroupName) {
                    $SessionSupport = @()
                    # Default behavior is to both.
                    if ((-Not $SingleSession) -And (-Not $MultiSession)) {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No specified session support.  Assuming all."
                        $AllSessionTypes = $true
                    }
                    if ($SingleSession -or $AllSessionTypes) {
                        $SessionSupport += "SingleSession"
                    }
                    if ($MultiSession -or $AllSessionTypes) {
                        $SessionSupport += "MultiSession"
                    }
                    $DesktopGroupName += (Get-BrokerDesktopGroup -AdminAddress $AdminAddress -SessionSupport $SessionSupport).Name
                }

                # Realistically, this will generally just iterate once.
                foreach ($Site in $SiteName) {
                    # This too...
                    foreach ($Zone in $ZoneName) {

                        if ($null -eq $CatalogName) {
                            $CatalogName = (Get-BrokerCatalog -AdminAddress $AdminAddress -ZoneName $Zone).Name
                        }

                        foreach ($CatName in $CatalogName) {
                            foreach ($DesktopGroup in $DesktopGroupName) {
                                $DG = Get-BrokerDesktopGroup -AdminAddress $AdminAddress -Name $DesktopGroup
                                $Params = @{
                                    AdminAddress     = $AdminAddress;
                                    ZoneName         = $Zone;
                                    CatalogName      = $CatName;
                                    DesktopGroupName = $DesktopGroup;
                                    MaxRecordCount   = 99999
                                }
                                if ($ActiveOnly) {
                                    $Params.InMaintenanceMode = $false;
                                }

                                $Machines = Get-BrokerMachine @Params

                                # We don't care about empty Delivery Groups
                                if ($null -ne $Machines) {
                                    #$MachineNames = $Machines.DNSName
                                    $Params = @{
                                        Broker           = $AdminAddress;
                                        SiteName         = $Site;
                                        ZoneName         = $Zone;
                                        CatalogName      = $CatName;
                                        DesktopGroupName = $DesktopGroup;
                                        SessionSupport   = $DG.SessionSupport;
                                        MachineDNSNames  = $Machines.DNSName
                                    }

                                    # Add conditional parameters
                                    if ($ErrorLog) {
                                        $Params.ErrorLog = $ErrorLog
                                    }

                                    if ($BootThreshold) { $Params.BootThreshold = $BootThreshold }
                                    if ($LoadThreshold) { $Params.LoadThreshold = $LoadThreshold }
                                    if ($DiskSpaceThreshold) { $Params.DiskSpaceThreshold = $DiskSpaceThreshold }
                                    if ($DiskQueueThreshold) { $Params.DiskQueueThreshold = $DiskQueueThreshold }

                                    Test-CVADworkerhealth @Params

                                    $ResultCount++
                                }
                            }
                        }
                    }
                }

                $PrevSuccess = $true
            }
            if (-Not $PrevSuccess) {
                throw "Connection Failure to Broker(s): $($Broker -join ' ')"
            }
        }
        catch {
            if ($ErrorLog) {
                Write-EUCError -Message "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" -Path $ErrorLog
            }
            else {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)"
            }
            throw $_
        }
    }

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Returned $ResultCount value(s)"
    }
}
