function Get-CADCssl {
    <#
    .SYNOPSIS
    Gets basic stats on Citrix ADC gateway ssl from NITRO

    .DESCRIPTION
    Gets basic stats on Citrix ADC gateway ssl from NITRO by polling
    $ADC/nitro/v1/stats/ssl and returning useful values.

    .PARAMETER ADC
    Alias: NSIP
    IP or DNS name of Citrix ADC Gateway

    .PARAMETER Credential
    ADC Credentials

    .PARAMETER ErrorLog
    Alias: LogPath
    Path to a file where any errors can be appended to

    .EXAMPLE
    Get-CADCssl -ADC 10.1.2.3 -Credential (Get-Credential) -ErrorLog "C:\Monitoring\ADC-Errors.txt"

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
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "ssl"

            foreach ($ssl in $Results) {
                $TotalSessions = [int64]$ssl.ssltotsessions
                $SessionsRate = $ssl.sslsessionsrate
                $TotalTransactions = [int64]$ssl.ssltottransactions
                $TransactionsRate = $ssl.ssltransactionsrate

                $TotalNewSessions = [int64]$ssl.ssltotnewsessions
                $NewSessionsRate = $ssl.sslnewsessionsrate
                $TotalSessionMiss = [int64]$ssl.ssltotsessionmiss
                $SessionsMissRate = $ssl.sslsessionmissrate
                $TotalSessionHits = [int64]$ssl.ssltotsessionhits
                $SessionsHitsRate = $ssl.sslsessionhitsrate

                $TotalBackendSessions = [int64]$ssl.sslbetotsessions
                $BackendSessionsRate = $ssl.sslbesessionsrate

                if ($ssl.sslenginestatus -eq 1) {
                    $EngineStatus = "UP"
                }
                else {
                    if ($ErrorLog) {
                        Write-EUCError -Message "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $ADC - SSLEngineStatus: DOWN" -Path $ErrorLog
                    }
                    else {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $ADC - SSLEngineStatus: DOWN"
                    }
                    $EngineStatus = "DOWN"
                }

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalSessions: $TotalSessions, SessionRate: $SessionsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalTransactions: $TotalTransactions, TransactionRate: $TransactionsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalNewSessions: $TotalNewSessions, NewSessionRate: $NewSessionsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalSessionMiss: $TotalSessionMiss, SessionsMissRate: $SessionsMissRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalSessionHits: $TotalSessionHits, SessionsHitsRate: $SessionsHitsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalBackendSessions: $TotalBackendSessions, BackendSessionsRate: $BackendSessionsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] EngineStatus: $EngineStatus"

                [PSCustomObject]@{
                    Series               = "CADCssl"
                    PSTypeName           = 'EUCMonitoring.CADCssl'
                    ADC                  = $ADC
                    TotalSessions        = $TotalSessions
                    SessionsRate         = $SessionsRate
                    TotalTransactions    = $TotalTransactions
                    TransactionsRate     = $TransactionsRate
                    TotalNewSessions     = $TotalNewSessions
                    NewSessionsRate      = $NewSessionsRate
                    TotalSessionMiss     = $TotalSessionMiss
                    SessionsMissRate     = $SessionsMissRate
                    TotalSessionHits     = $TotalSessionHits
                    SessionsHitsRate     = $SessionsHitsRate
                    TotalBackendSessions = $TotalBackendSessions
                    BackendSessionsRate  = $BackendSessionsRate
                    EngineStatus         = $EngineStatus
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

