function Get-CADCsslcertkey {
    <#
    .SYNOPSIS
    Gets basic stats on Citrix ADC gateway ssl certificates from NITRO

    .DESCRIPTION
    Gets basic stats on Citrix ADC gateway ssl certificates from NITRO by polling
    $ADC/nitro/v1/config/sslcertkey and returning useful values.

    .PARAMETER ADC
    IP or DNS name of Citrix ADC Gateway

    .PARAMETER Credential
    ADC Credentials

    .PARAMETER ErrorLogPath
    Path to a file where any errors can be appended to

    .EXAMPLE
    Get-CADCsslcertkey -ADC 10.1.2.3 -Credential (Get-Credential) -ErrorLogPath "C:\Monitoring\ADC-Errors.txt"

    .NOTES

    #>
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
                # $Subject = (($sslcertkey.Subject -split 'CN=')[1]).split('/')[0] # ! There's something off here for Go-Daddy Root cert.

                $Subject = ($sslcertkey.Subject -split 'CN=')[1]
                if ($null -eq $Subject) {
                    # -and ("ROOT_CERT" -in $sslcertkey.CertificateType)) {
                    $Subject = ($sslcertkey.Subject -split 'OU=')[1]
                }

                $Issuer = ($sslcertkey.Issuer -split 'CN=')[1]
                if ($null -eq $Issuer) {
                    # -and ("ROOT_CERT" -in $sslcertkey.CertificateType)) {
                    $Issuer = ($sslcertkey.Issuer -split 'OU=')[1]
                }

                $Status = $sslcertkey.Status
                $DaysToExpiration = $sslcertkey.DaysToExpiration
                if ($DaysToExpiration -lt 7) {
                    if ($ErrorLogPath) {
                        Write-EUCError -Message "[$(Get-Date)] [$($myinvocation.mycommand)] $Subject - DaysToExpiration: $DaysToExpiration" -Path $ErrorLogPath
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [$($myinvocation.mycommand)] $Subject - DaysToExpiration: $DaysToExpiration"
                    }
                }

                $IsClientCert = "CLNT_CERT" -in $sslcertkey.CertificateType
                $IsServerCert = "SRVR_CERT" -in $sslcertkey.CertificateType

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Certkey - Status: $Status, DaysToExpiration: $DaysToExpiration"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Client: $IsClientCert, Server: $IsServerCert"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Subject: $Subject"
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

