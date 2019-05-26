function Get-CADCsslcertkey {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("NSIP")]
        [string]$ADC,

        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [pscredential]$Credential,

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias("LogPath")]
        [string]$ErrorLogPath
    )

    Begin {
        # Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Starting session to $ADC"
        try {
            $ADCSession = Connect-CitrixADC -ADC $ADC -Credential $Credential
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Connection to $ADC established"
        }
        catch {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Connection to $ADC failed"
            throw $_
        }
    }

    Process {
        try {
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Config "sslcertkey"

            foreach ($sslcertkey in $Results) {
                $CertKey = $sslcertkey.CertKey
                $Subject = ($sslcertkey.Subject -split 'CN=')[1].split('/')[0]
                $Issuer = ($sslcertkey.Issuer -split 'CN=')[1]
                $Status = $sslcertkey.Status
                $DaysToExpiration = $sslcertkey.DaysToExpiration
                $IsClientCert = "CLNT_CERT" -in $sslcertkey.CertificateType
                $IsServerCert = "SRVR_CERT" -in $sslcertkey.CertificateType

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Certkey - Status: $Status, DaysToExpiration: $DaysToExpiration"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Client: $IsClientCert, Server: $IsServerCert, Subject: $Subject"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Issuer: $Issuer"

                [PSCustomObject]@{
                    Series           = "CADCsslcertkey"
                    PSTypeName       = 'EUCMonitoring.CADCsslcertkey'
                    ADC              = $ADC
                    CertKey          = $CertKey
                    Subject          = $Subject.trim()
                    Issuer           = $Issuer.trim()
                    Status           = $Status
                    DaysToExpiration = $DaysToExpiration
                    IsClientCert     = $IsClientCert
                    IsServerCert     = $IsServerCert
                }
            }
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
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Returned $($Results.Count) value(s)"
        Disconnect-CitrixADC -ADCSession $ADCSession
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Disconnected"
    }
}

