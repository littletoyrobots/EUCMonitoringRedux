
function Get-CitrixADCNitroValues {
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
        ,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Path = "stat/lbvserver"
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
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Nitro Fetch for $ADC $Path"
            $Params = @{
                uri         = "$ADC/nitro/v1/$Path";
                WebSession  = $Session;
                ContentType = $ContentType;
                Method      = $Method
            }
            $Values = Invoke-RestMethod @Params -ErrorAction Stop
        }
        catch {

        }

    }
    End {

    }
}