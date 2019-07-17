function Connect-CitrixADC {
    <#
    .SYNOPSIS
        Logs into a Citrix NetScaler.
    .DESCRIPTION
        Logs into a NetScaler ADC and returns variable called $NSSession to be used to invoke NITRO Commands.
    .PARAMETER ADC
        Citrix ADC IP (NSIP)
    .PARAMETER Credential
        Credential to be used for login.
    .PARAMETER Timeout
        Timeout in seconds for the session, defaults to 180.
    .PARAMETER ErrorLogPath
        File path for error logs to be appended.
    .OUTPUTS
        Microsoft.PowerShell.Commands.WebRequestSession
    .EXAMPLE
        Connect-CitrixADC -ADC "10.11.12.13" -Credential (Get-Credential)
    .NOTES
        Version 1.0     Adam Yarborough     20190715

    .LINK
    https://github.com/littletoyrobots/EUCMonitoringRedux
    #>

    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("NSIP")]
        [string]$ADC,

        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [pscredential]$Credential,

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [int]$Timeout = 180,

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias("LogPath")]
        [string]$ErrorLogPath
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Changing TLS Settings to tls12, tls11, tls"
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Trusting self-signed certs"
        # source: https://blogs.technet.microsoft.com/bshukla/2010/04/12/ignoring-ssl-trust-in-powershell-system-net-webclient/
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    }

    Process {
        # Strip the Secure Password back to a basic text password
        #    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
        #    $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        # Set up the JSON Payload to send to the netscaler
        $PayLoad = ConvertTo-JSON @{
            "login" = @{
                "username" = $Credential.UserName;
                "password" = $Credential.GetNetworkCredential().Password
                "timeout"  = $Timeout
            }
        }

        $saveSession = @{ }

        # Connect to CitrixADC
        $Session = $null
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Connecting to ADC $ADC using NITRO"
        try {
            $Params = @{
                uri             = "https://$ADC/nitro/v1/config/login"
                #   uri             = "$ADC/nitro/v1/config/login"
                body            = $PayLoad
                SessionVariable = "saveSession"
                Headers         = @{"Content-Type" = "application/vnd.com.citrix.netscaler.login+json" }
                Method          = "POST"
            }

            $Response = Invoke-RestMethod @Params -ErrorAction Stop
            if ('ERROR' -eq $Response.severity) {
                throw "Error. See response: `n$($response | Format-List -Property * | Out-String)"
            }

            # Build Script ADC Session Variable
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Connection successful"
            $Session = New-Object -TypeName PSObject
            $Session | Add-Member -NotePropertyName ADC -NotePropertyValue $ADC -TypeName String
            $Session | Add-Member -NotePropertyName WebSession -NotePropertyValue $saveSession -TypeName Microsoft.PowerShell.Commands.WebRequestSession

            return $Session
        }
        catch {
            if ($ErrorLogPath) {
                Write-EUCError -Message "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" -Path $ErrorLogPath
            }
            else {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)"
            }
            throw $_
        }
    }

    End {
        if ($null -eq $Session) {
            Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] No session returned"
        }
        else {
            Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] ADC session returned"
        }
    }
}
