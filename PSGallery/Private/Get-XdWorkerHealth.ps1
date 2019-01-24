Function Get-XdWorkerHealth {
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
    
    .PARAMETER Machines
    Parameter description
    
    .PARAMETER BootThreshold
    Parameter description
    
    .PARAMETER LoadThreshold
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
        [ValidateNotNullOrEmpty()][string]$Broker, 
        # This section is for returned objects
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$Workload, 
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$SiteName,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$ZoneName,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$CatalogName,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$DeliveryGroupName,

        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]$Machines, 
        # These are the tests.  If set to -1, then tests skipped. 
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][int]$BootThreshold,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][int]$LoadThreshold,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][int]$DiskSpaceThreshold,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][int]$DiskQueueThreshold,
        [string]$ErrorLog
    )

    Begin { 
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
        
    
        
    }

    Process {

        # Just remember, every test you run here will be run against every single worker target.  
        $Scriptblock = {
            Param (
                [string]$Machine,
                [string]$Broker,
                [int]$BootThreshold = -1,
                [int]$LoadThreshold = -1,     
                [int]$DiskSpaceThreshold = -1,
                [int]$DiskQueueThreshold = -1
            )
            begin { Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue }

            process { 
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

                try { 
                    # $FastPing = Test-Connection -ComputerName $Machine -Count 1 -Quiet -ErrorAction SilentlyContinue
                    $BrokerMachine = Get-BrokerMachine -AdminAddress $Broker -DNSName $Machine -ErrorAction Stop

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
                        if ((-1 -ne $BootThreshold) -or (-1 -ne $DiskSpaceThreshold) -or (-1 -ne $DiskQueueThreshold)) {
                            [regex]$rx = "\d\.\d$"
                            $data = test-wsman $Machine
                            $rx.match($data.ProductVersion)
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
                        if (-1 -ne $BootThreshold) {
                            $Uptime = $OS.LocalDateTime - $OS.LastBootUpTime
                            $UptimeDays = $Uptime.Days

                            If ($UptimeDays -ge [int]$BootThreshold) {
                                $Health = "Unhealthy"
                                $HighUptime = $true
                            }
                        }

                        if (-1 -ne $DiskSpaceThreshold) {
                            foreach ($Device in $Disk) {
                                # If drive is read/write and greater than threshold.  
                                if ((3 -eq $Device.DriveType) -and (($Device.FreeSpace / $Device.Size) * 100 -ge [int]$DiskSpaceThreshold)) {
                                    $Health = "Unhealthy"
                                    $HighDiskSpaceUsage = $true
                                }
                            }
                        }
                
                        # This is slow.  
                        if (-1 -ne $DiskQueueThreshold) {
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
                    if (-1 -ne $LoadThreshold) {
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
                    "[$(Get-Date) ERROR  ] $_"  | Out-File -FilePath "C:\Monitoring\$Machine.txt" -Append
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

        
        $Results = @()

        try {
            # Create and open runspace pool, setup runspaces array with min and max threads
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Setting Up Runspace pool"
            $Pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
            $Pool.ApartmentState = "MTA"
            $Pool.Open()

            $Runspaces = @()
            $RunspaceResults = @()

            foreach ($Machine in $Machines.DNSName) {
                $Runspace = [PowerShell]::Create()
                $null = $Runspace.AddScript($Scriptblock)
                $null = $Runspace.AddArgument($Machine)
                $null = $Runspace.AddArgument($Broker)
                $null = $Runspace.AddArgument($BootThreshold)
                $null = $Runspace.AddArgument($LoadThreshold)
                $null = $Runspace.AddArgument($DiskSpaceThreshold)
                $null = $Runspace.AddArgument($DiskQueueThreshold)
                $Runspace.RunspacePool = $Pool
                try {
                    $Runspaces += [PSCustomObject]@{ Pipe = $Runspace; Status = $Runspace.BeginInvoke() }
                }
                catch {
                    if ($ErrorLog) {
                        Write-EUCError -Path $ErrorLog "[$(Get-Date)] [XdWorkerHealth] $_"
                        Write-EUCError -Path $ErrorLog "[$(Get-Date)] [XdWorkerHealth] M: $Machine B: $Broker BT: $BootThreshold LT: $LoadThreshold DST: $DiskSpaceThreshold DQT: $DiskQueueThreshold" 
                    }    
                }
            }

            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Runspace executing"
            while ($Runspaces.Status.IsCompleted -notcontains $true) { start-sleep -Seconds 1 }

            foreach ($Runspace in $Runspaces) {
                try {
                    $RunspaceResults += $Runspace.Pipe.EndInvoke($Runspace.Status)
                } 
                catch {
                    $Ex = $_.Exception
                    if ($null -ne $Ex.InnerException) {
                        $Ex = $Ex.InnerException
                    }
                    if ($ErrorLog) {
                        Write-EUCError -Path $ErrorLog "[$(Get-Date)] [XdWorkerHealth] $Ex" 
                    }
                }
                $Runspace.Pipe.Dispose()
            }

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
                if (($Result.Health -eq "Unhealthy") -or ($Result.Health -eq "ERROR")) {
                    $Unhealthy++ 
                    if ($Result.FailedPing) { $FailedPing++; $ErrString += "FailedPing " }
                    if ($Result.DNSMismatch) { $DNSMismatch++; $ErrString += "DNSMismatch "}
                    if ($Result.DNSNotRegistered) { $DNSNotRegistered++; $ErrString += "DNSNotRegistered "}
                    if ($Result.HighLoad) { $HighLoad++; $ErrString += "HighLoad " }
                    if ($Result.HighUptime) { $HighUptime++; $ErrString += "HighUptime " }
                    if ($Result.HighDiskSpaceUsage) { $HighDiskSpaceUsage++; $ErrString += "HighDiskSpaceUsage " }
                    if ($Result.HighDiskQueue) { $HighDiskQueue++; $ErrString += "HighDiskQueue " }
                    if ($Result.Unregistered) { $Unregistered++; $ErrString += "Unregistered " }
                    if ("ERROR" -eq $Result.Health) { $UnknownError++; $ErrString += "UnknownError" }

                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Unhealthy machine: $($Result.host) - $ErrString"
                    if ($ErrorLog) {
                        Write-EUCError -Path $ErrorLog "[$(Get-Date)] [XdWorkerHealth] $($Result.host) - $ErrString" 
                    }
                }
            }

            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Healthy: $Healthy, Unhealthy: $Unhealthy"
            $Results += [PSCustomObject]@{
                Series             = "XdWorkerHealth"
                Type               = $Workload
                Host               = $Broker
                SiteName           = $SiteName
                ZoneName           = $ZoneName
                CatalogName        = $CatalogName
                DeliveryGroupName  = $DeliveryGroupName
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
            if ($ErrorLog) {
                Write-EUCError -Path $ErrorLog "[$(Get-Date)] [XdWorkerHealth] Exception: $_" 
                Write-EUCError -Path $ErrorLog "[$(Get-Date)] [XdWorkerHealth] $Workload B: $Broker S: $SiteName Z: $ZoneName C: $CatalogName DG: $DeliveryGroupName"
            }
                
            $Results += [PSCustomObject]@{
                Series             = "XdWorkerHealth"
                Type               = $Workload
                Host               = $Broker
                SiteName           = $SiteName
                ZoneName           = $ZoneName
                CatalogName        = $CatalogName
                DeliveryGroupName  = $DeliveryGroupName
                Healthy            = -1
                Unhealthy          = -1
                DNSNotRegistered   = -1
                DNSMismatch        = -1
                FailedPing         = -1
                HighLoad           = -1
                HighUptime         = -1
                HighDiskSpaceUsage = -1
                HighDiskQueue      = -1
                Unregistered       = -1
                UnknownError       = -1
            }
        }
        
        
        <#
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Disposing of Runspace pool"
        $pool.Close()
        $pool.Dispose()

        Remove-Variable Runspaces -Force
#>
        if ($Results.Count -gt 0) {
            return , $Results
        }
    }

    End { 
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Cleaning up Runspace pool"
        $pool.Close()
        $pool.Dispose()

        Remove-Variable Runspaces -Force

        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}