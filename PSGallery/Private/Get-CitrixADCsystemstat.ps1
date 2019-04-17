function Get-CitrixADCsystemstat {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $ADCSession
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
    } # Begin

    Process {
        $Results = @()

        $ADC = $ADCSession.ADC
        $Session = $ADCSession.WebSession
        $Method = "GET"
        $ContentType = 'application/json'

        try {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Fetching System Stats for $ADC"
            $Params = @{
                uri         = "$ADC/nitro/v1/stat/system";
                WebSession  = $Session;
                ContentType = $ContentType;
                Method      = $Method
            }
            $SystemStat = Invoke-RestMethod @Params -ErrorAction Stop

            $NumCpus = $SystemStat.System.numcpus
            $MgmtCpuUsagePcnt = $SystemStat.System.Mgmtcpuusagepcnt
            $CpuUsagePcnt = $SystemStat.System.cpuusagepcnt
            $MemUsagePcnt = $SystemStat.System.memusagepcnt
            $PktCpuUsagePcnt = $SystemStat.System.pktcpuusagepcnt
            $ResCpuUsagePcnt = $SystemStat.System.rescpuusagepcnt

            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] #: $NumCpus Cpu: $CpuUsagePcnt Mgmt: $MgmtCpuUsagePcnt "
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Pkt: $PktCpuUsagePcnt Mem: $MemUsagePcnt Res: $ResCpuUsagePcnt"

            $Results += [PSCustomObject]@{
                Series           = "CitrixADCsystem"
                Host             = $ADC
                Status           = "UP"
                State            = 2
                MgmtCpuUsagePcnt = $MgmtCpuUsagePcnt
                CpuUsagePcnt     = $CpuUsagePcnt
                MemUsagePcnt     = $MemUsagePcnt
                PktCpuUsagePcnt  = $PktCpuUsagePcnt
                ResCpuUsagePcnt  = $ResCpuUsagePcnt
                NumCpus          = $NumCpus
            }

        }
        catch {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"

            $Results += [PSCustomObject]@{
                Series           = "CitrixADCsystem"
                Host             = $ADC
                Status           = "ERROR"
                State            = -1
                MgmtCpuUsagePcnt = -1
                CpuUsagePcnt     = -1
                MemUsagePcnt     = -1
                PktCpuUsagePcnt  = -1
                ResCpuUsagePcnt  = -1
                NumCpus          = -1
            }
        }

        if ($Results.Count -gt 0) {
            return $Results
        }
    } # Process

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    } # End
}