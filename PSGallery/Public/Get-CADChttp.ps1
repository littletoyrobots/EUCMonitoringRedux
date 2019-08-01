function Get-CADChttp {
    <#
    .SYNOPSIS
    Gets basic stats on Citrix ADC gateway http from NITRO

    .DESCRIPTION
    Gets basic stats on Citrix ADC gateway http from NITRO by polling
    $ADC/nitro/v1/stats/protocolhttp and returning useful values.

    .PARAMETER ADC
    Alias: NSIP
    IP or DNS name of Citrix ADC Gateway

    .PARAMETER Credential
    ADC Credentials

    .PARAMETER ErrorLog
    Alias: LogPath
    Path to a file where any errors can be appended to

    .EXAMPLE
    Get-CADChttp -ADC 10.1.2.3 -Credential (Get-Credential) -ErrorLog "C:\Monitoring\ADC-Errors.txt"

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
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "protocolhttp"

            foreach ($http in $Results) {
                # Requests
                $TotalRequests = [int64]$http.httptotrequests
                $RequestsRate = [int64]$http.httprequestsrate
                $TotalRequestsBytes = [int64]$https.httptotrxrequestbytes
                $RequestsBytesRate = [int64]$http.httprxrequestbytesrate

                # Responses
                $TotalResponses = [int64]$http.httptotresponses
                $ResponsesRate = [int64]$http.httpresponsesrate
                $TotalResponsesBytes = [int64]$http.httptotrxresponsebytes
                $ResponsesBytesRate = [int64]$http.httprxresponsebytesrate

                # Gets / Posts / Other
                $TotalGets = [int64]$http.httptotgets
                $GetsRate = [int64]$http.httpgetsrate
                $TotalPosts = [int64]$http.httptotposts
                $PostsRate = [int64]$http.httppostsrate
                $TotalOthers = [int64]$http.httptotothers
                $OthersRate = [int64]$http.httpothersrate

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalRequests: $TotalRequests, RequestsRate: $RequestsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalRequestsBytes: $TotalRequestsBytes, RequestsBytesRate: $RequestsBytesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalResponses: $TotalResponses, ResponsesRate: $ResponsesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalResponsesBytes: $TotalResponsesBytes, ResponsesBytesRate: $ResponsesBytesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalGets: $TotalGets, GetsRate: $GetsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalPosts: $TotalPosts, PostsRate: $PostsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalOthers: $TotalOthers, OthersRate: $OthersRate"

                [PSCustomObject]@{
                    Series              = "CADChttp"
                    PSTypeName          = 'EUCMonitoring.CADChttp'
                    ADC                 = $ADC
                    TotalRequests       = $TotalRequests
                    RequestsRate        = $RequestsRate
                    TotalRequestsBytes  = $TotalRequestsBytes
                    RequestsBytesRate   = $RequestsBytesRate
                    TotalResponses      = $TotalResponses
                    ResponsesRate       = $ResponsesRate
                    TotalResponsesBytes = $TotalResponsesBytes
                    ResponsesBytesRate  = $ResponsesBytesRate
                    TotalGets           = $TotalGets
                    GetsRate            = $GetsRate
                    TotalPosts          = $TotalPosts
                    PostsRate           = $PostsRate
                    TotalOthers         = $TotalOthers
                    OthersRate          = $OthersRate
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

