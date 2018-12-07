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
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
    } # Begin

    Process { 
        $Results = @()
        # $Errors = @()

        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Connect ADC Session"
        $ADCSession = Connect-CitrixADC -ADC $ADC -Credential $Credential
        $Session = $ADCSession.WebSession

        if ($false -eq $Session) {
            write-warning "Could not log into the Citrix ADC"
            return $false # This is so that Test-Series will handle appropriately.
        }
        else {
            if ($GatewayUsers) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Gateway Users Enabled"
                $Results += Get-CitrixADCgatewayuser -ADCSession $ADCSession
            }

            if ($LoadBalance) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Load Balance Enabled"
                $Results += Get-CitrixADClbvserver -ADCSession $ADCSession
            }

            if ($ContentSwitch) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Content Switch Enabled"
                $Results += Get-CitrixADCcsvserver -ADCSession $ADCSession
            }
        }

        if ($Results.Count -gt 0) {
            return $Results
        }
    } # Process

    End { 
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Disconnect ADC Session"
        Disconnect-CitrixADC -ADC $ADC -ADCSession $ADCSession
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    } # End 
}

. Private\Connect-CitrixADC.ps1
. PRivate\Disconnect-CitrixADC.ps1
$Creds = (Get-Credential)
Test-CitrixADC -ADC 10.240.1.53 -Credential $Creds -GatewayUsers -LoadBalance -ContentSwitch -Verbose