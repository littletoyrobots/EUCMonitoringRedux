Function Test-CVADworkerhealth {
    [cmdletbinding()]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Broker,
        # This section is for returned objects

        [Alias("Site")]
        [string]$SiteName,

        [Alias("Zone")]
        [string]$ZoneName,

        [Alias("Catalog")]
        [string]$CatalogName,

        [Alias("DeliveryGroup")]
        [string]$DesktopGroupName,

        [string]$SessionSupport,

        [string[]]$MachineDNSNames,

        # These are the tests.  If set to -1, then tests skipped.
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
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] $SiteName / $ZoneName / $CatalogName / $DesktopGroupName"
        # Create and open runspace pool, setup runspaces array with min and max threads
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Setting Up Runspace pool"
        $Pool = [RunspaceFactory]::CreateRunspacePool(1, ([int]$env:NUMBER_OF_PROCESSORS + 1))
        # $Pool.ThreadOptions = 'ReuseThread'
        $Pool.ApartmentState = "MTA"
        $Pool.Open()
    }

    Process {

        # Just remember, every test you run here will be run against every single worker target.  Don't
        # be a complete ass with someone else's machine.
        $Scriptblock = {
            Param (
                [string]$Machine,
                [string]$Broker,
                [int]$BootThreshold,
                [int]$LoadThreshold,
                [int]$DiskSpaceThreshold,
                [int]$DiskQueueThreshold
            )
            begin { Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue }

            process {
                $Health = "Not Run"

                $DNSMismatch = $false
                $DNSNotRegistered = $false
                $FailedPing = $false
                $HighUptime = $false
                $HighLoad = $false
                $HighDiskSpaceUsage = $false
                $HighDiskQueue = $false
                $Unregistered = $false

                $BrokerMachine = Get-BrokerMachine -AdminAddress $Broker -DNSName $Machine -ErrorAction Stop

                # First we'll test connection through WSMan
                try {
                    # $FastPing = Test-Connection -ComputerName $Machine -Count 1 -Quiet -ErrorAction SilentlyContinue

                    # Test for ping first.
                    $Connected = (Test-NetConnection -ComputerName $Machine -ErrorAction Stop)
                    if (-Not ($Connected.PingSucceeded)) {
                        $Health = "Unhealthy"
                        $FailedPing = $true
                        if ($null -eq $Connected.RemoteAddress) {
                            $DNSNotRegistered = $true
                        }
                        elseif ($Connected.RemoteAddress -ne $BrokerMachine.IPAddress) {
                            $DNSMismatch = $true
                        }
                    }

                    else {
                        # These tests will error out if connection failure.
                        # Little setup for the tests that need it.  Provides $OS and $DISK
                        if (($BootThreshold) -or ($DiskSpaceThreshold) -or ($DiskQueueThreshold)) {
                            [regex]$rx = "\d\.\d$"
                            $data = test-wsman $Machine -ErrorAction Stop
                            # $rx.match($data.ProductVersion)
                            if ($rx.match($data.ProductVersion).value -eq '3.0') {
                                $OS = Get-Ciminstance -ClassName win32_operatingsystem -ComputerName $Machine -ErrorAction Continue
                                $Disk = Get-Ciminstance -ClassName win32_logicaldisk -ComputerName $Machine -ErrorAction Continue
                            }
                            else {
                                $opt = New-CimSessionOption -Protocol Dcom
                                $Session = new-cimsession -ComputerName $Machine -SessionOption $opt
                                $OS = $Session | Get-Ciminstance -ClassName win32_operatingsystem
                                $Disk = $Session | Get-Ciminstance -ClassName win32_logicaldisk
                            }
                        }

                        # Test for Uptime of Machine
                        if ($BootThreshold) {
                            $Uptime = $OS.LocalDateTime - $OS.LastBootUpTime
                            $UptimeDays = $Uptime.Days

                            If ($UptimeDays -ge [int]$BootThreshold) {
                                $Health = "Unhealthy"
                                $HighUptime = $true
                            }
                        }

                        if ($DiskSpaceThreshold) {
                            foreach ($Device in $Disk) {
                                # If drive is read/write and greater than threshold.
                                if ((3 -eq $Device.DriveType) -and (($Device.FreeSpace / $Device.Size) * 100 -ge [int]$DiskSpaceThreshold)) {
                                    $Health = "Unhealthy"
                                    $HighDiskSpaceUsage = $true
                                }
                            }
                        }

                        # This is slow.
                        if ($DiskQueueThreshold) {
                            $Queues = (Get-Counter "\\$Machine\PhysicalDisk(*)\Current Disk Queue Length" -ErrorAction SilentlyContinue).CounterSamples.CookedValue
                            foreach ($Queue in $Queues) {
                                if ($Queue -ge $DiskQueueThreshold) {
                                    $Health = "Unhealthy"
                                    $HighDiskQueue = $true
                                }
                            }
                        }
                    }


                    # Is the load of the machine within bounds?
                    if ($LoadThreshold) {
                        if ($BrokerMachine.LoadIndex -ge $LoadThreshold) {
                            $Health = "Unhealthy"
                            $HighLoad = $true
                        }
                    }

                    # Is the machine registered?
                    if ("Registered" -ne $BrokerMachine.RegistrationState) {
                        $Health = "Unhealthy"
                        $Unregistered = $true
                    }

                    # If status not changed, we're good.
                    if ($Health -eq "Not Run") {
                        $Health = "Healthy"
                    }

                }
                catch {
                    $Health = "ERROR"
                }

                return [PSCustomObject]@{
                    Host               = $Machine
                    Health             = $Health
                    DNSMismatch        = $DNSMismatch
                    DNSNotRegistered   = $DNSNotRegistered
                    FailedPing         = $FailedPing
                    HighUptime         = $HighUptime
                    HighLoad           = $HighLoad
                    HighDiskSpaceUsage = $HighDiskSpaceUsage
                    HighDiskQueue      = $HighDiskQueue
                    Unregistered       = $Unregistered
                }
            }

            end { }
        } # SCRIPTBLOCK

        #
        # ! Actual meat of the script
        #
        try {
            $Runspaces = @()
            $RunspaceResults = @()

            $MachineList = New-Object System.Collections.ArrayList(, $MachineDNSNames)
            # TODO Lock-Object?  Compare different tests jobs / threads for speed
            # Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $($MachineList -join ', ')"

            foreach ($Machine in $MachineList) {
                $Runspace = [PowerShell]::Create()
                $Runspace.AddScript($Scriptblock) | Out-Null
                $Runspace.AddParameter('Machine', $Machine) | Out-Null
                $Runspace.AddParameter('Broker', $Broker) | Out-Null
                if ($BootThreshold) { $Runspace.AddParameter('BootThreshold', $BootThreshold) | Out-Null }
                if ($LoadThreshold) { $Runspace.AddParameter('LoadThreshold', $LoadThreshold) | Out-Null }
                if ($DiskSpaceThreshold) { $Runspace.AddParameter('DiskSpaceThreshold', $DiskSpaceThreshold) | Out-Null }
                if ($DiskQueueThreshold) { $Runspace.AddParameter('DiskQueueThreshold', $DiskQueueThreshold) | Out-Null }


                $Runspace.RunspacePool = $Pool

                # try / catch for Runspace errors instead of other errors
                try {
                    $Runspaces += [PSCustomObject]@{ Pipe = $Runspace; Status = $Runspace.BeginInvoke() }
                }
                catch {
                    if ($ErrorLogPath) {
                        Write-EUCError -Message "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" -Path $ErrorLogPath
                    }
                    else {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)"
                    }
                }
            }

            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Runspace executing"
            do {
                Start-Sleep -Seconds 1
                $Count = ($Runspaces | Where-Object { $_.Status.IsCompleted -ne $true }).Count
                if ($Count -gt 0) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Worker health checks remaining: $Count"
                }
            } while ($Count -gt 0)
            # while ($Runspaces.Status.IsCompleted -notcontains $true) { start-sleep -Seconds 1 }

            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Runspace complete"

            foreach ($Runspace in $Runspaces) {
                # try / catch for EndInvoke oddities.
                try {
                    $RunspaceResults += $Runspace.Pipe.EndInvoke($Runspace.Status)
                }
                catch {
                    $Ex = $_.Exception
                    if ($null -ne $Ex.InnerException) {
                        $Ex = $Ex.InnerException
                    }
                    if ($ErrorLog) {
                        Write-EUCError -Path $ErrorLog "[$(Get-Date)] [$($myinvocation.mycommand)] $Ex"
                    }
                    else {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Ex"
                    }
                }

                $Runspace.Pipe.Dispose()
            }

            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Parsing Results"
            # Parsing Results
            $Healthy = 0
            $Unhealthy = 0
            $HighLoad = 0
            $HighUptime = 0
            $HighDiskSpaceUsage = 0
            $HighDiskQueue = 0
            $Unregistered = 0
            $UnknownError = 0
            $DNSMismatch = 0
            $DNSNotRegistered = 0
            $FailedPing = 0

            foreach ($Result in $RunspaceResults) {
                $ErrString = ""
                if ($Result.Health -eq "Healthy") { $Healthy++ }
                #    if (($Result.Health -eq "Unhealthy") -or ($Result.Health -eq "ERROR")) {
                else {
                    $Unhealthy++
                    if ($Result.FailedPing) { $FailedPing++; $ErrString += "FailedPing " }
                    if ($Result.DNSMismatch) { $DNSMismatch++; $ErrString += "DNSMismatch " }
                    if ($Result.DNSNotRegistered) { $DNSNotRegistered++; $ErrString += "DNSNotRegistered " }
                    if ($Result.HighLoad) { $HighLoad++; $ErrString += "HighLoad " }
                    if ($Result.HighUptime) { $HighUptime++; $ErrString += "HighUptime " }
                    if ($Result.HighDiskSpaceUsage) { $HighDiskSpaceUsage++; $ErrString += "HighDiskSpaceUsage " }
                    if ($Result.HighDiskQueue) { $HighDiskQueue++; $ErrString += "HighDiskQueue " }
                    if ($Result.Unregistered) { $Unregistered++; $ErrString += "Unregistered " }
                    if ("ERROR" -eq $Result.Health) { $UnknownError++; $ErrString += "UnknownError" }


                    if ($ErrorLog) {
                        Write-EUCError -Path $ErrorLog "[$(Get-Date)] [CVADworkerhealth] $($Result.Host) - $ErrString"
                    }
                    else {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Unhealthy machine: $($Result.Host) - $ErrString"
                    }
                }
            }

            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Healthy: $Healthy, Unhealthy: $Unhealthy"
            [PSCustomObject]@{
                Series             = "CVADworkerhealth"
                PSTypeName         = 'EUCMonitoring.CVADworkerhealth'
                Broker             = $Broker
                SiteName           = $SiteName
                ZoneName           = $ZoneName
                CatalogName        = $CatalogName
                DesktopGroupName   = $DesktopGroupName
                SessionSupport     = $SessionSupport
                Healthy            = $Healthy
                Unhealthy          = $Unhealthy
                DNSNotRegistered   = $DNSNotRegistered
                DNSMismatch        = $DNSMismatch
                FailedPing         = $FailedPing
                HighLoad           = $HighLoad
                HighUptime         = $HighUptime
                HighDiskSpaceUsage = $HighDiskSpaceUsage
                HighDiskQueue      = $HighDiskQueue
                Unregistered       = $Unregistered
                UnknownError       = $UnknownError
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
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Cleaning up Runspace pool"
        $pool.Close()
        $pool.Dispose()

        Remove-Variable Runspaces -Force

        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Runspace disposed"
    }
}