Function Get-CVADworkerhealth {
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

        [switch]$ActiveOnly,

        # Tests
        [switch]$ConnectivityTests,

        [int]$BootThreshold,

        [int]$LoadThreshold,

        [int]$DiskSpaceThreshold,

        [int]$DiskQueueThreshold,

        [switch]$All, # AllSessionsTypes, AllTests

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

                if ($null -eq $SiteName) { $SiteName = (Get-BrokerSite -AdminAddress $AdminAddress).Name }
                if ($null -eq $ZoneName) { $ZoneName = (Get-ConfigZone -AdminAddress $AdminAddress).Name }

                if ($null -eq $DesktopGroupName) {
                    $SessionSupport = @()
                    # Default behavior is to both.
                    if ((-Not $SingleSession) -And (-Not $MultiSession)) { $All = $true }
                    if ($SingleSession -or $All) {
                        $SessionSupport += "SingleSession"
                    }
                    if ($MultiSession -or $All) {
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
