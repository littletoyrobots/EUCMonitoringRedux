function Get-CitrixADCinterface {
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
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Fetching SSL Stats for $ADC"

            $Params = @{
                uri         = "$ADC/nitro/v1/stat/protocoltcp";
                WebSession  = $Session;
                ContentType = $ContentType;
                Method      = $Method
            }
            $InterfaceStat = Invoke-RestMethod @Params -ErrorAction Stop



            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] ActiveSRV: $Variable" 
            $Results += [PSCustomObject]@{
                Series = "CitrixADCinterface"
                Host   = $ADC
                Status = "UP"
                State  = 2

          
            }

        }
        catch {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"

            $Results += [PSCustomObject]@{
                Series = "CitrixADCinterface"
                Host   = $ADC
                Status = "ERROR"
                State  = -1
        
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