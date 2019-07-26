function Get-CADCsystem {
    <#
    .SYNOPSIS
    Gets basic stats on Citrix ADC gateway system from NITRO

    .DESCRIPTION
    Gets basic stats on Citrix ADC gateway system from NITRO by polling
    $ADC/nitro/v1/stats/system and returning useful values.

    .PARAMETER ADC
    Alias: NSIP
    IP or DNS name of Citrix ADC Gateway

    .PARAMETER Credential
    ADC Credentials

    .PARAMETER ErrorLog
    Alias: LogPath
    Path to a file where any errors can be appended to

    .EXAMPLE
    Get-CADCsystem -ADC 10.1.2.3 -Credential (Get-Credential) -ErrorLog "C:\Monitoring\ADC-Errors.txt"

    .NOTES

    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("NSIP")]
        [string]$ADC,

        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [pscredential]$Credential,

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias("LogPath")]
        [string]$ErrorLog
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Starting session to $ADC"
        try {
            $ADCSession = Connect-CitrixADC -ADC $ADC -Credential $Credential
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Connection to $ADC established"
        }
        catch {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Connection to $ADC failed"
            throw $_
        }
    }

    Process {
        try {
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "system"

            foreach ($System in $Results) {
                # Requests
                $NumCpus = $System.numcpus
                $MgmtCpuUsagePcnt = $System.Mgmtcpuusagepcnt
                $CpuUsagePcnt = $System.cpuusagepcnt
                $MemUsagePcnt = $System.memusagepcnt
                $PktCpuUsagePcnt = $System.pktcpuusagepcnt
                $ResCpuUsagePcnt = $System.rescpuusagepcnt

                #    $Config = Get-CADCNitroValue -ADCSession $ADCSession -Config "nsconfig"
                #    $DaysChanged = $Config.lastconfigchangedtime
                #    $DaysSaved = $Config.lastconfigsavedtime

                $Errors = @()
                if ($CpuUsagePcnt -gt 90) {
                    $Errors += "HighCPU"
                }
                if ($MemUsagePct -gt 90) {
                    $Errors += "HighMEM"
                }
                if ($Errors.Count -ge 1) {
                    if ($ErrorLog) {
                        Write-EUCError -Message "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $ADC - $($Errors -join ' ')" -Path $ErrorLog
                    }
                    else {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $ADC - $($Errors -join ' ')"
                    }
                }

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $ADC - NumCpus: $NumCpus Cpu: $CpuUsagePcnt Mgmt: $MgmtCpuUsagePcnt "
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $ADC - Pkt: $PktCpuUsagePcnt Mem: $MemUsagePcnt Res: $ResCpuUsagePcnt"



                [PSCustomObject]@{
                    Series           = "CADCsystem"
                    PSTypeName       = 'EUCMonitoring.CADCsystem'
                    ADC              = $ADC
                    MgmtCpuUsagePcnt = $MgmtCpuUsagePcnt
                    CpuUsagePcnt     = $CpuUsagePcnt
                    MemUsagePcnt     = $MemUsagePcnt
                    PktCpuUsagePcnt  = $PktCpuUsagePcnt
                    ResCpuUsagePcnt  = $ResCpuUsagePcnt
                    NumCpus          = $NumCpus
                    #    DaysSinceConfigLastChanged = $DaysChanged
                    #    DaysSinceConfigLastSaved   = $DaysSaved
                }
            }
        }
        catch {
            if ($ErrorLog) {
                Write-EUCError -Message "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" -Path $ErrorLog
            }
            else {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)"
            }
            throw $_
        }
    }

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Returned $($Results.Count) value(s)"
        Disconnect-CitrixADC -ADCSession $ADCSession
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Disconnected"
    }
}

