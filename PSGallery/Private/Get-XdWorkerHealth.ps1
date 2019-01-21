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
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][int]$DiskQueueThreshold
    )

    Begin { 
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
        
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Setting Up Runspace pool"
        $Pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
        $Pool.ApartmentState = "MTA"
        $Pool.Open()
        
    }

    Process {

        $Scriptblock = {
            Param (
                [string]$Machine,
                [string]$BootThreshold = -1,
                [string]$LoadThreshold = -1,
                
                [string]$DiskSpaceThreshold = -1,
                [string]$DiskQueueThreshold = -1
            )

            $Errors = @()
            $Status = "Not Run"

            $HighUptime = $false
            $HighLoad = $false
            $HighDiskSpaceUsage = $false
            $HighDiskQueue = $false
            $Unregistered = $false
            
            try { 
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

                if (-1 -ne $DiskQueueThreshold) {
                    $Queues = (Get-Counter "\\$Machine\PhysicalDisk(*)\Current Disk Queue Length" -ErrorAction SilentlyContinue).CounterSamples.CookedValue
                    foreach ($Queue in $Queues) {
                        if ($Queue -ge [int]$DiskQueueThreshold) {
                            $Status = "Unhealthy"
                            $HighDiskQueue = $true
                        }
                    }
                }

                # Load PSSnapin if checking load or registration
                # Test for Load of machine
                Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue
                if (-1 -ne $LoadThreshold) {
                    Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue
                    $Load = Get-BrokerMachine  -AdminAddress $Broker -HostedMachineName $Machine | Select-Object -ExpandProperty LoadIndex
                    If ($Load -ge [int]$LoadThreshold) {
                        $Status = "Unhealthy"
                        $HighLoad = $true
                        $errors += "$Machine has a high load of $CurrentLoad"
                    }
                }

                $Registered = get-brokermachine -AdminAddress $Broker -Property RegistrationState | Select-Object -ExpandProperty RegistrationState
                if (-not $Registered) { $Unregistered = $true }
            
                # If status not changed, we're good.  
                if ($Status -eq "Not Run") { 
                    $Status = "Healthy"
                }
            }
            catch {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Error checking worker health on $Machine"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"
                $Status = "ERROR"
            }

            return [PSCustomObject]@{
                'Host'               = $Machine
                'Status'             = $Status
                'HighUptime'         = $HighUptime
                'HighLoad'           = $HighLoad
                'HighDiskSpaceUsage' = $HighDiskSpaceUsage
                'HighDiskQueue'      = $HighDiskQueue
                'Unregistered'       = $Unregistered
            }
        }

        
        $Results = @()

        $Runspaces = @()
        $RunspaceResults = @()

        foreach ($Machine in $Machines) {
            $MachineName = $Machine.HostedMachineName
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
        while ($Runspaces.Status.IsCompleted -notcontains $true) {}

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

        foreach ($Result in $RunspaceResults) {
            if ($Result.Status -eq "Healthy") { $Healthy++ }
            else {
                $Unhealthy++ 
                if ($Result.HighLoad) { $HighLoad++ }
                if ($Result.HighUptime) { $HighUptime++ }
                if ($Result.HighDiskSpaceUsage) { $HighDiskSpaceUsage++ }
                if ($Result.HighDiskQueue) { $HighDiskQueue++ }
                if ($Result.Unregistered) { $Unregistered++ }
                if ("ERROR" -eq $Result.Status) { $UnknownError++ }
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
            HighLoad           = $HighLoad
            HighUptime         = $HighUptime
            HighDiskSpaceUsage = $HighDiskSpaceUsage
            HighDiskQueue      = $HighDiskQueue
            Unregistered       = $Unregistered
            UnknownError       = $UnknownError
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