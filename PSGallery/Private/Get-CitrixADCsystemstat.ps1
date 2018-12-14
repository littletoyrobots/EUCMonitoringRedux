function Get-CitrixADCsystemstat {
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
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Fetching Content Switch Stats for $ADC"
            $Params = @{
                uri         = "$ADC/nitro/v1/stat/csvserver";
                WebSession  = $Session;
                ContentType = $ContentType;
                Method      = $Method
            }

            $CSVServers = Invoke-RestMethod @Params -ErrorAction Stop

            if ($null -eq $CSVServers) { 
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Could not retrieve system stats"
            }


        }
        catch {


        }

        if ($Results.Count -gt 0) {
            return $Results
        }
    } # Process

    End { 
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    } # End 
}