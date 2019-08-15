function Get-CADCNitroValue {
    <#
    .SYNOPSIS
        Logs into a Citrix NetScaler.
    .DESCRIPTION
        Logs into a NetScaler ADC and returns variable called $NSSession to be used to invoke NITRO Commands.
    .PARAMETER ADC
        Citrix ADC IP (NSIP)
    .PARAMETER Credential
        Credential to be used for login.
    .PARAMETER ADCUserName
        UserName to be used for login.
    .PARAMETER ADCPassword
        Password to be used for login
    #>
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $ADCSession,

        [parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = 'Stat')]
        [ValidateNotNullOrEmpty()]
        $Stat,

        [parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = 'Config')]
        [ValidateNotNullOrEmpty()]
        $Config,

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias("LogPath")]
        [string]$ErrorLog
    )

    Begin {

        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Changing TLS Settings to tls12, tls11, tls"
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Trusting self-signed certs"
        # source: https://blogs.technet.microsoft.com/bshukla/2010/04/12/ignoring-ssl-trust-in-powershell-system-net-webclient/

        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        if ($PSBoundParameters.ContainsKey('Stat')) {
            $Uri = "https://$($ADCSession.ADC)/nitro/v1/stat/$Stat"
            # $Uri = "$($ADCSession.ADC)/nitro/v1/stat/$Stat"
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Getting stat: $Stat"
            $NitroName = $Stat
        }
        if ($PSBoundParameters.ContainsKey('Config')) {
            $Uri = "https://$($ADCSession.ADC)/nitro/v1/config/$Config"
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Getting config: $Config"
            #$Uri = "$($ADCSession.ADC)/nitro/v1/config/$Config"
            $NitroName = $Config
        }

    } # Begin

    Process {
        #$ADC = $ADCSession.ADC
        $Session = $ADCSession.WebSession
        $Method = "GET"
        $ContentType = 'application/json'
        $Results = @()

        try {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Fetching from $Uri"
            $Params = @{
                uri         = $Uri;
                WebSession  = $Session;
                ContentType = $ContentType;
                Method      = $Method
            }
            $NitroValue = Invoke-RestMethod @Params -ErrorAction Stop

            if ($null -eq $NitroValue) {
                if ($ErrorLog) {
                    Write-EUCError -Message "[$($myinvocation.mycommand)] $Uri - No values returned" -Path $ErrorLog
                }
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Uri - No values returned"
                }
            }
            elseif (0 -ne $NitroValue.Errorcode) {
                if ($ErrorLog) {
                    Write-EUCError -Message "[$($myinvocation.mycommand)] [Severity: $($NitroValue.Severity)] $($NitroValue.Message)" -Path $ErrorLog
                }
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [Severity: $($NitroValue.Severity)] $($NitroValue.Message)"
                }
                throw "[Severity: $($NitroValue.Severity)] $($NitroValue.Message)"
            }
            else {
                $Results += $NitroValue.$NitroName
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

        return $Results
    }

    End {
        if ($Results) {
            Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Returned $($Results.Count) value(s)"
        }
    }
}
