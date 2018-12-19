
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
        [int]$BootThreshold = 7,
        [int]$HighLoad = 8000,

        # Will return session information based on site, catalog, delivery group, etc
        [switch]$SessionInfo,
        [switch]$WorkerHealthCount,

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
        $XdSessionInfo = $false 

        foreach ($Computer in $ComputerName) {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing $Computer" 

            if ($XdDesktop) {
                
                if ($XdDesktopComplete) { 
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Skipping XdDesktop"
                } 
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing XdDesktop"
                    try {       
                        $params = @{
                            Broker            = $Computer;
                            Workload          = 'desktop';
                            SessionInfo       = $SessionInfo;
                            WorkerHealthCount = $WorkerHealthCount;
                            BootThreshold     = $BootThreshold;
                            HighLoad          = $HighLoad;
                            $All              = $All
                        }
                        $Results += Test-XdWorker @params
                        $XdDesktopComplete = $true

                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                     
                    }
                    catch {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failed"
                    }
                }
            }

            if ($XdServer) {
                if ($XdServerComplete) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Skipping XdServer"
                } 
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing XdServer"
                    try {
                        $params = @{
                            Broker            = $Computer;
                            Workload          = 'server';
                            SessionInfo       = $SessionInfo;
                            WorkerHealthCount = $WorkerHealthCount;
                            BootThreshold     = $BootThreshold;
                            HighLoad          = $HighLoad;
                            All               = $All
                        }
                        $Results += Test-XdWorker @params
                        $XdServerComplete = $true
                        
                        if ($XdSessionInfo) {    
                            $Results += Test-XdSessionInfo -Broker $Broker -Advanced $Advanced
                        }
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                    }
                    catch {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                        #                $TestsDown += "XdServer"
                        #                $Errors += "Could not retrieve XdDesktop worker values"
                    }
                }
            }

           
        }

        if ($Results.Count -gt 0) {
            return $Results
        }
    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}