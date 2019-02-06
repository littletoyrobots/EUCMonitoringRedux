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
            
            $MgmtCpuUsagePcnt = $SystemStat.System.Mgmtcpuusagepcnt
            $CpuUsagePcnt = $SystemStat.System.cpuusagepcnt
            $MemUsagePcnt = $SystemStat.System.memusagepcnt
            $PktCpuUsagePcnt = $SystemStat.System.pktcpuusagepcnt 
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Cpu: $CpuUsagePcnt Mgmt: $MgmtCpuUsagePcnt Pkt: $PktCpuUsagePcnt Mem: $MemUsagePcnt"
            
            $Params = @{
                uri         = "$ADC/nitro/v1/stat/protocoltcp";
                WebSession  = $Session;
                ContentType = $ContentType;
                Method      = $Method
            }
            $TCPStat = Invoke-RestMethod @Params -ErrorAction Stop

            # Rates
            $TCPRxPktRate = [int]$TCPStat.protocoltcp.tcprxpktsrate
            $TCPRxBytesRate = [int]$TCPStat.protocoltcp.tcprxbytesrate
            $TCPTxPktRate = [int]$TCPStat.protocoltcp.tcptxpktsrate
            $TCPTxBytesRate = [int]$TCPStat.protocoltcp.tcptxbytesrate


            # TCP Connections
            $TCPActiveServerConnections = [int]$TCPStat.protocoltcp.activeserverconn 
            $TCPCurClientConnEstablished = [int]$TCPStat.protocoltcp.tcpcurclientconnestablished
            $TCPCurServerConnEstablished = [int]$TCPStat.protocoltcp.tcpcurserverconnestablished

            $TCPCurrentClientConnections = [int]$TCPStat.protocoltcp.tcpcurclientconn
            $TCPCurrentServerConnections = [int]$TCPStat.protocoltcp.tcpcurserverconn

            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] ActiveSRV: $TCPActiveServerConnections" 
 
            $Results += [PSCustomObject]@{
                Series                      = "CitrixADCsystem"
                Host                        = $ADC
                Status                      = "UP"
                State                       = 2
                MgmtCpuUsagePcnt            = $MgmtCpuUsagePcnt
                CpuUsagePcnt                = $CpuUsagePcnt 
                MemUsagePcnt                = $MemUsagePcnt
                PktCpuUsagePcnt             = $PktCpuUsagePcnt

                TCPRxPktRate                = $TCPRxPktRate
                TCPRxBytesRate              = $TCPRxBytesRate
                TCPTxPktRate                = $TCPTxPktRate
                TCPTxBytesRate              = $TCPTxBytesRate

                TCPActiveServerConnections  = $TCPActiveServerConnections
                TCPCurClientConnEstablished = $TCPCurClientConnEstablished
                TCPCurServerConnEstablished = $TCPCurServerConnEstablished

                TCPCurrentClientConnections = $TCPCurrentClientConnections
                TCPCurrentServerConnections = $TCPCurrentServerConnections
            }

        }
        catch {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"

            $Results += [PSCustomObject]@{
                Series                      = "CitrixADCsystem"
                Host                        = $ADC
                Status                      = "ERROR"
                State                       = 2
                MgmtCpuUsagePcnt            = -1
                CpuUsagePcnt                = -1 
                MemUsagePcnt                = -1
                PktCpuUsagePcnt             = -1
                TCPRxPktRate                = -1
                TCPRxBytesRate              = -1
                TCPTxPktRate                = -1
                TCPTxBytesRate              = -1
                TCPActiveServerConnections  = -1
                TCPCurClientConnEstablished = -1
                TCPCurServerConnEstablished = -1
                TCPCurrentClientConnections = -1
                TCPCurrentServerConnections = -1
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