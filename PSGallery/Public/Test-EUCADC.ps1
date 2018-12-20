Function Test-EUCADC {
   
    [cmdletbinding()]
    Param(
        [Parameter(ValueFromPipeline, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ADC, #hard coded maybe OK
        
        # Will return Netscaler information
        [switch]$CitrixADC,
        [switch]$All, 

        [switch]$System,
        # Load Balancing
        # Caching
        # Compression
        # SSL Offloading
        # Content Switching
        # WAN Optimize?
        [switch]$GatewayUsers,
        [switch]$LoadBalance,
        [switch]$ContentSwitch,
        [switch]$Cache,
        [switch]$Compression,
        [switch]$SSLOffload,
        [switch]$ContentRoute,
   

        [pscredential]$Credential
    )
    
    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"

    } #BEGIN
		
    Process { 
        $Results = @()

        if ($CitrixADC) {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Connect Citrix ADC Session"
            $ADCSession = Connect-CitrixADC -ADC $ADC -Credential $Credential  

            if ($false -eq $ADCSession) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Invalid ADC Session"
                Write-Warning "Could not log into the Citrix ADC"
                return
            }
            else {
                if ($System -or $All) {
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

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Disconnect ADC Session"
                Disconnect-CitrixADC -ADCSession $ADCSession
            }
        }
        
        if ($Results.Count -gt 0) {
            return , $Results
        }


    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}