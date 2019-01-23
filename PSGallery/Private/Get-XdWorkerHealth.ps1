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
        
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Setting Up Runspace pool"
        $Pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
        $Pool.ApartmentState = "MTA"
        $Pool.Open()
        
    }

    Process {

        # Just remember, every test you run here will be run against every single worker target.  
        $Scriptblock = {
            Param (
                [string]$Machine,
                [string]$BootThreshold = -1,
                [string]$LoadThreshold = -1,     
                [string]$DiskSpaceThreshold = -1,
                [string]$DiskQueueThreshold = -1
            )
            begin { Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue }

            process { 
                # $Errors = @()
                $Status = "Not Run"

                $DNSMisMatch = $false
                $FailedPing = $false
                $HighUptime = $false
                $HighLoad = $false
                $HighDiskSpaceUsage = $false
                $HighDiskQueue = $false
                $Unregistered = $false

                try { 
                    # $FastPing = Test-Connection -ComputerName $Machine -Count 1 -Quiet -ErrorAction SilentlyContinue

                    # if (-Not $FastPing) {
                    $Connected = (Test-NetConnection -ComputerName $Machine -ErrorAction Stop)
                    if (-Not ($Connected.PingSucceeded)) {
                        $Status = "Unhealthy"
                        if ($null -eq $Connected.RemoteAddress) {
                            $DNSMisMatch = $true
                        }
                        else {
                            $FailedPing = $true
                        }
                    }
                    # }
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
                                $Status = "Unhealthy"
                                $HighUptime = $true
                            }
                        }

                        if (-1 -ne $DiskSpaceThreshold) {
                            foreach ($Device in $Disk) {
                                # If drive is read/write and greater than threshold.  
                                if ((3 -eq $Device.DriveType) -and (($Device.FreeSpace / $Device.Size) * 100 -ge [int]$DiskSpaceThreshold)) {
                                    $Status = "Unhealthy"
                                    $HighDiskSpaceUsage = $true
                                }
                            }
                        }
                
                        # This is slow.  
                        if (-1 -ne $DiskQueueThreshold) {
                            $Queues = (Get-Counter "\\$Machine\PhysicalDisk(*)\Current Disk Queue Length" -ErrorAction SilentlyContinue).CounterSamples.CookedValue
                            foreach ($Queue in $Queues) {
                                if ($Queue -ge [int]$DiskQueueThreshold) {
                                    $Status = "Unhealthy"
                                    $HighDiskQueue = $true
                                }
                            }
                        }
                    }
                
                
                    # Is the load of the machine within bounds?
                    if (-1 -ne $LoadThreshold) {
                        $Load = Get-BrokerMachine -AdminAddress $Broker -DNSName $Machine -ErrorAction Stop | Select-Object -ExpandProperty LoadIndex
                        # "Machine $Machine - Load Tested" | Out-File -FilePath "C:\Monitoring\Errorlog.txt" -Append
                        If ($Load -ge [int]$LoadThreshold) {
                            $Status = "Unhealthy"
                            $HighLoad = $true
                        }
                    }

                    # Is the machine registered? 
                    # ! Turn this into a splat
                    $Registered = Get-BrokerMachine -AdminAddress $Broker -DNSName $Machine -Property RegistrationState -ErrorAction Stop | Select-Object -ExpandProperty RegistrationState
                    # "Machine $Machine - Registered Tested: $Registered" | Out-File -FilePath "C:\Monitoring\Errorlog.txt" -Append                
                    if ("Registered" -ne $Registered) { 
                        $Status = "Unhealthy"
                        $Unregistered = $true 
                    }
            
                    # If status not changed, we're good.  
                    if ($Status -eq "Not Run") { 
                        $Status = "Healthy"
                    }
                
                }
                catch {
                    # Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Error checking worker health on $Machine"
                    # Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"
                    # "[$(Get-Date) ERROR  ] [$($myinvocation.mycommand)] Error checking worker health on $Machine" | Out-File -FilePath "C:\Monitoring\Errorlog.txt" -Append
                    "[$(Get-Date) ERROR  ] $_"  | Out-File -FilePath "C:\Monitoring\$Machine.txt" -Append
                    $Status = "ERROR"
                }

                return [PSCustomObject]@{
                    Host               = $Machine
                    Status             = $Status
                    DNSMisMatch        = $DNSMisMatch
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
            $Runspaces = @()
            $RunspaceResults = @()

            foreach ($Machine in $Machines) {
                $MachineName = $Machine.DNSName
                # "Runspace tool: Adding $MachineName" | Out-File -FilePath "C:\Monitoring\Errorlog.txt" -Append
                $Runspace = [PowerShell]::Create()
                $null = $Runspace.AddScript($Scriptblock)
                $null = $Runspace.AddArgument($MachineName)
                $null = $Runspace.AddArgument($BootThreshold)
                $null = $Runspace.AddArgument($LoadThreshold)
                $null = $Runspace.AddArgument($DiskSpaceThreshold)
                $null = $Runspace.AddArgument($DiskQueueThreshold)
                $Runspace.RunspacePool = $pool
                $Runspaces += [PSCustomObject]@{ Pipe = $Runspace; Status = $Runspace.BeginInvoke() }
            }

            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Runspace executing"
            while ($Runspaces.Status.IsCompleted -notcontains $true) { start-sleep -Seconds 1 }

            foreach ($Runspace in $Runspaces) {
                $RunspaceResults += $Runspace.Pipe.EndInvoke($Runspace.Status)
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
            $DNSMisMatch = 0
            $FailedPing = 0

            foreach ($Result in $RunspaceResults) {
                $ErrString = ""
                if ($Result.Status -eq "Healthy") { $Healthy++ }
                if (($Result.Status -eq "Unhealthy") -or ($Result.Status -eq "ERROR")) {
                    $Unhealthy++ 
                    if ($Result.FailedPing) { $FailedPing++; $ErrString += "FailedPing " }
                    if ($Result.DNSMisMatch) { $DNSMisMatch++; $ErrString += "DNSMisMatch "}
                    if ($Result.HighLoad) { $HighLoad++; $ErrString += "HighLoad " }
                    if ($Result.HighUptime) { $HighUptime++; $ErrString += "HighUptime " }
                    if ($Result.HighDiskSpaceUsage) { $HighDiskSpaceUsage++; $ErrString += "HighDiskSpaceUsage " }
                    if ($Result.HighDiskQueue) { $HighDiskQueue++; $ErrString += "HighDiskQueue " }
                    if ($Result.Unregistered) { $Unregistered++; $ErrString += "Unregistered " }
                    if ("ERROR" -eq $Result.Status) { $UnknownError++; $ErrString += "UnknownError" }

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
                DNSMisMatch        = $DNSMisMatch
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
                DNSMisMatch        = -1
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