function Get-CADCgatewayuser {
    <#
    .SYNOPSIS
    Gets basic stats on Citrix ADC gateway users from NITRO

    .DESCRIPTION
    Gets basic stats on Citrix ADC gateway users from NITRO by polling
    $ADC/nitro/v1/config/aaasession & $ADC/nitro/v1/config/vpnicaconnection and returning useful values.

    .PARAMETER ADC
    Alias: NSIP
    IP or DNS name of Citrix ADC Gateway

    .PARAMETER Credential
    ADC Credentials

    .PARAMETER ErrorLog
    Alias: LogPath
    Path to a file where any errors can be appended to

    .EXAMPLE
    Get-CADCgatewayuser -ADC 10.1.2.3 -Credential (Get-Credential) -ErrorLog "C:\Monitoring\ADC-Errors.txt"

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
        [string]$ErrorLog
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
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Config "vpnicaconnection"
            $VPNUsers = $Results.Count

            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Config "aaasession"
            $ICAUsers = $Results.Count

            $TotalUsers = $VPNUsers + $ICAUsers

            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $ADC - VPNUsers: $VPNUsers, ICAUsers: $ICAUsers, Total: $TotalUsers"
            [PSCustomObject]@{
                Series     = "CADCgatewayuser"
                PSTypeName = 'EUCMonitoring.CADCgatewayuser'
                ADC        = $ADC
                VPNUsers   = $VPNUsers
                ICAUsers   = $ICAUsers
                TotalUsers = $TotalUsers
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
    }

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Returned 1 value(s)"
        Disconnect-CitrixADC -ADCSession $ADCSession
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Disconnected"
    }
}

