Function Get-CVADworkload {
    <#
    .SYNOPSIS
    Get basic stats on Citrix Virtual Apps and Desktops

    .DESCRIPTION
    Get basic stats on Citrix Virtual Apps and Desktops, including machine count, registration state totals,
    session totals, power state totals, etc.  The specified

    .PARAMETER Broker
    These are the Citrix VAD Brokers you want to test against. These are the delivery controllers, or cloud
    connectors, typically invoked in the Citrix PSSnapin as AdminAddress.

    .PARAMETER SiteName
    Allows you to specify the name of the Sites you want queried.  If not specified, will query
    against all Sites for the broker

    .PARAMETER ZoneName
    Allows you to specify the name of the Zones you want queried.  If not specified, will query
    against all Zones for the broker

    .PARAMETER CatalogName
    Allows you to specify the name of the Machine Catalogs you want queried.  If not specified, will query
    against all catalogs for the broker

    .PARAMETER DesktopGroupName
    Also known as DeliveryGroup, this specifies the group of machines

    .PARAMETER SingleSession
    Single session delivery groups, usually desktops

    .PARAMETER MultiSession
    Return values for multi session delivery groups, usually applications

    .PARAMETER All
    Return values for all session types.

    .EXAMPLE
    Get-CVADworkload -Broker "ddc1.domain.com", "ddc2.domain.com" -MultiSession -ErrorLog "errors.txt"

    .Example
    Get-CVADworkload -Broker "ddc1.domain.com" -All -Verbose

    .NOTES
    Need to have the permissions to run Get-BrokerSite, Get-BrokerMachine, Get-BrokerDesktopGroup, and
    Get-BrokerSession against the brokers you intend to query
    #>

    [cmdletbinding()]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("CloudConnector", "DeliveryController")]
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

        [switch]$All, # All Sessions Types

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias("LogPath")]
        [string]$ErrorLog
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Loading Citrix.Broker Powershell Snapins"
        $Snapins = "Citrix.Broker.Admin.V2", "Citrix.Configuration.Admin.V2"
        foreach ($Snapin in $Snapins) {
            if ($null -eq (Get-PSSnapin | Where-Object { $_.Name -eq $Snapin })) {
                Add-PSSnapin $Snapin -ErrorAction Stop
                Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] $Snapin loaded successfully"
            }
            else {
                Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] $Snapin already loaded"
            }
            # If we have failures loading, it will fail below.
        }
    }

    Process {
        $ResultCount = 0

        try {
            $PrevSuccess = $false
            foreach ($AdminAddress in $Broker) {
                # No need to repeat a first run
                if ($PrevSuccess) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Previous collection success, skipping $AdminAddress"
                    continue
                }

                # If we can't ping, skip and go to next broker.
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
                if ($null -eq $DesktopGroupName) {
                    $SessionSupport = @()
                    if ($SingleSession -or $All) {
                        $SessionSupport += "SingleSession"
                    }
                    if ($MultiSession -or $All) {
                        $SessionSupport += "MultiSession"
                    }

                    # Get the Desktop Groups for the specified Session Support
                    if (($null -ne $SessionSupport) -and ("" -ne $SessionSupport)) {
                        $DesktopGroupName += (Get-BrokerDesktopGroup -AdminAddress $AdminAddress -SessionSupport $SessionSupport).Name
                    }

                    # If not specified, default go getting both SingleSession and MultiSession
                    else {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No specified session support.  Assuming all."
                        $DesktopGroupName += (Get-BrokerDesktopGroup -AdminAddress $AdminAddress -SessionSupport "SingleSession", "Multisession" ).Name
                    }
                }

                # Realistically, this will generally just iterate once.
                foreach ($Site in $SiteName) {
                    foreach ($Zone in $ZoneName) {

                        # If the Catalogs aren't specified by parameters, grab all Catalogs
                        if ($null -eq $CatalogName) {
                            $CatalogName = (Get-BrokerCatalog -AdminAddress $AdminAddress -ZoneName $Zone).Name
                        }

                        foreach ($CatName in $CatalogName) {
                            # We iterate the known desktop groups for each catalog since you can have multiple
                            foreach ($DesktopGroup in $DesktopGroupName) {
                                # Grab all the machines associated with the DesktopGroup.
                                $DG = Get-BrokerDesktopGroup -AdminAddress $AdminAddress -Name $DesktopGroup
                                $BMParams = @{
                                    AdminAddress     = $AdminAddress;
                                    ZoneName         = $Zone;
                                    CatalogName      = $CatName;
                                    DesktopGroupName = $DesktopGroup;
                                    MaxRecordCount   = 99999
                                }
                                $Machines = Get-BrokerMachine @BMParams

                                # Only return values on delivery groups with machines in them.
                                if ($null -ne $Machines) {
                                    $MachineCount = $Machines.Count

                                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $SiteName / $Zone / $CatName / $DesktopGroup"
                                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] MachineCount: $MachineCount"

                                    $Registered = ($Machines | Where-Object { ($_.RegistrationState -eq "Registered" -and $_.PowerState -ne "Off") }).Count
                                    $Unregistered = ($Machines | Where-Object { ($_.RegistrationState -eq "Unregistered" -and $_.PowerState -ne "Off") }).Count
                                    $InMaintenance = ($Machines | Where-Object { (($_.InMaintenanceMode -eq $true) -and ($_.PowerState -ne "Off")) }).Count
                                    $FaultState = ($Machines | Where-Object { ($_.FaultState -ne "None") }).Count
                                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Registered: $Registered, Unregistered: $Unregistered"
                                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] InMaintenance: $InMaintenance, FaultState: $FaultState"

                                    $PowerOn = ($Machines | Where-Object { ($_.PowerState -eq "On") }).Count
                                    $PowerOff = ($Machines | Where-Object { ($_.PowerState -eq "Off") }).Count
                                    $PowerOther = ($Machines | Where-Object { ($_.PowerState -ne "On") -and ($_.PowerState -ne "Off") }).Count
                                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] PowerOn: $PowerOn, PowerOff: $PowerOff, PowerOther: $PowerOther"

                                    $LoadIndexAvg = ($Machines.LoadIndex | Measure-Object -Average).Average
                                    $LoadIndexMax = ($Machines.LoadIndex | Measure-Object -Maximum).Maximum
                                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] LoadIndexAvg: $LoadIndexAvg, LoadIndexMax: $LoadIndexMax"

                                    # Here's the costly bit.
                                    $params = @{
                                        AdminAddress     = $AdminAddress;
                                        ZoneName         = $Zone;
                                        CatalogName      = $CatName;
                                        DesktopGroupName = $DesktopGroup;
                                        #SessionState     = "Active"; # Get 'em all
                                        Maxrecordcount   = 99999
                                    }
                                    $Sessions = Get-BrokerSession @Params # Debating putting select statement so that
                                    $TotalSessions = $Sessions.Count

                                    $ActiveSessions = ($Sessions | Where-Object { $_.SessionState -eq "Active" -and $null -eq $_.IdleDuration } ).Count
                                    $IdleSessions = ($Sessions | Where-Object { $_.SessionState -eq "Active" -and $_.IdleDuration -gt [timespan]"00:00:00" } ).Count
                                    $DisconnectedSessions = ($Sessions | Where-Object { $_.SessionState -eq "Disconnected" }).Count

                                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalSessions: $TotalSessions, ActiveSessions: $ActiveSessions"
                                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] IdleSessions: $IdleSessions, DisconnectedSessions: $DisconnectedSessions"

                                    [PSCustomObject]@{
                                        Series               = "CVADworkload"
                                        PSTypeName           = 'EUCMonitoring.CVADworkload'
                                        Broker               = $AdminAddress
                                        SiteName             = $Site
                                        ZoneName             = $Zone
                                        CatalogName          = $CatName
                                        DeliveryGroupName    = $DesktopGroup
                                        SessionSupport       = "$($DG.SessionSupport)"
                                        MachineCount         = $MachineCount
                                        Registered           = $Registered
                                        Unregistered         = $Unregistered
                                        PowerOn              = $PowerOn
                                        PowerOff             = $PowerOff
                                        PowerOther           = $PowerOther
                                        InMaintenence        = $InMaintenance
                                        FaultState           = $FaultState
                                        LoadIndexAvg         = $LoadIndexAvg
                                        LoadIndexMax         = $LoadIndexMax
                                        TotalSessions        = $TotalSessions
                                        ActiveSessions       = $ActiveSessions
                                        IdleSessions         = $IdleSessions
                                        DisconnectedSessions = $DisconnectedSessions
                                        OtherSessions        = $TotalSessions - ($ActiveSessions + $IdleSessions + $DisconnectedSessions)
                                    }

                                    $ResultCount++
                                }
                            }
                        }
                    }
                }

                $PrevSuccess = $true
            }
            if (-Not $PrevSuccess) {
                if ($ErrorLog) {
                    Write-EUCError -Path $ErrorLog "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No successful CVAD Broker connection"
                }
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No successful CVAD Broker connection"
                }
                throw "Connection Failure to Broker(s): $($Broker -join ' ')"
            }
        }
        catch {
            if ($ErrorLogPath) {
                Write-EUCError -Message "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" -Path $ErrorLogPath
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
;