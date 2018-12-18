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


        [string[]]$HTTPPath,
        [int]$HTTPPort = 80,
        [string[]]$HTTPSPath,
        [int]$HTTPSPort = 443,
        [int[]]$ValidCertPort,
      
        
        # Specifies the level of detail being returned.  Basic by default. 
        [switch]$Advanced,

        [Parameter(ValueFromPipeline, Mandatory = $false)]
        [pscredential]$Credential
    )
    
    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
    }
    
    Process {
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Series"
        $Results = @()
        #       $Errors = @()


        foreach ($Computer in $ComputerName) {
            $Result = [PSCustomObject]@{
                Series      = $Series
                Status      = "UP"
                StatusValue = 2
                Host        = $Computer
            }

            try { 
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing connection to $Computer"
                if (-Not (Test-NetConnection -ComputerName $Computer -InformationLevel Quiet)) {
                    $Result.Status = "DOWN"
                    $Result.StatusValue = 0
                    foreach ($Port in $Ports) {
                        $Result | Add-Member -NotePropertyName "Port$Port" -NotePropertyValue 0 -TypeName int
                    }
                    foreach ($Service in $Services) {
                        $Result | Add-Member -NotePropertyName "$Service" -NotePropertyValue 0 -TypeName int
                    }
                    foreach ($Path in $HTTPPath) {
                        $Result | Add-Member -NotePropertyName "HTTPUrl_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -NotePropertyValue 0 -TypeName int
                    }
                    foreach ($Path in $HTTPSPath) {
                        $Result | Add-Member -NotePropertyName "HTTPUrl_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -NotePropertyValue 0 -TypeName int
                    }
                    foreach ($Port in $ValidCertPort) {
                        $Result | Add-Member -NotePropertyName "ValidCert_Port$($Port)" -NotePropertyValue 0 -TypeName int
                    }
                }

                # Ports
                foreach ($Port in $Ports) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing Port $Port"
                    if (Test-NetConnection $Computer -Port $Port -InformationLevel Quiet) {
                        $Result | Add-Member -NotePropertyName "Port$Port" -NotePropertyValue 1 -TypeName int
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                    }
                    else {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                        $Result | Add-Member -NotePropertyName "Port$Port" -NotePropertyValue 0 -TypeName int
                        $Result.Status = "DEGRADED"
                        $Result.StatusValue = 1
                        $Errors += "Port $Port closed"
                    }
                }

                # Windows Services
                foreach ($Service in $Services) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing Service $Service"

                    if ("Running" -eq (Get-Service -ErrorAction SilentlyContinue -ComputerName $ServerName -Name $ServiceName).Status) {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                        $Result | Add-Member -NotePropertyName "$Service" -NotePropertyValue 1 -TypeName int
                    }
                    else {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                        $Result | Add-Member -NotePropertyName "$Service" -NotePropertyValue 0 -TypeName int
                        $Result.Status = "DEGRADED"
                        $Result.StatusValue = 1
                        $Errors += "$Service not running"
                    }
                }

                # URL Checking
                foreach ($Path in $HTTPPath) {      
                    $Url = "http://$($Computer):$($HTTPPort)$($HTTPPath)"
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] HTTP Test $url"
                    
                    if (Test-Url $Url) {
                        $Result | Add-Member -NotePropertyName "HTTPPath_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -NotePropertyValue 1 -TypeName int
                    }
                    else {
                        $Result.Status = "DEGRADED"
                        $Result.StatusValue = 1
                        $Result | Add-Member -NotePropertyName "HTTPPath_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -NotePropertyValue 0 -TypeName int
                    }
                }

                foreach ($Path in $HTTPSPath) {      
                    $Url = "http://$($Computer):$($HTTPSPort)$($Path)"
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] HTTPS Test $Url"
                    
                    if (Test-Url $Url) {
                        $Result | Add-Member -NotePropertyName "HTTPSPath_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -NotePropertyValue 1 -TypeName int
                    }
                    else {
                        $Result.Status = "DEGRADED"
                        $Result.StatusValue = 1
                        $Result | Add-Member -NotePropertyName "HTTPSPath_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -NotePropertyValue 0 -TypeName int
                    }
                }


                foreach ($Port in $ValidCertPort) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Valid Cert Port $Url"
                    if (Test-ValidCert -ComputerName $ComputerName -Port $Port) {
                        $Result | Add-Member -NotePropertyName "ValidCert_Port$($Port)" -NotePropertyValue 1 -TypeName int
                    }
                    else {
                        $Result.Status = "DEGRADED"
                        $Result.StatusValue = 1
                        $Result | Add-Member -NotePropertyName "ValidCert_Port$($Port)" -NotePropertyValue 0 -TypeName int
                    }
                }                
            }
            catch {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Problem occured testing $Series"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"

                $Result.Status = "ERROR"
                $Result.StatusValue = -1
                foreach ($Port in $Ports) {
                    $Result | Add-Member -NotePropertyName "Port$Port" -NotePropertyValue -1 -TypeName int
                }
                foreach ($Service in $Services) {
                    $Result | Add-Member -NotePropertyName "$Service" -NotePropertyValue -1 -TypeName int
                }
                foreach ($Path in $HTTPPath) {
                    $Result | Add-Member -NotePropertyName "HTTPUrl_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -NotePropertyValue -1 -TypeName int
                }
                foreach ($Path in $HTTPSPath) {
                    $Result | Add-Member -NotePropertyName "HTTPUrl_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -NotePropertyValue -1 -TypeName int
                }
                foreach ($Port in $ValidCertPort) {
                    $Result | Add-Member -NotePropertyName "ValidCert_Port$($Port)" -NotePropertyValue -1 -TypeName int
                }

            }
            $Results += $Result
        }


        if ($Results.Count -gt 0) {
            return $Results
        }
    }
    
    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}

