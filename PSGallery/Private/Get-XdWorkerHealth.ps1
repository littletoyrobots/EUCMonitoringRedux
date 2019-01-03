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
    
    .PARAMETER HighLoad
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
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$Workload, 
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$SiteName,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$ZoneName,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$CatalogName,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$DeliveryGroupName,

        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]$Machines, 

        [parameter(Mandatory = $true, ValueFromPipeline = $true)][int]$BootThreshold,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][int]$HighLoad
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
                $Session = new-cimsession -ComputerName $Machine -SessionOption $opt
                $OS = $Session | Get-Ciminstance -ClassName win32_operatingsystem
            }
            $Uptime = $OS.LocalDateTime - $OS.LastBootUpTime
            $UptimeDays = $Uptime.Days

            If ($UptimeDays -lt [int]$BootThreshold) {
                Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue
                $Load = Get-BrokerMachine  -AdminAddress $Broker -HostedMachineName $Machine -Property LoadIndex
                $CurrentLoad = $Load.LoadIndex
                If ($CurrentLoad -lt $HighLoad) {
                    $Status = "Healthy"
                }
                else {
                    $Status = "Unhealthy"
                    $errors += "$Machine has a high load of $CurrentLoad"
                }
            }
            else {
                $Status = "Unhealthy"
                $errors += "$Machine has not been booted in $UptimeDays days"
            }

            return [PSCustomObject]@{
                'Server'   = $Machine
                'Services' = $Status
                'Errors'   = $Errors
            }
        }

        
        $Results = @()

        $Runspaces = @()
        $RunspaceResults = @()
        $Healthy = 0
        $Unhealthy = 0

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

        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Runspace executing"
        while ($Runspaces.Status.IsCompleted -notcontains $true) {}

        foreach ($Runspace in $Runspaces) {
            $RunspaceResults += $Runspace.Pipe.EndInvoke($Runspace.Status)
            $Runspace.Pipe.Dispose()
        }

        # Parsing Results
        foreach ($Result in $RunspaceResults.Services) {
            if ($Result -eq "Healthy") { $Healthy++ }
            else { $Unhealthy++ }
        }

        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Healthy: $Healthy, Unhealthy: $Unhealthy"
        $Results += [PSCustomObject]@{
            Series            = "XdWorkerHealth"
            Type              = $Workload
            Host              = $Broker
            SiteName          = $SiteName
            ZoneName          = $ZoneName
            CatalogName       = $CatalogName
            DeliveryGroupName = $DeliveryGroupName
            Healthy           = $Healthy
            Unhealthy         = $Unhealthy                    
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