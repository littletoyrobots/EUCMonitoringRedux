Function Get-CVADworkload {
    <#
    .SYNOPSIS
    Short description

    .DESCRIPTION
    Long description

    .PARAMETER Broker
    Parameter description

    .PARAMETER Workload
    Parameter description

    .PARAMETER SiteName
    Parameter description

    .PARAMETER ZoneName
    Parameter description

    .PARAMETER CatalogName
    Parameter description

    .PARAMETER DeliveryGroupName
    Parameter description

    .EXAMPLE
    An example

    .NOTES
    Current Version:    1.0
    Creation Date:      2019/01/01

    .CHANGE CONTROL
    Name                 Version         Date            Change Detail
    Adam Yarborough      1.0             2019/01/01      Function Creation
    #>

    [cmdletbinding()]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
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

        [switch]$All, # AllSessionsTypes, AllTests

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias("LogPath")]
        [string]$ErrorLog
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Loading Citrix.Broker Powershell Snapins"
        $ctxsnap = Get-PSSnapin -Registered Citrix.Broker.* -ErrorAction SilentlyContinue | Add-PSSnapin -PassThru

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Citrix.Broker Powershell Snapins Load Failed"
            Throw "Unable to load Citrix.Broker Powershell Snapins"
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Citrix.Broker Powershell Snapins Loaded"
        }

        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Loading Citrix.Configuration.Admin Powershell Snapins"
        $ctxsnap = Get-PSSnapin -Registered Citrix.Configuration.Admin.* -ErrorAction SilentlyContinue | Add-PSSnapin -PassThru

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Citrix.Configuration.Admin Powershell Snapins Load Failed"
            Throw "Unable to load Citrix.Configuration.Admin Powershell Snapins"
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Citrix.Configuration.Admin Powershell Snapins Loaded"
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
                    if ($null -ne $SessionSupport) {
                        $DesktopGroupName += (Get-BrokerDesktopGroup -AdminAddress $AdminAddress -SessionSupport $SessionSupport).Name
                    }
                    else {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No specified session support.  Assuming all."
                        $DesktopGroupName += (Get-BrokerDesktopGroup -AdminAddress $AdminAddress -SessionSupport SingleSession, Multisession ).Name
                    }
                }

                # Realistically, this will generally just iterate once.
                foreach ($Site in $SiteName) {
                    foreach ($Zone in $ZoneName) {
                        if ($null -eq $CatalogName) {
                            $CatalogName = (Get-BrokerCatalog -AdminAddress $AdminAddress -ZoneName $Zone).Name
                        }

                        foreach ($CatName in $CatalogName) {
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
                                    $IdleSessions = ($Sessions | Where-Object { $_.SessionState -eq "Active" -and $_.IdleDuration -gt [timespan]"00:00:00"} ).Count
                                    $DisconnectedSessions = ($Sessions | Where-Object { $_.SessionState -eq "Disconnected" }).Count

                                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalSessions: $TotalSessions, ActiveSessions: $ActiveSessions"
                                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] IdleSessions: $IdleSessions, DisconnectedSessions: $DisconnectedSessions"

                                    [PSCustomObject]@{
                                        Series               = "CVADWorkload"
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