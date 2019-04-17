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

    Write-Host "Testing $Machine"
    # $Errors = @()
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
        # Test for ping first.
        $Connected = (Test-NetConnection -ComputerName $Machine -ErrorAction Stop -WarningAction SilentlyContinue)
        if (-Not ($Connected.PingSucceeded)) {
            $Health = "Unhealthy"
            $FailedPing = $true
            # If no address, then registration failure
            if ($null -eq $Connected.RemoteAddress) {
                $DNSNotRegistered = $true
            }
            # else, check for dns mismatch
            elseif ($Connected.RemoteAddress -ne $BrokerMachine.IPAddress) {
                $DNSMismatch = $true
            }
        }

        # Tests that require direct connectivity to the machines go here
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
        # ! Turn this into a splat
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
        # Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Error checking worker health on $Machine"
        # Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"
        # "[$(Get-Date) ERROR  ] [$($myinvocation.mycommand)] Error checking worker health on $Machine" | Out-File -FilePath "C:\Monitoring\Errorlog.txt" -Append
        # "[$(Get-Date) ERROR  ] $_"  | Out-File -FilePath "C:\Monitoring\$Machine.txt" -Append
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