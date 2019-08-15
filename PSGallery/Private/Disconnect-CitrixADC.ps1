function Disconnect-CitrixADC {
    <#
    .SYNOPSIS
        Logs out of a Citrix NetScaler.

    .DESCRIPTION
        Logs out of a Citrix NetScaler and clears the NSSession Global Variable.

    .PARAMETER ADCSession
        CitrixADC Rest WebSession.

    .PARAMETER ErrorLog
        File path for error logs to be appended.
#>

    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $ADCSession,

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias("LogPath")]
        [string]$ErrorLog
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Disconnecting from $($ADCSession.ADC) using NITRO"
    } # Begin

    Process {
        $ADC = $ADCSession.ADC
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
            "logout" = @{}
        }

        # Logout of the NetScaler
        try {
            if ($null -eq $ADCSession.WebSession) {
                throw 'Must be logged into Citrix ADC first'
            }

            $Params = @{
                Uri        = "https://$ADC/nitro/v1/config/logout"
                Body       = $PayLoad
                Websession = $ADCSession.WebSession
                Headers    = @{"Content-Type" = "application/vnd.com.citrix.netscaler.logout+json"}
                Method     = "POST"
            }

            $Response = Invoke-RestMethod @Params # -ErrorAction Stop
            if ('ERROR' -eq $Response.severity) {
                throw "Error. See response: `n$($response | Format-List -Property * | Out-String)"
            }
        }
        catch {
            if ($ErrorLog) {
                Write-EUCError -Message "[$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" -Path $ErrorLog
            }
            else {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)"
            }
            throw $_
        }

    } # Process

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Logout Success"
    } # End
}