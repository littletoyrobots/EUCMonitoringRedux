function Get-CADCip {
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
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "protocolip"

            foreach ($ip in $Results) {
                # Rx
                $TotalRxPackets = [int64]$ip.iptotrxpkts
                $RxPacketsRate = $ip.iprxpktsrate
                $TotalRxBytes = [int64]$ip.iptotrxbytes
                $RxBytesRate = $ip.iprxbytesrate
                $TotalRxMbits = [int64]$ip.iptotrxmbits
                $RxMbitsRate = $ip.iprxmbitsrate

                # Tx
                $TotalTxPackets = [int64]$ip.iptottxpkts
                $TxPacketsRate = $ip.iptxpktsrate
                $TotalTxBytes = [int64]$ip.iptottxbytes
                $TxBytesRate = $ip.iptxbytesrate
                $TotalTxMbits = [int64]$ip.iptottxmbits
                $TxMbitsRate = $ip.iptxmbitsrate

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalRxPackets: $TotalRxPackets, RxPacketsRate: $RxPacketsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalRxBytes: $TotalRxBytes, RxBytesRate: $RxBytesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalRxMbits: $TotalRxMbits, RxMbitsRate: $RxMbitsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalTxPackets: $TotalTxPackets, TxPacketsRate: $TxPacketsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalTxBytes: $TotalTxBytes, TxBytesRate: $TxBytesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalTxMits: $TotalTxMbits, TxMbitsRate: $TxMbitsRate"

                [PSCustomObject]@{
                    Series         = "CADCip"
                    PSTypeName     = 'EUCMonitoring.CADCip'
                    ADC            = $ADC
                    TotalRxPackets = $TotalRxPackets
                    RxPacketsRate  = $RxPacketsRate
                    TotalRxBytes   = $TotalRxBytes
                    RxBytesRate    = $RxBytesRate
                    TotalRxMbits   = $TotalRxMbits
                    RxMbitsRate    = $RxMbitsRate
                    TotalTxPackets = $TotalTxPackets
                    TxPacketsRate  = $TxPacketsRate
                    TotalTxBytes   = $TotalTxBytes
                    TxBytesRate    = $TxBytesRate
                    TotalTxMits    = $TotalTxMbits
                    TxMbitsRate    = $TxMbitsRate
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

