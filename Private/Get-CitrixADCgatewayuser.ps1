
function Get-CitrixADCgatewayuser {
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

        $ICAUsers = -1
        $VPNUsers = -1
        $TotalUsers = -1

        try { 
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Try to get gateway users"
            $Method = "GET"
            $ContentType = 'application/json'
            $Params = @{
                uri         = "$ADC/nitro/v1/config/vpnicaconnection";
                WebSession  = $Session;
                ContentType = $ContentType;
                Method      = $Method
            }
            $UserSessions = Invoke-RestMethod @Params -ErrorAction Stop
            if ($null -eq $UserSessions) { 
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Could not retrieve ica user sessions"
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
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Could not retrieve vpn user sessions"
            }
            else {
                $VPNUsers = (($UserSessions.aaasession) | Measure-Object).count
            }

            $TotalUsers = $ICAUsers + $VPNUsers
        }
        catch {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Problem getting gateway users"
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"
        }

        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] ICAUsers: $ICAUsers, VPNUsers: $VPNUsers, TotalUsers: $TotalUsers"
        $Results += [PSCustomObject]@{
            Series     = "CitrixADC"
            Test       = "gatewayusers"
            Host       = $ADC
            ICAUsers   = $ICAUsers
            VPNUsers   = $VPNUsers
            TotalUsers = $TotalUsers
        }

        if ($Results.Count -gt 0) {
            return $Results
        }
    }
    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}