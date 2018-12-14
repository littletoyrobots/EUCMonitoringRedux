function Test-ValidCert {
    <#
.SYNOPSIS
    Checks the validity of a remote certificate presented on a port, as seen by host the function is run on
.DESCRIPTION
    Checks the validity of a remote certificate presented on a port, as seen by host the function is run on.
.PARAMETER ComputerName
    Host you want to check the certificate of.  Can be hostname or IP.
.PARAMETER Port
    Specifies the ports to run checks against
.NOTES
    Current Version:        1.0
    Creation Date:          14/05/2018
.CHANGE CONTROL
    Name                    Version         Date                Change Detail
    Adam Yarborough         1.0             22/02/2018          Function Creation
    David Brett             1.1             16/06/2018          Updated Function Parameters
    Ryan Butler             1.2             09/08/2018          Validate on date vs Chain to avoid 
                                                                odd PS conditions. 
.CREDIT
    Original code by Rob VandenBrink, https://bit.ly/2IDf5Gd
.OUTPUT
    Returns boolean value.  $true / $false
.EXAMPLE
    None Required
#>

    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$ComputerName,
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][int]$Port
    )
    begin { 
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Changing TLS Settings"
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
        
        
    }

    process {
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing Valid Cert on $ComputerName Port: $Port"
        try {
            $TcpSocket = New-Object Net.Sockets.TcpClient($ComputerName, $Port)
            $tcpstream = $TcpSocket.GetStream()
            $Callback = { param($sender, $cert, $chain, $errors) return $true }
            $SSLStream = New-Object -TypeName System.Net.Security.SSLStream -ArgumentList @($tcpstream, $True, $Callback)

            try {
                $SSLStream.AuthenticateAsClient($ComputerName)
                $Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($SSLStream.RemoteCertificate)
            }
            catch { Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Could not authenticate as client to $ComputerName on $Port" }
            finally {
                $SSLStream.Dispose()
            }
        }
        catch { Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Could not connect to $ComputerName on $Port to test Cert" }

        if ($null -eq $Certificate) { return $false }
        else {
            $daysleft = $Certificate.NotAfter - (get-date)
            if ($daysleft.Days -le 5) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Cert about to expire"
                return $false
            }
            else {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Certificate valid"
                return $true
            }

        }
    }
    
    end {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] "
    }
}