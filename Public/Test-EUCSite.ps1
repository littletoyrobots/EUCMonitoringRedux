
function Test-EUCSeries {
    [CmdletBinding()]
    param (
        # Specifies the name of the series to run against. 
        [Parameter(ValueFromPipeline, Mandatory = $true)]
        [string]$SeriesName,

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
        [switch]$XdSessionInfo,

      
        # Specifies the level of detail being returned.  Basic by default. 
        [switch]$Advanced,

        [Parameter(ValueFromPipeline, Mandatory = $false)]
        [pscredential]$Credential
    )
    
    
    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] $($myinvocation.mycommand)"

    } #BEGIN
		
    Process { 
        Write-Verbose "[$(Get-Date) PROCESS] Description of what's occuring..."
        $Results = @()

        $XdDesktopComplete = $false
        $XdServerComplete = $false
        $XdSessionInfo = $false 

        foreach ($Computer in $ComputerName) {
            Write-Verbose "[$(Get-Date) PROCESS] Testing $Computer" 

            if ($XdDesktop) {
                if ($XdDesktopComplete) { 
                    Write-Verbose "[$(Get-Date) PROCESS] Skipping XdDesktop"
                } 
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] Testing XdDesktop"
                    try {
                        if ($Advanced) {
                            $TestMode = "advanced" 
                        }
                        else {
                            $TestMode = "basic"
                        }
                        $params = @{
                            Broker         = $Computer;
                            WorkerTestMode = $Testmode;
                            Workload       = 'desktop';
                            BootThreshold  = $BootThreshold;
                            HighLoad       = $HighLoad
                        }
                        $Results += Test-XdWorker @params
                        $XdDesktopComplete = $true
                        Write-Verbose "[$(Get-Date) PROCESS] Success"
                    }
                    catch {
                        Write-Verbose "[$(Get-Date) PROCESS] Failure"
                        $TestsDown += "XdDesktop"
                        $Errors += "Could not retrieve XdDesktop worker values"
                        # ! Maybe delay this until after for-each completes and Test for XdDesktopComplete = $true there. 
                    }
                }
            }

            if ($XdServer) {
                if ($XdServerComplete) {
                    Write-Verbose "[$(Get-Date) PROCESS] Skipping XdServer"
                } 
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] Testing XdServer"
                    try {
                        if ($Advanced) {
                            $TestMode = "advanced" 
                        }
                        else {
                            $TestMode = "basic"
                        }
                        $params = @{
                            Broker         = $Computer;
                            WorkerTestMode = $Testmode;
                            Workload       = 'server';
                            BootThreshold  = $BootThreshold;
                            HighLoad       = $HighLoad
                        }
                        $Results += Test-XdWorker @params
                        $XdServerComplete = $true
                        Write-Verbose "[$(Get-Date) PROCESS] Success"
                    }
                    catch {
                        Write-Verbose "[$(Get-Date) PROCESS] Failure"
                        $TestsDown += "XdServer"
                        $Errors += "Could not retrieve XdDesktop worker values"
                    }
                }
            }

            if ($XdSessionInfo) {
                if ($XdSessionInfoComplete) {
                    Write-Verbose "[$(Get-Date) PROCESS] Skipping XdSessionInfo"
                } 
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] Testing XdSessionInfo"
                    try {
                        $Results += Test-XdSessionInfo -Broker $Broker -Advanced $Advanced
                        $XdSessionInfoComplete = $true
                    } 
                    catch {
                        Write-Verbose "Failure $Computer - XdSessionInfo"
                        $Errors += "Could not get XdSessionInfo from broker $Broker"
                    }
                }
            }
        }

        if ($Results.Count -gt 0) {
            return $Results
        }
    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] $($myinvocation.mycommand)"
    }
}