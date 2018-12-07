function Disconnect-CitrixADC {
    <# 
.SYNOPSIS 
    Logs out of a Citrix NetScaler.
.DESCRIPTION 
    Logs out of a Citrix NetScaler and clears the NSSession Global Variable.
.PARAMETER NSIP 
    Citrix NetScaler NSIP. 
.NOTES 
    Name: Disconnect-NetScaler
    Author: David Brett
    Date Created: 15/03/2017 
.CHANGE LOG
    David Brett     1.0     15/03/2017          Initial Script Creation 
    David Brett     1.1     14/06/2018          Edited the Function to remove positional parameters and cleaned out old code        
#> 

    [CmdletBinding()]
    Param
    (
        [parameter(Mandatory = $false, ValueFromPipeline = $true)]$ADCSession
    )
    
    Begin { 
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
    } # Begin 
    
    Process { 
        $ADC = $ADCSession.ADC
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Disconnecting from $ADC using NITRO"
        # Validate That the IP Address is valid
        # Test-IP $NSIP

        # Check to see if a valid NSSession is active. If not then quit the function
        if ($null -eq $ADC) {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Not a valid ADC address"
            break
        }
        if ($null -eq $ADCSession.WebSession) {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No valid ADC session found, quitting."
            break
        }

        # Set up the JSON Payload to send to the netscaler
        $PayLoad = ConvertTo-JSON @{
            "logout" = @{
            }
        }

        # Logout of the NetScaler
        try {
            $Params = @{
                Uri        = "$ADC/nitro/v1/config/logout"
                Body       = $PayLoad
                Websession = $ADCSession.WebSession
                Headers    = @{"Content-Type" = "application/vnd.com.citrix.netscaler.logout+json"}
                Method     = POST
            }
            Invoke-RestMethod @Params -ErrorAction Stop
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Logout Success"
        }
        Catch {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Unable to successfully close session"
        }

    } # Process

    End { 
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    } # End
}