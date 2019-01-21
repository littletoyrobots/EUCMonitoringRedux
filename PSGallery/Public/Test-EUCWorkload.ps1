
function Test-EUCWorkload {
    [CmdletBinding()]
    param (
        # Specifies the name of the series to run against. 
        #[Parameter(ValueFromPipeline, Mandatory = $true)]
        #    [string]$SeriesName,

        # The names of the servers to run against. 
        [Parameter(ValueFromPipeline, Mandatory = $true)]
        [string[]]$ComputerName,

        # Tells the function that the servers are part of a site, and if they
        # can connect to one
        [switch]$XdDesktop,
        [switch]$XdServer,

        # Default values for XdDesktop and XdServer Tests. 
        [switch]$WorkerHealth,
        [int]$BootThreshold = -1,
        [int]$LoadThreshold = -1,
        [int]$DiskSpaceThreshold = -1,
        [int]$DiskQueueThreshold = -1,

        # Will return extended session information based on site, catalog, delivery group, etc
        #    [switch]$SessionInfo,
        #    [switch]$SessionDuration,
        #    [int]$DurationLength = 600,
        
        [switch]$All,
        [Parameter(ValueFromPipeline, Mandatory = $false)]
        [pscredential]$Credential
    )
    
    
    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"

    } #BEGIN
		
    Process { 
        
        $Results = @()

        $XdDesktopComplete = $false
        $XdServerComplete = $false

        foreach ($Computer in $ComputerName) {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing $Computer" 
            $Connected = (Test-NetConnection -ComputerName $Computer -ErrorAction Stop)
            if (-Not ($Connected.PingSucceeded)) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Could not connect to $Computer"
                if ($null -eq $Connected.RemoteAddress) {
                    throw "Name resolution of $($Connected.ComputerName) failed"
                }
                continue
            }
            elseif ($XdDesktop) {
                
                if ($XdDesktopComplete) { 
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Skipping XdDesktop"
                } 
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing XdDesktop"
                    #        try {       
                    $params = @{
                        Broker             = $Computer;
                        Workload           = 'Desktop';
                        #    SessionInfo     = $SessionInfo;
                        #    SessionDuration = $SessionDuration;
                        #    DurationLength  = $DurationLength;
                        WorkerHealth       = $WorkerHealth;
                        BootThreshold      = $BootThreshold;
                        LoadThreshold      = $LoadThreshold;
                        DiskSpaceThreshold = $DiskSpaceThreshold;
                        DiskQueueThreshold = $DiskQueueThreshold;
                        All                = $All
                    }
                    $Results += Test-XdWorkload @params
                    if ($Results) { $XdDesktopComplete = $true }

                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                }
                #catch {
                #    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failed"
                #}
                #    }
            }

            if ($XdServer) {
                if ($XdServerComplete) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Skipping XdServer"
                } 
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing XdServer"
                    try {
                        $params = @{
                            Broker             = $Computer;
                            Workload           = 'Server';
                            #    SessionInfo     = $SessionInfo;
                            #    SessionDuration = $SessionDuration;
                            #    DurationLength  = $DurationLength;
                            WorkerHealth       = $WorkerHealth;
                            BootThreshold      = $BootThreshold;
                            LoadThreshold      = $LoadThreshold;
                            DiskSpaceThreshold = $DiskSpaceThreshold;
                            DiskQueueThreshold = $DiskQueueThreshold;
                            All                = $All
                        }
                        $Results += Test-XdWorkload @params
                        $XdServerComplete = $true

                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                    }
                    catch {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"
                    }
                }
            }

           
        }

        if ($Results.Count -gt 0) {
            return , $Results
        }
    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}