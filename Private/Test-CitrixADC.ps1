function Test-CitrixADC {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $ADC,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [pscredential]$Credential,
        
        [switch]$GatewayUsers,
        [switch]$LoadBalance,
        [switch]$ContentSwitch
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] $($myinvocation.mycommand)"
    } # Begin

    Process { 
        $Results = @()
        # $Errors = @()

        Write-Verbose "[$(Get-Date) PROCESS] Connect ADC Session"
        $ADCSession = Connect-CitrixADC -ADC $ADC -Credential $Credential
        $Session = $ADCSession.WebSession

        $Method = "GET"
        $ContentType = 'application/json'

        if ($false -eq $Session) {
            write-warning "Could not log into the Citrix ADC"
            return $false # This is so that Test-Series will handle appropriately.
        }
        else {
            if ($GatewayUsers) {
                $ICAUsers = -1
                $VPNUsers = -1
                $TotalUsers = -1

                try { 
                    Write-Verbose "[$(Get-Date) PROCESS] Get Gateway Users"

                    $Params = @{
                        uri         = "$ADC/nitro/v1/config/vpnicaconnection";
                        WebSession  = $Session;
                        ContentType = $ContentType;
                        Method      = $Method
                    }
                    $UserSessions = Invoke-RestMethod @Params -ErrorAction Stop
                    if ($null -eq $UserSessions) { 
                        Write-Verbose "[$(Get-Date) PROCESS] $($myinvocation.mycommand)"
                    }
                    else {
                        $ICAUsers = (($UserSessions.vpnicaconnection) | Measure-Object).count
                    }
            
                    $Params = @{
                        uri         = "$ADC/nitro/v1/config/aaasession";
                        WebSession  = $Session;
                        ContentType = $ContentType;
                        Method      = $Method
                    }
                    $UserSessions = Invoke-RestMethod @Params -ErrorAction Stop
                    if ($null -eq $UserSessions) {
                        Write-Verbose "[$(Get-Date) PROCESS] $($myinvocation.mycommand)"
                    }
                    else {
                        $VPNUsers = (($UserSessions.aaasession) | Measure-Object).count
                    }

                    $TotalUsers = $ICAUsers + $VPNUsers
                }
                catch {
                    Write-Verbose "[$(Get-Date) PROCESS] Problem getting gateway users"
                    Write-Verbose "[$(Get-Date) PROCESS] $_"
                }

                Write-Verbose "[$(Get-Date) PROCESS] ICAUsers: $ICAUsers, VPNUsers: $VPNUsers, TotalUsers: $TotalUsers"
                $Results += [PSCustomObject]@{
                    Series     = "CitrixADCGateway"
                    Test       = "gatewayusers"
                    Host       = $ADC
                    ICAUsers   = $ICAUsers
                    VPNUsers   = $VPNUsers
                    TotalUsers = $TotalUsers
                }
            }

            if ($LoadBalance) {
                try {
                    Write-Verbose "[$(Get-Date) PROCESS] Fetching Load Balance Stats for $ADC"
                    $Params = @{
                        uri         = "$ADC/nitro/v1/stat/lbvserver";
                        WebSession  = $Session;
                        ContentType = $ContentType;
                        Method      = $Method
                    }
                    $LBVServers = Invoke-RestMethod @Params -ErrorAction Stop

                    if ($null -eq $LBVServers) { 
                        Write-Verbose "[$(Get-Date) PROCESS] No LB VServers"
                    }
                    else {
                        foreach ($lbvserver in $LBVServers.lbvserver) {
                            $Name = $lbvserver.name
                            $State = $lbvserver.state
                            $Health = [int]$lbvserver.vslbhealth
                            $HitsRate = [int]$lbvserver.hitsrate
                            $RequestsRate = [int]$lbvserver.requestsrate
                            $ResponsesRate = [int]$lbvserver.responsesrate
                            $TotalHits = [int]$lbvserver.tothits
                            $TotalRequests = [int]$lbvserver.totalrequests
                            $TotalResponses = [int]$lbvserver.totalresponses
                            $CurrentClientConnections = [int]$lbserver.curclntconnections 
                            $CurrentServerConnections = [int]$lbserver.cursrvrconnections 
                        
                            Write-Verbose "[$(Get-Date) PROCESS] $Name - Health: $Health, HitsRate: $HitsRate, RequestsRate: $RequestsRate, ResponsesRate: $ResponsesRate"
                            Write-Verbose "[$(Get-Date) PROCESS] $Name - TotalHits: $TotalHits, TotalRequests: $TotalRequests, TotalResponses: $TotalResponses"
                            Write-Verbose "[$(Get-Date) PROCESS] $Name - Current Client Connections: $CurrentClientConnections, Current Server Connections: $CurrentServerConnections"
                            $Results += [PSCustomObject]@{
                                Series                   = "CitrixADCGateway"
                                Test                     = "lbvserver"
                                Host                     = $ADC
                                Name                     = $Name
                                State                    = $State
                                Health                   = $Health
                                HitsRate                 = $HitsRate
                                RequestsRate             = $RequestsRate
                                ResponsesRate            = $ResponsesRate
                                TotalHits                = $TotalHits
                                TotalRequests            = $TotalRequests
                                TotalResponses           = $TotalResponses
                                CurrentClientConnections = $CurrentClientConnections
                                CurrentServerConnections = $CurrentServerConnections
                            }
                        }    
                    }
                }
                catch {
                    Write-Verbose "[$(Get-Date) PROCESS] Problem getting load balancing vservers"
                    Write-Verbose "[$(Get-Date) PROCESS] $_"
                    $Results += [PSCustomObject]@{
                        Series                   = "CitrixADCGateway"
                        Test                     = "lbvserver"
                        Host                     = $ADC
                        Name                     = "ERROR"
                        Health                   = -1
                        HitsRate                 = -1
                        RequestsRate             = -1
                        ResponsesRate            = -1
                        TotalHits                = -1
                        TotalRequests            = -1
                        TotalResponses           = -1
                        CurrentClientConnections = -1
                        CurrentServerConnections = -1
                    }
                }
            }
            if ($ContentSwitch) {
                try {
                    Write-Verbose "[$(Get-Date) PROCESS] Fetching Content Switch Stats for $ADC"
                    $Params = @{
                        uri         = "$ADC/nitro/v1/stat/csvserver";
                        WebSession  = $Session;
                        ContentType = $ContentType;
                        Method      = $Method
                    }
                    $CSVServers = Invoke-RestMethod @Params -ErrorAction Stop

                    if ($null -eq $CSVServers) { 
                        Write-Verbose "[$(Get-Date) PROCESS] No CSVServers"
                    }
                    else {
                        foreach ($csvserver in $CSVServers.csvserver) {
                            $Name = $csvserver.Name
                            $Health = [int]$csvserver.vslbhealth
                            $HitsRate = [int]$csvserver.hitsrate
                            $RequestsRate = [int]$csvserver.requestsrate
                            $ResponsesRate = [int]$csvserver.responsesrate
                            $TotalHits = [int]$csvserver.tothits
                            $TotalRequests = [int]$csvserver.totalrequests
                            $TotalResponses = [int]$csvserver.totalresponses
                            $CurrentClientConnections = [int]$lbserver.curclntconnections 
                            $CurrentServerConnections = [int]$lbserver.cursrvrconnections 
                        
                            Write-Verbose "[$(Get-Date) PROCESS] $Name - Health: $Health, HitsRate: $HitsRate, RequestsRate: $RequestsRate, ResponsesRate: $ResponsesRate"
                            Write-Verbose "[$(Get-Date) PROCESS] $Name - TotalHits: $TotalHits, TotalRequests: $TotalRequests, TotalResponses: $TotalResponses"
                            Write-Verbose "[$(Get-Date) PROCESS] $Name - Current Client Connections: $CurrentClientConnections, Current Server Connections: $CurrentServerConnections"
                            $Results += [PSCustomObject]@{
                                Series                   = "CitrixADCGateway"
                                Test                     = "csvserver"
                                Host                     = $ADC
                                Name                     = $Name
                                State                    = $State
                                Health                   = $Health
                                HitsRate                 = $HitsRate
                                RequestsRate             = $RequestsRate
                                ResponsesRate            = $ResponsesRate
                                TotalHits                = $TotalHits
                                TotalRequests            = $TotalRequests
                                TotalResponses           = $TotalResponses
                                CurrentClientConnections = $CurrentClientConnections
                                CurrentServerConnections = $CurrentServerConnections
                            }
                        }    
                    }
                }
                catch {
                    Write-Verbose "[$(Get-Date) PROCESS] Problem getting load balancing vservers"
                    Write-Verbose "[$(Get-Date) PROCESS] $_"
                    $Results += [PSCustomObject]@{
                        Series                   = "CitrixADCGateway"
                        Test                     = "csvserver"
                        Host                     = $ADC
                        Name                     = "ERROR"
                        Health                   = -1
                        HitsRate                 = -1
                        RequestsRate             = -1
                        ResponsesRate            = -1
                        TotalHits                = -1
                        TotalRequests            = -1
                        TotalResponses           = -1
                        CurrentClientConnections = -1
                        CurrentServerConnections = -1
                    }
                }
            }
        }

        if ($Results.Count -gt 0) {
            return $Results
        }
    } # Process

    End { 
        Write-Verbose "[$(Get-Date) END    ] Disconnect ADC Session"
        Disconnect-CitrixADC -ADC $ADC -ADCSession $ADCSession
        Write-Verbose "[$(Get-Date) END    ] $($myinvocation.mycommand)"
    } # End 
}

. Private\Connect-CitrixADC.ps1
. PRivate\Disconnect-CitrixADC.ps1
$Creds = (Get-Credential)
Test-CitrixADCGateway -ADC 10.240.1.53 -Credential $Creds -GatewayUsers -LoadBalance -ContentSwitch -Verbose