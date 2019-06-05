function Get-CADCcache {
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
            $Results = Get-CADCNitroValue -ADCSession $ADCSession -Stat "cache"

            foreach ($cache in $Results) {
                $RecentHitPcnt = [int]$cache.cacherecentpercenthit
                $RecentMissPcnt = 100 - $RecentHitPcnt

                $CurrentHits = [int]$cache.cachecurhits
                $CurrentMiss = [int]$cache.cachecurmisses

                $HitsPcnt = [int]$cache.cachepercenthit
                $MissPcnt = 100 - $HitsPcnt

                $HitsRate = [int]$cache.cachehitsrate
                $RequestsRate = [int]$cache.cacherequestsrate
                $MissRate = [int]$cache.cachemissesrate

                $TotalHits = [int64]$cache.cachetothits
                $TotalMisses = [int64]$cache.cachetotmisses

                # Verbose values for testings
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $ADC - cache"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] RecentHitPcnt: $RecentHitPcnt, RecentMissPcnt: $RecentMissPcnt"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] HitsPcnt: $HitsPcnt, MissPcnt: $MissPcnt"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] CurrentHits: $CurrentHits, CurrentMiss: $CurrentMiss"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] HitsRate: $HitsRate, RequestsRate: $RequestsRate, MissRate: $MissRate"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] TotalHits: $TotalHits, TotalMisses: $TotalMisses"

                [PSCustomObject]@{
                    Series         = "CADCcache"
                    PSTypeName     = 'EUCMonitoring.CADCcache'
                    ADC            = $ADC
                    RecentHitPcnt  = $RecentHitPcnt
                    RecentMissPcnt = $RecentMissPcnt
                    CurrentHits    = $CurrentHits
                    CurrentMiss    = $CurrentMiss
                    HitsPcnt       = $HitsPcnt
                    MissPcnt       = $MissPcnt
                    HitsRate       = $HitsRate
                    RequestRate    = $RequestsRate
                    MissRate       = $MissRate
                    TotalHits      = $TotalHits
                    TotalMisses    = $TotalMisses
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

