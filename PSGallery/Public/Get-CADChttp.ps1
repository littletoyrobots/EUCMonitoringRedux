function Get-CADChttp {
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
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "protocolhttp"

            foreach ($http in $Results) {
                # Requests
                $TotalRequests = [int64]$http.httptotrequests
                $RequestsRate = $http.httprequestsrate
                $TotalRequestsBytes = [int64]$https.httptotrxrequestbytes
                $RequestsBytesRate = $http.httprxrequestbytesrate

                # Responses
                $TotalResponses = [int64]$http.httptotresponses
                $ResponsesRate = $http.httpresponsesrate
                $TotalResponsesBytes = [int64]$http.httptotrxresponsebytes
                $ResponsesBytesRate = $http.httprxresponsebytesrate

                # Gets / Posts / Other
                $TotalGets = [int64]$http.httptotgets
                $GetsRate = $http.httpgetsrate
                $TotalPosts = [int64]$http.httptotposts
                $PostsRate = $http.httppostsrate
                $TotalOthers = [int64]$http.httptotothers
                $OthersRate = $http.httpothersrate

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalRequests: $TotalRequests, RequestsRate: $RequestsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalRequestsBytes: $TotalRequestsBytes, RequestsBytesRate: $RequestsBytesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalResponses: $TotalResponses, ResponsesRate: $ResponsesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalResponsesBytes: $TotalResponsesBytes, ResponsesBytesRate: $ResponsesBytesRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalGets: $TotalGets, GetsRate: $GetsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalPosts: $TotalPosts, PostsRate: $PostsRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalOthers: $TotalOthers, OthersRate: $OthersRate"

                [PSCustomObject]@{
                    #    Series                   = "CADChttp"
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

