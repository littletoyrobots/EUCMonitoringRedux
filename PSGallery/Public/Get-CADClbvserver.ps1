function Get-CADClbvserver {
    <#
    .SYNOPSIS
    Gets basic stats on Citrix ADC gateway load balancing virtual servers from NITRO

    .DESCRIPTION
    Gets basic stats on Citrix ADC gateway load balancing virtual servers from NITRO by polling
    $ADC/nitro/v1/stats/lbvserver and returning useful values.

    .PARAMETER ADC
    Alias: NSIP
    IP or DNS name of Citrix ADC Gateway

    .PARAMETER Credential
    ADC Credentials

    .PARAMETER ErrorLogPath
    Alias: LogPath
    Path to a file where any errors can be appended to

    .EXAMPLE
    Get-CADClbvserver -ADC 10.1.2.3 -Credential (Get-Credential) -ErrorLogPath "C:\Monitoring\ADC-Errors.txt"

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
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "lbvserver"

            foreach ($lbvserver in $Results) {
                $Name = $lbvserver.name
                $State = $lbvserver.state
                $Health = [int]$lbvserver.vslbhealth

                # Rates
                $HitsRate = [int]$lbvserver.hitsrate
                $RequestsRate = [int]$lbvserver.requestsrate
                $RequestBytesRate = [int]$lbvserver.requestbytesrate
                $ResponsesRate = [int]$lbvserver.responsesrate
                $ResponseBytesRate = [int]$lbvserver.responsebytesrate

                #Totals
                $TotalHits = [int64]$lbvserver.tothits
                $TotalRequests = [int64]$lbvserver.totalrequests
                $TotalResponses = [int64]$lbvserver.totalresponses

                # Current Connections
                $EstablishedConnections = [int]$lbvserver.establishedconn
                $CurrentClientConnections = [int]$lbvserver.curclntconnections
                $CurrentServerConnections = [int]$lbvserver.cursrvrconnections

                if ($Health -eq 100) { $Status = 2 }
                elseif ($Health -gt 0) {
                    $Status = 1
                    if ($ErrorLogPath) {
                        Write-EUCError -Message "[$(Get-Date)] [CitrixADClbvserver] $Name - DEGRADED" -Path $ErrorLogPath
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [CitrixADClbvserver] $Name - DEGRADED"
                    }
                }
                else {
                    $Status = 0
                    if ($ErrorLogPath) {
                        Write-EUCError -Message "[$(Get-Date)] [CitrixADClbvserver] $Name - DOWN" -Path $ErrorLogPath
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [CitrixADClbvserver] $Name - DOWN"
                    }
                }

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - Health: $Health, HitsRate: $HitsRate, RequestsRate: $RequestsRate, ResponsesRate: $ResponsesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - TotalHits: $TotalHits, TotalRequests: $TotalRequests, TotalResponses: $TotalResponses"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - Current Client Connections: $CurrentClientConnections, Current Server Connections: $CurrentServerConnections"
                [PSCustomObject]@{
                    Series                   = "CADClbvserver"
                    PSTypeName               = 'EUCMonitoring.CADClbvserver'
                    ADC                      = $ADC
                    Name                     = $Name
                    Status                   = $Status
                    State                    = $State
                    Health                   = $Health
                    HitsRate                 = $HitsRate
                    RequestsRate             = $RequestsRate
                    RequestByteRate          = $RequestBytesRate
                    ResponsesRate            = $ResponsesRate
                    ResponseByteRate         = $ResponseBytesRate
                    TotalHits                = $TotalHits
                    TotalRequests            = $TotalRequests
                    TotalResponses           = $TotalResponses
                    EstablishedConnections   = $EstablishedConnections
                    CurrentClientConnections = $CurrentClientConnections
                    CurrentServerConnections = $CurrentServerConnections
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

