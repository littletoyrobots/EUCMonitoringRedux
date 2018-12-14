Function Get-XdWorkerHealth {
    [cmdletbinding()]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()][string]$Broker, 

        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]$Machines, 

        [parameter(Mandatory = $true, ValueFromPipeline = $true)][int]$BootThreshold,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][int]$HighLoad
    )

    Begin { 
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Loading Citrix Broker Powershell Snapin"
        $ctxsnap = Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue
        $ctxsnap = Get-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Powershell Snapin Load Failed"
            Write-Error "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Cannot Load XenDesktop Powershell SDK"
            Return
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Powershell SDK Snapin Loaded"
        }

        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Setting Up Runspace pool"
        $Pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
        $Pool.ApartmentState = "MTA"
        $Pool.Open()
        $Runspaces = @()
    }

    Process {
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)]"

        $Scriptblock = {
            Param (
                [string]$Machine,
                [string]$BootThreshold,
                [string]$HighLoad
            )

            $Errors = @()
            $Status = "Not Run"

            # Test for Uptime of Machine
            [regex]$rx = "\d\.\d$"
            $data = test-wsman $Machine
            $rx.match($data.ProductVersion)
            if ($rx.match($data.ProductVersion).value -eq '3.0') {
                $os = Get-Ciminstance -ClassName win32_operatingsystem -ComputerName $Machine -ErrorAction Continue
            }
            else {
                $opt = New-CimSessionOption -Protocol Dcom
                $session = new-cimsession -ComputerName $machine -SessionOption $opt
                $os = $session | Get-Ciminstance -ClassName win32_operatingsystem
            }
            $Uptime = $OS.LocalDateTime - $os.LastBootUpTime
            $UptimeDays = $Uptime.Days

            If ($UptimeDays -lt [int]$BootThreshold) {
                Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue
                $Load = Get-BrokerMachine  -AdminAddress $Broker -HostedMachineName $Machine -Property LoadIndex
                $CurrentLoad = $Load.LoadIndex
                If ($CurrentLoad -lt $HighLoad) {
                    $Status = "Passed"
                }
                else {
                    $Status = "Degraded"
                    $errors += "$Machine has a high load of $CurrentLoad"
                }
            }
            else {
                $Status = "Degraded"
                $errors += "$Machine has not been booted in $UptimeDays days"
            }

            return [PSCustomObject]@{
                'Server'   = $Machine
                'Services' = $Status
                'Errors'   = $Errors
            }
        }
        $Results = @()

        foreach ($Machine in $Machines) {

            $MachineName = $Machine.HostedMachineName
            $Runspace = [PowerShell]::Create()
            $null = $Runspace.AddScript($Scriptblock)
            $null = $Runspace.AddArgument($MachineName)
            $null = $Runspace.AddArgument($BootThreshold)
            $null = $Runspace.AddArgument($HighLoad)
            $Runspace.RunspacePool = $pool
            $Runspaces += [PSCustomObject]@{ Pipe = $Runspace; Status = $Runspace.BeginInvoke() }
        }

        while ($Runspaces.Status.IsCompleted -notcontains $true) {}

        foreach ($Runspace in $Runspaces ) {
            $results += $Runspace.Pipe.EndInvoke($Runspace.Status)
            $Runspace.Pipe.Dispose()
        }

        $pool.Close()
        $pool.Dispose()

        Remove-Variable Runspaces -Force

        if ($Results.Count -gt 0) {
            return $Results
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