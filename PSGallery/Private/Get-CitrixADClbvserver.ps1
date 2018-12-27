
function Get-CitrixADClbvserver {
    <#
    .SYNOPSIS
    Short description
    
    .DESCRIPTION
    Long description
    
    .PARAMETER ADCSession
    Parameter description
    
    .EXAMPLE
    An example
    
    .NOTES
    General notes
    #>
    
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $ADCSession
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
    } # Begin

    Process { 
        $Results = @()

        $ADC = $ADCSession.ADC
        $Session = $ADCSession.WebSession
        $Method = "GET"
        $ContentType = 'application/json'

        try {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Fetching Load Balance Stats for $ADC"
            $Params = @{
                uri         = "$ADC/nitro/v1/stat/lbvserver";
                WebSession  = $Session;
                ContentType = $ContentType;
                Method      = $Method
            }
            $LBVServers = Invoke-RestMethod @Params -ErrorAction Stop

            if ($null -eq $LBVServers) { 
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No LB VServers"
            }
            else {
                foreach ($lbvserver in $LBVServers.lbvserver) {
                    $Name = $lbvserver.name
                    $Status = $lbvserver.state
                    $Health = [int]$lbvserver.vslbhealth
                    $HitsRate = [int]$lbvserver.hitsrate
                    $RequestsRate = [int]$lbvserver.requestsrate
                    $ResponsesRate = [int]$lbvserver.responsesrate
                    $TotalHits = [int]$lbvserver.tothits
                    $TotalRequests = [int]$lbvserver.totalrequests
                    $TotalResponses = [int]$lbvserver.totalresponses
                    $CurrentClientConnections = [int]$lbserver.curclntconnections 
                    $CurrentServerConnections = [int]$lbserver.cursrvrconnections 
                        
                    if ($Health -eq 100) { $State = 2 }
                    elseif ($Health -gt 0) { $State = 1 }
                    else { $State = 0 }

                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - Health: $Health, HitsRate: $HitsRate, RequestsRate: $RequestsRate, ResponsesRate: $ResponsesRate"
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - TotalHits: $TotalHits, TotalRequests: $TotalRequests, TotalResponses: $TotalResponses"
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Name - Current Client Connections: $CurrentClientConnections, Current Server Connections: $CurrentServerConnections"
                    $Results += [PSCustomObject]@{
                        Series                   = "CitrixADClbvserver"
                        Host                     = $ADC
                        Name                     = $Name
                        Status                   = $Status
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
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Problem getting load balancing vservers"
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"
            $Results += [PSCustomObject]@{
                Series                   = "CitrixADClbvserver"
                Host                     = $ADC
                Name                     = "ERROR"
                Status                   = "ERROR"
                State                    = -1
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
        if ($Results.Count -gt 0) {
            return $Results
        }
    } # Process

    End { 
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    } # End 
}