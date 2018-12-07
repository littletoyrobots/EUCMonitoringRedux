function Connect-CitrixADC {
    <# 
    .SYNOPSIS 
        Logs into a Citrix NetScaler.
    .DESCRIPTION 
        Logs into a NetScaler ADC and returns variable called $NSSession to be used to invoke NITRO Commands.
    .PARAMETER ADC 
        Citrix NetScaler NSIP.
    .PARAMETER Credential 
        UserName to be used for login.
    .NOTES 
        Name: Connect-NetScaler
        Author: David Brett
        Date Created: 15/03/2017
    .CHANGE LOG
        David Brett - 15/03/2017 - Initial Script Creation
        Ryan Butler - 27/03/2017 - Change to nssession scope 
        David Brett - 14/06/2018 - Edited the Function to remove positional parameters and cleaned up old code
        Adam Yarborough - 26/07/2018 - Edited to 
#> 

    [CmdletBinding()]
    Param
    (
        [parameter(Mandatory = $false, ValueFromPipeline = $true)]$ADC,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][pscredential]$Credential
    )

    begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
    }

    process {
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Changing TLS Settings"
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

        # Strip the Secure Password back to a basic text password
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
        $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        # Validate That the IP Address is valid
        # Test-IP $NSIP

        # Set up the JSON Payload to send to the netscaler    
        $PayLoad = ConvertTo-JSON @{
            "login" = @{
                "username" = $Credential.UserName;
                "password" = $UnsecurePassword
            }
        }

        # Connect to NetScaler
    
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Connecting to ADC $ADC using NITRO"
        try {
            $Params = @{
                uri             = "$ADC/nitro/v1/config/login"
                body            = $PayLoad
                SessionVariable = saveSession
                Headers         = @{"Content-Type" = "application/vnd.com.citrix.netscaler.login+json"}
                Method          = POST
            }
            Invoke-RestMethod @Params -ErrorAction Stop
        } 
        catch {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Error creating ADC Session"
            Write-Warning "Unable to connect to ADC $ADC"
            return $false
        }

        #return [Microsoft.PowerShell.Commands.WebRequestSession]$Session 
        # Build Script NetScaler Session Variable
        $Session = New-Object -TypeName PSObject
        $Session | Add-Member -NotePropertyName ADC -NotePropertyValue $ADC -TypeName String
        $Session | Add-Member -NotePropertyName WebSession -NotePropertyValue $saveSession -TypeName Microsoft.PowerShell.Commands.WebRequestSession

        # Return NetScaler Session
   
        return $Session
    }
    end {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}
