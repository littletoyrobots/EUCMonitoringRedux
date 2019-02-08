function Test-RdsWorkload {
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Broker, 
        [string]$Workload,
        #        [switch]$SessionInfo, 
        #        [switch]$SessionDuration,
        #        [int]$DurationLength = 600, 
        
        [switch]$WorkerHealth,
        [int]$BootThreshold = 7,
        [int]$LoadThreshold = 8000,
        [int]$DiskSpaceThreshold = 80,
        [int]$DiskQueueThreshold = 5,
        [switch]$All,

        [string]$ErrorLog
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Loading RDS Powershell Snapin"

        Import-Module RemoteDesktop
    } #BEGIN

    # Broker, CollectionName, Workload, Host.  
    # $RDSessionCollections = (Get-RDSessionCollection -ConnectionBroker $ConnectionBrooker).Collectionname
    Process {
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] "

        # Get all the collections.  Iterate over them and get each collection's health, adding to returned 
        # results.  
        $Collections = Get-RDSessionCollection -ConnectionBroker $Broker

        foreach ($Collection in $Collections) {
            $CollectionName = $Collection.CollectionName

            $SessionHosts = Get-RDSessionHost -CollectionName -$CollectionName -CollectionBroker $Broker

            if ($null -ne $SessionHosts) {
                #$ActiveSessionHosts = Get-RDSessionHost -CollectionName -$CollectionName -CollectionBroker $Broker | Where-Object { $_.NewConnectionAllowed -eq "Yes"}
                $MachineCount = $SessionHosts.Count
                $Sessions = Get-RDUserSession -ConnectionBroker $Broker -CollectionName $CollectionName 


                # This work, even if $Sessions is null.
                $TotalSessions = $Sessions.Count
                $ActiveSessions = $Sessions.Count # | Where-Object SessionState -eq "XXX"
                $IdleSessions = $Sessions.Count  # ! Does something get returned here that makes this easy? 
                $DisconnectedSessions = $Sessions | Where-Object { $_.SessionState -eq "STATE_DISCONNECTED" }

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] " 
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] " 
                $Results += [PSCustomObject]@{
                    Series               = "XdWorker"
                    Type                 = $Workload
                    Host                 = $Broker

                    SiteName             = $SiteName
                    ZoneName             = $ZoneName

                    CollectionName       = $CollectionName
          
                    MachineCount         = $MachineCount
                    # Registered           = $Registered
                    # Unregistered         = $Unregistered
                    # PowerOn              = $PowerOn
                    # PowerOff             = $PowerOff
                    # PowerOther           = $PowerOther
                    # InMaintenence        = $InMaintenance
                    # LoadIndexAvg         = $LoadIndexAvg
                    # LoadIndexMax         = $LoadIndexMax
                    TotalSessions        = $TotalSessions
                    ActiveSessions       = $ActiveSessions
                    IdleSessions         = $IdleSessions
                    DisconnectedSessions = $DisconnectedSessions    
                    OtherSessions        = $TotalSessions - ($ActiveSessions + $IdleSessions + $DisconnectedSessions)
                }

                if ($WorkerHealth) {
                    # Filter out maintenance mode

                    $Params = @{

                    }
                    $Results += Get-RdsWorkerHealth @Params 
                }
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Skipping RdsWorkerHealth"
                }
            }
        }
    }

    End {
        Write-Verbose "[$(Get-Date) END   ] [$($myinvocation.mycommand)]"
    }

}