function Get-CADCcsvserver {
    <#
    .SYNOPSIS
    Gets basic stats on Citrix ADC gateway content switching virtual servers from NITRO

    .DESCRIPTION
    Gets basic stats on Citrix ADC gateway content switching virtual servers from NITRO by polling
    $ADC/nitro/v1/stats/csvserver and returning useful values.

    .PARAMETER ADC
    Alias: NSIP
    IP or DNS name of Citrix ADC Gateway

    .PARAMETER Credential
    ADC Credentials

    .PARAMETER ErrorLog
    Alias: LogPath
    Path to a file where any errors can be appended to

    .EXAMPLE
    Get-CADCcsvserver -ADC 10.1.2.3 -Credential (Get-Credential) -ErrorLog "C:\Monitoring\ADC-Errors.txt"

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
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "csvserver"

            foreach ($csvserver in $Results) {
                $Name = $csvserver.name
                $State = $csvserver.state
                $Health = [int]$csvserver.vslbhealth

                # Rates
                $HitsRate = [int]$csvserver.hitsrate
                $RequestsRate = [int]$csvserver.requestsrate
                $RequestBytesRate = [int]$csvserver.requestbytesrate
                $ResponsesRate = [int]$csvserver.responsesrate
                $ResponseBytesRate = [int]$csvserver.responsebytesrate

                #Totals
                $TotalHits = [int64]$csvserver.tothits
                $TotalRequests = [int64]$csvserver.totalrequests
                $TotalResponses = [int64]$csvserver.totalresponses

                # Current Connections
                $EstablishedConnections = [int]$csvserver.establishedconn
                $CurrentClientConnections = [int]$csvserver.curclntconnections
                $CurrentServerConnections = [int]$csvserver.cursrvrconnections

                if ($Health -eq 100) { $Status = 2 }
                elseif ($Health -gt 0) {
                    $Status = 1
                    if ($ErrorLog) {
                        Write-EUCError -Message "[$(Get-Date)] [CADCcsvserver] $ADC - $Name`: DEGRADED" -Path $ErrorLog
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [CADCcsvserver] $ADC - $Name`: - DEGRADED"
                    }
                }
                else {
                    $Status = 0
                    if ($ErrorLog) {
                        Write-EUCError -Message "[$(Get-Date)] [CADCcsvserver] $ADC - $Name`: DOWN" -Path $ErrorLog
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [CADCcsvserver] $ADC - $Name`: DOWN"
                    }
                }

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - Health: $Health, HitsRate: $HitsRate, RequestsRate: $RequestsRate, ResponsesRate: $ResponsesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - TotalHits: $TotalHits, TotalRequests: $TotalRequests, TotalResponses: $TotalResponses"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - Current Client Connections: $CurrentClientConnections, Current Server Connections: $CurrentServerConnections"
                [PSCustomObject]@{
                    Series                   = "CADCcsvserver"
                    PSTypeName               = 'EUCMonitoring.CADCcsvserver'
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

