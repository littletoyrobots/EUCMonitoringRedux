function Get-CADCgslbvserver {
    <#
    .SYNOPSIS
    Gets basic stats on Citrix ADC gateway global server load balancing virtual servers from NITRO

    .DESCRIPTION
    Gets basic stats on Citrix ADC gateway global server load balancing virtual servers from NITRO by polling
    $ADC/nitro/v1/stats/gslbvserver and returning useful values.

    .PARAMETER ADC
    IP or DNS name of Citrix ADC Gateway

    .PARAMETER Credential
    ADC Credentials

    .PARAMETER ErrorLogPath
    Path to a file where any errors can be appended to

    .EXAMPLE
    Get-CADCgslbvserver -ADC 10.1.2.3 -Credential (Get-Credential) -ErrorLogPath "C:\Monitoring\ADC-Errors.txt"

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
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "gslbvserver"

            foreach ($gslbvserver in $Results) {
                $Name = $gslbvserver.name
                $State = $gslbvserver.state
                $Health = [int]$gslbvserver.vslbhealth

                # Rates
                $HitsRate = [int]$gslbvserver.hitsrate
                $RequestsRate = [int]$gslbvserver.requestsrate
                $RequestBytesRate = [int]$gslbvserver.requestbytesrate
                $ResponsesRate = [int]$gslbvserver.responsesrate
                $ResponseBytesRate = [int]$gslbvserver.responsebytesrate

                #Totals
                $TotalHits = [int64]$gslbvserver.tothits
                $TotalRequests = [int64]$gslbvserver.totalrequests
                $TotalResponses = [int64]$gslbvserver.totalresponses

                # Current Connections
                $EstablishedConnections = [int]$gslbvserver.establishedconn
                $CurrentClientConnections = [int]$gslbvserver.curclntconnections
                $CurrentServerConnections = [int]$gslbvserver.cursrvrconnections

                if ($Health -eq 100) { $Status = 2 }
                elseif ($Health -gt 0) {
                    $Status = 1
                    if ($ErrorLogPath) {
                        Write-EUCError -Message "[$(Get-Date)] [CitrixADCgslbvserver] $Name - DEGRADED" -Path $ErrorLogPath
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [CitrixADCgslbvserver] $Name - DEGRADED"
                    }
                }
                else {
                    $Status = 0
                    if ($ErrorLogPath) {
                        Write-EUCError -Message "[$(Get-Date)] [CitrixADCgslbvserver] $Name - DOWN" -Path $ErrorLogPath
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [CitrixADCgslbvserver] $Name - DOWN"
                    }
                }

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - Health: $Health, HitsRate: $HitsRate, RequestsRate: $RequestsRate, ResponsesRate: $ResponsesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - TotalHits: $TotalHits, TotalRequests: $TotalRequests, TotalResponses: $TotalResponses"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - Current Client Connections: $CurrentClientConnections, Current Server Connections: $CurrentServerConnections"
                [PSCustomObject]@{
                    Series                   = "CADCgslbvserver"
                    PSTypeName               = 'EUCMonitoring.CADCgslbvserver'
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
