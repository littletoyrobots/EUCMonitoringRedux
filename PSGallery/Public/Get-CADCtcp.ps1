function Get-CADCtcp {
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
        [string]$ErrorLogPath
    )

    Begin {
        # Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Starting session to $ADC"
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
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "protocoltcp"

            foreach ($tcp in $Results) {
                # Rx
                $TotalRxPackets = [int64]$tcp.tcptotrxpkts
                $RxPacketsRate = $tcp.tcprxpktsrate
                $TotalRxBytes = [int64]$tcp.tcptotrxbytes
                $RxBytesRate = $tcp.tcprxbytesrate

                # Tx
                $TotalTxPackets = [int64]$tcp.tcptottxpkts
                $TxPacketsRate = $tcp.tcptxpktsrate
                $TotalTxBytes = [int64]$tcp.tcptottxbytes
                $TxBytesRate = $tcp.tcptxbytesrate

                $ActiveServerConnections = [int]$tcp.activeserverconn
                $CurClientConnEstablished = [int]$tcp.tcpcurclientconnestablished
                $CurServerConnEstablished = [int]$tcp.tcpcurserverconnestablished
                $CurrentClientConnections = [int]$tcp.tcpcurclientconn
                $CurrentServerConnections = [int]$tcp.tcpcurserverconn

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalRxPackets: $TotalRxPackets, RxPacketsRate: $RxPacketsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalRxBytes: $TotalRxBytes, RxBytesRate: $RxBytesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalTxPackets: $TotalTxPackets, TxPacketsRate: $TxPacketsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalTxBytes: $TotalTxBytes, TxBytesRate: $TxBytesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] ActiveServerConnections: $ActiveServerConnections"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] CurClientConnEstablished: $CurClientConnEstablished, CurServerConnEstablished: $CurServerConnEstablished"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] CurClientConnections: $CurrentClientConnections, CurServerConnections: $CurrentServerConnections"

                [PSCustomObject]@{
                    #    Series                   = "CADCtcp"
                    PSTypeName               = 'EUCMonitoring.CADCtcp'
                    ADC                      = $ADC
                    TotalRxPackets           = $TotalRxPackets
                    RxPacketsRate            = $RxPacketsRate
                    TotalRxBytes             = $TotalRxBytes
                    RxBytesRate              = $RxBytesRate
                    TotalTxPackets           = $TotalTxPackets
                    TxPacketsRate            = $TxPacketsRate
                    TotalTxBytes             = $TotalTxBytes
                    TxBytesRate              = $TxBytesRate
                    ActiveServerConnections  = $ActiveServerConnections
                    CurClientConnEstablished = $CurClientConnEstablished
                    CurServerConnEstablished = $CurServerConnEstablished
                    CurClientConnections     = $CurrentClientConnections
                    CurServerConnections     = $CurrentServerConnections
                }
            }
        }
        catch {
            if ($ErrorLogPath) {
                Write-EUCError -Message "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" -Path $ErrorLogPath
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

