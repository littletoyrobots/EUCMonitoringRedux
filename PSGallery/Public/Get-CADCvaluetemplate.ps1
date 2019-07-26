function Get-CADCvaluetemplate {
    <#
    .SYNOPSIS
    Gets basic stats on Citrix ADC gateway valuetemplate from NITRO

    .DESCRIPTION
    Gets basic stats on Citrix ADC gateway valuetemplate from NITRO by polling
    $ADC/nitro/v1/stats/valuetemplate and returning useful values.

    .PARAMETER ADC
    Alias: NSIP
    IP or DNS name of Citrix ADC Gateway

    .PARAMETER Credential
    ADC Credentials

    .PARAMETER ErrorLog
    Alias: LogPath
    Path to a file where any errors can be appended to

    .EXAMPLE
    Get-CADCvaluetemplate -ADC 10.1.2.3 -Credential (Get-Credential) -ErrorLog "C:\Monitoring\ADC-Errors.txt"

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
            # ! Changeme "valuetemplate"
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "valuetemplate"

            foreach ($valuetemplate in $Results) {
                # Cast the big values coming over as strings to [int64]
                #    $TotalRxPackets = [int64]$ip.iptotrxpkts
                # Its fine to keep normal integers as regular values.
                #   $RxPacketsRate = $ip.iprxpktsrate

                # If an error condition can be found, such as degraded states, do your logging here.
                <#
                if ($Health -eq 100) { $Status = 2 }
                elseif ($Health -gt 0) {
                    $Status = 1
                    if ($ErrorLog) {
                        Write-EUCError -Message "[$(Get-Date)] [CitrixADCcsvserver] $Name DEGRADED" -Path $ErrorLog
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [CitrixADCcsvserver] $Name DEGRADED"
                    }
                }
                else {
                    $Status = 0
                    if ($ErrorLog) {
                        Write-EUCError -Message "[$(Get-Date)] [CitrixADCcsvserver] $Name DOWN" -Path $ErrorLog
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [CitrixADCcsvserver] $Name DOWN"
                    }
                }
                #>

                # Verbose values for testings
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $ADC - valuetemplate"

                [PSCustomObject]@{
                    Series     = "CADCvaluetemplate" # ! Changeme
                    PSTypeName = 'EUCMonitoring.CADCvaluetemplate' # ! Changeme
                    ADC        = $ADC
                    # Additional values here...

                }
            }
        }
        catch {
            if ($ErrorLog) {
                Write-EUCError -Message "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" -Path $ErrorLog
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

