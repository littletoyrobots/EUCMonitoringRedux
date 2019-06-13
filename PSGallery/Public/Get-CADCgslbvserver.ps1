function Get-CADCgslbvserver {
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
