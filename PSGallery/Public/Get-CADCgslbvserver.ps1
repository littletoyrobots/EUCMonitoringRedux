function Get-CADCgslbvserver {
    <#
    .SYNOPSIS
    Gets basic stats on Citrix ADC gateway global server load balancing virtual servers from NITRO

    .DESCRIPTION
    Gets basic stats on Citrix ADC gateway global server load balancing virtual servers from NITRO by polling
    $ADC/nitro/v1/stats/gslbvserver and returning useful values.

    .PARAMETER ADC
    Alias: NSIP
    IP or DNS name of Citrix ADC Gateway

    .PARAMETER Credential
    ADC Credentials

    .PARAMETER ErrorLog
    Alias: LogPath
    Path to a file where any errors can be appended to

    .EXAMPLE
    Get-CADCgslbvserver -ADC 10.1.2.3 -Credential (Get-Credential) -ErrorLog "C:\Monitoring\ADC-Errors.txt"

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
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "gslbvserver"

            foreach ($gslbvserver in $Results) {
                $Name = $gslbvserver.name
                $State = $gslbvserver.state
                $Health = [int64]$gslbvserver.vslbhealth

                # Rates
                $HitsRate = [int64]$gslbvserver.hitsrate
                $RequestsRate = [int64]$gslbvserver.requestsrate
                $RequestBytesRate = [int64]$gslbvserver.requestbytesrate
                $ResponsesRate = [int64]$gslbvserver.responsesrate
                $ResponseBytesRate = [int64]$gslbvserver.responsebytesrate

                #Totals
                $TotalHits = [int64]$gslbvserver.tothits
                $TotalRequests = [int64]$gslbvserver.totalrequests
                $TotalResponses = [int64]$gslbvserver.totalresponses

                # Current Connections
                $EstablishedConnections = [int64]$gslbvserver.establishedconn
                $CurrentClientConnections = [int64]$gslbvserver.curclntconnections
                $CurrentServerConnections = [int64]$gslbvserver.cursrvrconnections

                if ($Health -eq 100) { $Status = 2 }
                elseif ($Health -gt 0) {
                    $Status = 1
                    if ($ErrorLog) {
                       Write-EUCError -Message "[CADCgslbvserver] $ADC - $Name`: DEGRADED" -Path $ErrorLog
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [CADCgslbvserver] $ADC - $Name`: DEGRADED"
                    }
                }
                else {
                    $Status = 0
                    if ($ErrorLog) {
                       Write-EUCError -Message "[CADCgslbvserver] $Name - DOWN" -Path $ErrorLog
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [CADCgslbvserver] $Name - DOWN"
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
            if ($ErrorLog) {
                Write-EUCError -Message "[$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" -Path $ErrorLog
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
