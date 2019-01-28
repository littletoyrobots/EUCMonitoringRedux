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

        import-module RemoteDesktop

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Broker Snapin Load Failed"
            if ($ErrorLog) {
                Write-EUCError -Path $ErrorLog "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] XenDesktop Broker Snapin Load Failed" 
            }
            throw "Cannot Load XenDesktop Powershell SDK"
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Broker Snapin Loaded"
        }

        $ctxsnap = Add-PSSnapin Citrix.Configuration.Admin.* -ErrorAction SilentlyContinue
        $ctxsnap = Get-PSSnapin Citrix.Configuration.Admin.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Configuration Snapin Load Failed"
            if ($ErrorLog) {
                Write-EUCError -Path $ErrorLog "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] XenDesktop Configuration Snapin Load Failed" 
            }
            throw "Cannot Load XenDesktop Powershell SDK"
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] XenDesktop Configuration Snapin Loaded"
        }
    } #BEGIN

    # Broker, CollectionName, Workload, Host.  
    # $RDSessionCollections = (Get-RDSessionCollection -ConnectionBroker $ConnectionBrooker).Collectionname
    Process {
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] "

        $Collections = Get-RDSessionCollection -ConnectionBroker $Broker

        foreach ($Collection in $Collections) {
            $CollectionName = $Collection.CollectionName

            $SessionHosts = Get-RDSessionHost -CollectionName -$CollectionName -CollectionBroker $Broker
            $ActiveSessionHosts = Get-RDSessionHost -CollectionName -$CollectionName -CollectionBroker $Broker | Where-Object { $_.NewConnectionAllowed -eq "Yes"}
            $Sessions = Get-RDUserSession -ConnectionBroker $Broker -CollectionName $CollectionName 


            # This work, even if $Sessions is null.
            $TotalSessions = $Sessions.Count
            $ActiveSessions = $Sessions # | Where-Object SessionState -eq "XXX"
            $IdleSessions = $Sessions #
            $DisconnectedSessions = $Sessions | Where-Object { $_.SessionState -eq "STATE_DISCONNECTED" }

            $Results += [PSCustomObject]@{
                Series               = "XdWorker"
                Type                 = $Workload
                Host                 = $Broker

                SiteName             = $SiteName
                ZoneName             = $ZoneName

                CollectionName       = $CollectionName

                # CatalogName          = $CatalogName
                # DeliveryGroupName    = $DeliveryGroupName
                                

                                
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
        }
    }

    End {
        Write-Verbose "[$(Get-Date) END   ] [$($myinvocation.mycommand)]"
    }

}