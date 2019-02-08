function Get-CitrixADCtcp {
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
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Fetching TCP Stats for $ADC"

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
                Series                   = "CitrixADCtcp"
                Host                     = $ADC
                Status                   = "UP"
                State                    = 2

                RxPktRate                = $TCPRxPktRate
                RxBytesRate              = $TCPRxBytesRate
                TxPktRate                = $TCPTxPktRate
                TxBytesRate              = $TCPTxBytesRate

                ActiveServerConnections  = $TCPActiveServerConnections
                CurClientConnEstablished = $TCPCurClientConnEstablished
                CurServerConnEstablished = $TCPCurServerConnEstablished

                CurClientConnections     = $TCPCurrentClientConnections
                CurServerConnections     = $TCPCurrentServerConnections
            }

        }
        catch {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"

            $Results += [PSCustomObject]@{
                Series                   = "CitrixADCtcp"
                Host                     = $ADC
                Status                   = "ERROR"
                State                    = -1
                RxPktRate                = -1
                RxBytesRate              = -1
                TxPktRate                = -1
                TxBytesRate              = -1
                ActiveServerConnections  = -1
                CurClientConnEstablished = -1
                CurServerConnEstablished = -1
                CurClientConnections     = -1
                CurServerConnections     = -1
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