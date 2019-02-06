Function Test-EUCADC {
    <#
    .SYNOPSIS
    Return values on various l
    
    .DESCRIPTION
    Long description
    
    .PARAMETER CitrixADC
    Hostname / IP of the CitrixADCs
    
    .PARAMETER All
    Returns all available stats for the ADC
    
    .PARAMETER SystemStats
    Includes basic cpu/mem/load type stats in returned objects
    
    .PARAMETER GatewayUsers
    Includes gateway user stats in returned objects
    
    .PARAMETER LoadBalance
    Includes Load Balance stats in returned objects
    
    .PARAMETER ContentSwitch
    Includes Content Switch / Content Route stats in returned objects
    
    .PARAMETER Cache
    Includes cache stats in returned objects
    
    .PARAMETER Compression
    Includes compression stats in returned objects
    
    .PARAMETER SSLOffload
    Includes ssl offload stats in returned objects
    
    .PARAMETER Credential
    Parameter description
    
    .EXAMPLE
    An example
    
    .NOTES
    Current Version:    1.0
    Creation Date:      2019/01/01

    .CHANGE CONTROL
    Name                 Version         Date            Change Detail
    Adam Yarborough      1.0             2019/01/01      Function Creation
    #>
    [cmdletbinding()]
    Param(
        [Parameter(ValueFromPipeline, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        #[string]$ADC, #hard coded maybe OK
        
        # Will return Netscaler information
        [string[]]$CitrixADC,

        [string[]]$BarracudaADC,
        # Return all stats
        [switch]$All, 

        # Mainly for 
        [switch]$SystemStats,

        # Mainly for gateways
        [switch]$GatewayUsers,
        [switch]$LoadBalance,
        [switch]$ContentSwitch,
        [switch]$Cache, # Placeholder
        [switch]$Compression, # Placeholder
        [switch]$SSLOffload, # Placeholder

        [pscredential]$Credential
    )
    
    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"

    } #BEGIN
		
    Process { 
        $Results = @()

        foreach ($ADC in $CitrixADC) {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Connect Citrix ADC Session"
            $ADCSession = Connect-CitrixADC -ADC $ADC -Credential $Credential  

            if ($false -eq $ADCSession) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Invalid ADC Session"
                Write-Warning "Could not log into the Citrix ADC"
                return
            }
            else {
                if ($SystemStats -or $All) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] System Stats Enabled"
                    $Results += Get-CitrixADCsystemstat -ADCSession $ADCSession
                }
                if ($GatewayUsers -or $All) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Gateway Users Enabled"
                    $Results += Get-CitrixADCgatewayuser -ADCSession $ADCSession
                }

                if ($LoadBalance -or $All) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Load Balance Enabled"
                    $Results += Get-CitrixADClbvserver -ADCSession $ADCSession
                }

                if ($ContentSwitch -or $All) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Content Switch Enabled"
                    $Results += Get-CitrixADCcsvserver -ADCSession $ADCSession
                }

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Disconnect Citrix ADC Session"
                Disconnect-CitrixADC -ADCSession $ADCSession
            }
        }

        foreach ($ADC in $BarracudaADC) {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Connect Barracuda ADC Session"
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Not yet implemented"
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Disconnect Barracuda ADC Session"
        }
        
        if ($Results.Count -gt 0) {
            return , $Results
        }


    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}