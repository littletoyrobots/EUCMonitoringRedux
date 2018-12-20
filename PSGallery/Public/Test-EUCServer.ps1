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
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Series: $Series"
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
                $Connected = (Test-NetConnection -ComputerName $Computer -ErrorAction Stop)
                if (-Not ($Connected.PingSucceeded)) {
                    if ($null -eq $Connected.RemoteAddress) {
                        throw "Name resolution of $($Connected.ComputerName) failed"
                    }
                    $Result.Status = "DOWN"
                    $Result.StatusValue = 0
                    foreach ($Port in $Ports) {
                        $Result | Add-Member -NotePropertyName "Port$Port" -NotePropertyValue 0 # 
                    }
                    foreach ($Service in $Services) {
                        $Result | Add-Member -NotePropertyName "$Service" -NotePropertyValue 0 # 
                    }
                    foreach ($Path in $HTTPPath) {
                        $Result | Add-Member -NotePropertyName "HTTPUrl_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -NotePropertyValue 0 #
                    }
                    foreach ($Path in $HTTPSPath) {
                        $Result | Add-Member -NotePropertyName "HTTPUrl_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -NotePropertyValue 0 # 
                    }
                    foreach ($Port in $ValidCertPort) {
                        $Result | Add-Member -NotePropertyName "ValidCert_Port$($Port)" -NotePropertyValue 0 # 
                    }
                }
                
                else {
                    # Ports
                    foreach ($Port in $Ports) {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing $Computer Port $Port"
                        if (Test-NetConnection $Computer -Port $Port -InformationLevel Quiet) {
                            $Result | Add-Member -NotePropertyName "Port$Port" -NotePropertyValue 1 
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                        }
                        else {
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                            $Result | Add-Member -NotePropertyName "Port$Port" -NotePropertyValue 0 
                            $Result.Status = "DEGRADED"
                            $Result.StatusValue = 1
                            $Errors += "Port $Port closed"
                        }
                    }

                    # Windows Services
                    foreach ($Service in $Services) {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing $Computer Service $Service"

                        if ("Running" -eq (Get-Service -ErrorAction SilentlyContinue -ComputerName $Computer -Name $ServiceName).Status) {
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                            $Result | Add-Member -NotePropertyName "$Service" -NotePropertyValue 1 
                        }
                        else {
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                            $Result | Add-Member -NotePropertyName "$Service" -NotePropertyValue 0 
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
                            $Result | Add-Member -NotePropertyName "HTTPPath_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -NotePropertyValue 1 
                        }
                        else {
                            $Result.Status = "DEGRADED"
                            $Result.StatusValue = 1
                            $Result | Add-Member -NotePropertyName "HTTPPath_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -NotePropertyValue 0 
                        }
                    }

                    foreach ($Path in $HTTPSPath) {      
                        $Url = "https://$($Computer):$($HTTPSPort)$($Path)"
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] HTTPS Test $Url"
                    
                        if (Test-Url $Url) {
                            $Result | Add-Member -NotePropertyName "HTTPSPath_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -NotePropertyValue 1 
                        }
                        else {
                            $Result.Status = "DEGRADED"
                            $Result.StatusValue = 1
                            $Result | Add-Member -NotePropertyName "HTTPSPath_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -NotePropertyValue 0 
                        }
                    }


                    foreach ($Port in $ValidCertPort) {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Valid Cert Port $Url"
                        if (Test-ValidCert -ComputerName $Computer -Port $Port) {
                            $Result | Add-Member -NotePropertyName "ValidCert_Port$($Port)" -NotePropertyValue 1 
                        }
                        else {
                            $Result.Status = "DEGRADED"
                            $Result.StatusValue = 1
                            $Result | Add-Member -NotePropertyName "ValidCert_Port$($Port)" -NotePropertyValue 0 
                        }
                    }  
                }              
            }
            catch {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Problem occured testing $Series - $Computer"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"

                $Result.Status = "ERROR"
                $Result.StatusValue = -1
                foreach ($Port in $Ports) {
                    $Result | Add-Member -NotePropertyName "Port$Port" -NotePropertyValue -1 #
                }
                foreach ($Service in $Services) {
                    $Result | Add-Member -NotePropertyName "$Service" -NotePropertyValue -1 # 
                }
                foreach ($Path in $HTTPPath) {
                    $Result | Add-Member -NotePropertyName "HTTPUrl_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -NotePropertyValue -1 #
                }
                foreach ($Path in $HTTPSPath) {
                    $Result | Add-Member -NotePropertyName "HTTPUrl_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -NotePropertyValue -1 # 
                }
                foreach ($Port in $ValidCertPort) {
                    $Result | Add-Member -NotePropertyName "ValidCert_Port$($Port)" -NotePropertyValue -1 # 
                }

            }
            $Results += $Result
        }


        if ($Results.Count -gt 0) {
            return , $Results
        }
    }
    
    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}

