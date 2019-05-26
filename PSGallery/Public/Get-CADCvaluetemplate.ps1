function Get-CADCvaluetemplate {
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
                    if ($ErrorLogPath) {
                        Write-EUCError -Message "[$(Get-Date)] [CitrixADCcsvserver] $Name DEGRADED" -Path $ErrorLogPath
                    }
                    else {
                        Write-Verbose "[$(Get-Date)] [CitrixADCcsvserver] $Name DEGRADED"
                    }
                }
                else {
                    $Status = 0
                    if ($ErrorLogPath) {
                        Write-EUCError -Message "[$(Get-Date)] [CitrixADCcsvserver] $Name DOWN" -Path $ErrorLogPath
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

