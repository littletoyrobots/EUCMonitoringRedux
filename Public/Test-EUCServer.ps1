function Test-EUCServer {
    [CmdletBinding()]
    param (
        # Specifies the name of the series to run against. 
        [Parameter(ValueFromPipeline, Mandatory = $true)]
        [string]$Series,

        # The names of the servers to run against. 
        [Parameter(ValueFromPipeline, Mandatory = $true)]
        [string[]]$ComputerName,
        
        # The ports you want to test against the Servers.
        [Parameter(ValueFromPipeline, Mandatory = $false)]
        [int[]]$Ports,

        # The services you want to make sure are running on the Servers
        [Parameter(ValueFromPipeline, Mandatory = $false)]
        [string[]]$Services,


        [string[]]$HTTPUrl,
        [string[]]$HTTPSUrl,
        [int[]]$ValidCertPort,
      
        
        # Specifies the level of detail being returned.  Basic by default. 
        [switch]$Advanced,

        [Parameter(ValueFromPipeline, Mandatory = $false)]
        [pscredential]$Credential
    )
    
    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] $($myinvocation.mycommand)"
    }
    
    Process {
        Write-Verbose "[$(Get-Date) PROCESS] Initializing variables "
        $Results = @()
        $Errors = @()


        foreach ($Computer in $ComputerName) {
            $Result = [PSCustomObject]@{
                Status      = "UP"
                StatusValue = 1
            }
            $State = "UP"
            $PortsUp = @()
            $PortsDown = @()
            $ServicesUp = @()
            $ServicesDown = @()
            $TestsUp = @()
            $TestsDown = @()
            $TestData = @()

            if (-Not (Test-NetConnection -ComputerName $Computer -InformationLevel Quiet)) {
                $State = "DOWN"
                $PortsDown += $Ports
                $ServicesDown += $Services

            }

            # Ports
            foreach ($Port in $Ports) {
                Write-Verbose "[$(Get-Date) PROCESS] Testing $Computer - Port $Port"
                if ( Test-NetConnection $Computer -Port $Port -InformationLevel Quiet ) {
                    Write-Verbose "[$(Get-Date) PROCESS] Success"
                    $PortsUp += $Port
                }
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] Failure"
                    $State = "DEGRADED"
                    $PortsDown += $Port
                    $Errors += "$Port closed"
                }
            }

            # Windows Services
            foreach ($Service in $Services) {
                Write-Verbose "[$(Get-Date) PROCESS] Testing $Computer - Service $Service"
                $CurrentServiceStatus = Test-Service $Computer $Service
                If ($CurrentServiceStatus -eq "Running") {
                    Write-Verbose "[$(Get-Date) PROCESS] Success"
                    $ServicesUp += $Service
                }
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] Failure"
                    $State = "DEGRADED"
                    $ServicesDown += $Service
                    $Errors += "$Service not running"
                }
            }


            foreach ($url in $HTTPUrl) {
                try { }
                catch {
                    Write-Verbose "Error connecting to $url"
                    Write-Verbose $_ 
                }
            }

            foreach ($url in $HTTPSUrl) {
                try {

                }
                catch {
                    Write-Verbose "Error connecting to $url"
                    Write-Verbose $_ 
                }
            }

            foreach ($Port in $ValidCertPort) {
                try {}
                catch {}
            }
        }


    }
    
    End {
        Write-Verbose "[$(Get-Date) END    ] $($myinvocation.mycommand)"
    }
}

Test-EUCSeries -Series "DDC" -ComputerName "xa-ddc1.wataugamc.org" -Ports 80, 443 -Verbose