function Test-EUCServer {
    <#
    .SYNOPSIS
    Short description

    .DESCRIPTION
    Long description

    .PARAMETER Series
    Parameter description

    .PARAMETER ComputerName
    Parameter description

    .PARAMETER Ports
    Parameter description

    .PARAMETER Services
    Parameter description

    .PARAMETER HTTPPath
    Parameter description

    .PARAMETER HTTPPort
    Parameter description

    .PARAMETER HTTPSPath
    Parameter description

    .PARAMETER HTTPSPort
    Parameter description

    .PARAMETER ValidCertPort
    Parameter description

    .PARAMETER Advanced
    Parameter description

    .PARAMETER Credential
    Currently a placeholder, but will be to run tests with different permissions.

    .EXAMPLE
    An example

    .NOTES
    General notes
    #>

    [CmdletBinding()]
    param (
        # Specifies the name of the series to run against.
        [Parameter(ValueFromPipeline, Mandatory = $true)]
        [string]$Series,

        # The names of the servers to run against.
        [Parameter(ValueFromPipeline, Mandatory = $true)]
        [Alias("Server")]
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

        [Parameter(ValueFromPipeline, Mandatory = $false)]
        [pscredential]$Credential,

        [string]$ErrorLog
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
        $WarningPreference = 'SilentlyContinue'
    }

    Process {
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Series: $Series"
        $Results = @()
        #       $Errors = @()


        foreach ($Computer in $ComputerName) {
            $Result = [PSCustomObject]@{
                Series = $Series
                Status = "UP"
                State  = 2
                Host   = $Computer
            }

            $ErrString = ""

            try {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing connection to $Computer"
                $Connected = (Test-NetConnection -ComputerName $Computer -ErrorAction Stop)
                if (-Not ($Connected.PingSucceeded)) {
                    if ($null -eq $Connected.RemoteAddress) {
                        throw "Name resolution of $($Connected.ComputerName) failed, no address."
                    }
                    elseif ($Connected.RemoteAddress -ne $ComputerName) {
                        throw "Name resolution of $($Connected.ComputerName) failed, dns mismatch"
                    }
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                    if ($ErrorLog) {
                        Write-EUCError -Path $ErrorLog "[$Series] $Computer DOWN"
                    }
                    $Result.Status = "DOWN"
                    $Result.State = 0
                    foreach ($Port in $Ports) {
                        $Result | Add-Member -MemberType NoteProperty -Name "Port$Port" -Value 0 #
                    }
                    foreach ($Service in $Services) {
                        $Result | Add-Member -MemberType NoteProperty -Name "$Service" -Value 0 #
                    }
                    foreach ($Path in $HTTPPath) {
                        $Result | Add-Member -MemberType NoteProperty -Name "HTTPPath_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -Value 0 #
                    }
                    foreach ($Path in $HTTPSPath) {
                        $Result | Add-Member -MemberType NoteProperty -Name "HTTPSPath_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -Value 0 #
                    }
                    foreach ($Port in $ValidCertPort) {
                        $Result | Add-Member -MemberType NoteProperty -Name "ValidCert_Port$($Port)" -Value 0 #
                    }
                }

                else {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                    # Ports
                    foreach ($Port in $Ports) {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing $Computer Port $Port"
                        if (Test-NetConnection $Computer -Port $Port -InformationLevel Quiet) {
                            $Result | Add-Member -MemberType NoteProperty -Name "Port$($Port)" -Value 1
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                        }
                        else {
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                            $Result | Add-Member -MemberType NoteProperty -Name "Port$($Port)" -Value 0
                            $Result.Status = "DEGRADED"
                            $Result.State = 1
                            $ErrString += "Port$Port "
                        }
                    }

                    # Windows Services
                    # We previously used Get-Service, but it ended up being too slow.  Now, after confirming
                    # that services need to be checked, we create a CimSession and check against that.
                    if ($null -ne $Services) {
                        [regex]$rx = "\d\.\d$"
                        $data = test-wsman $Computer -ErrorAction STOP
                        if ($rx.match($data.ProductVersion).value -eq '3.0') {
                            $Session = New-CimSession -ComputerName $ComputerName
                        }
                        else {
                            # We're older and need to revert to dcom
                            $opt = New-CimSessionOption -Protocol Dcom
                            $Session = New-CimSession -ComputerName $Computer -SessionOption $opt
                        }

                        foreach ($Service in $Services) {
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Testing $Computer Service $Service"

                            # $SvcStatus = (Get-Service -ErrorAction SilentlyContinue -ComputerName $Computer -Name $Service).Status
                            $SvcStatus = ($Session | Get-CimInstance win32_service -Filter "Name = `"$Service`"").State
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $SvcStatus"
                            if ("Running" -eq $SvcStatus) {
                                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                                $Result | Add-Member -MemberType NoteProperty -Name "$Service" -Value 1
                            }
                            else {
                                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                                $Result | Add-Member -MemberType NoteProperty -Name "$Service" -Value 0
                                $Result.Status = "DEGRADED"
                                $Result.State = 1
                                $ErrString += "$Service "
                            }
                        }
                    }

                    # URL Checking
                    foreach ($Path in $HTTPPath) {
                        $Url = "http://$($Computer):$($HTTPPort)$($HTTPPath)"
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] HTTP Test $url"

                        if (Test-Url $Url) {
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                            $Result | Add-Member -MemberType NoteProperty -Name "HTTPPath_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -Value 1
                        }
                        else {
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                            $Result.Status = "DEGRADED"
                            $Result.State = 1
                            $Result | Add-Member -MemberType NoteProperty -Name "HTTPPath_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -Value 0
                            $ErrString += "HTTPPath_$($HTTPPort)$($HTTPPath -replace '\W', '_') "
                        }
                    }

                    foreach ($Path in $HTTPSPath) {
                        $Url = "https://$($Computer):$($HTTPSPort)$($Path)"
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] HTTPS Test $Url"

                        if (Test-Url $Url) {
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                            $Result | Add-Member -MemberType NoteProperty -Name "HTTPSPath_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -Value 1
                        }
                        else {
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                            $Result.Status = "DEGRADED"
                            $Result.State = 1
                            $Result | Add-Member -MemberType NoteProperty -Name "HTTPSPath_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -Value 0
                            $ErrString += "HTTPSPath_$($HTTPSPort)$($HTTPSPath -replace '\W', '_') "
                        }
                    }


                    foreach ($Port in $ValidCertPort) {
                        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Valid Cert Port $Url"
                        if (Test-ValidCert -ComputerName $Computer -Port $Port) {
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Success"
                            $Result | Add-Member -MemberType NoteProperty -Name "ValidCert_Port$($Port)" -Value 1
                        }
                        else {
                            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Failure"
                            $Result.Status = "DEGRADED"
                            $Result.State = 1
                            $Result | Add-Member -MemberType NoteProperty -Name "ValidCert_Port$($Port)" -Value 0
                            $ErrString += "ValidCert_Port$($Port) "
                        }
                    }

                }

                if (($Result.Status -eq "DEGRADED") -and ($ErrorLog)) {
                    Write-EUCError -Path $ErrorLog "[$Series] $Computer - $ErrString"
                }

                $Results += $Result
            }
            catch {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Problem occured testing $Series - $Computer"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_"

                if ($ErrorLog) {
                    Write-EUCError -Path $ErrorLog "[$Series] Exception $_"
                }

                $ErrorState = -1
                $ErrorResult = [PSCustomObject]@{
                    Series = $Series
                    Status = "ERROR"
                    State  = $ErrorState
                    Host   = $Computer
                }

                foreach ($Port in $Ports) {
                    $ErrorResult | Add-Member -MemberType NoteProperty -Name "Port$Port" -Value $ErrorState
                }
                foreach ($Service in $Services) {
                    $ErrorResult | Add-Member -MemberType NoteProperty -Name "$Service" -Value $ErrorState
                }
                foreach ($Path in $HTTPPath) {
                    $ErrorResult | Add-Member -MemberType NoteProperty -Name "HTTPPath_$($HTTPPort)$($HTTPPath -replace '\W', '_')" -Value $ErrorState
                }
                foreach ($Path in $HTTPSPath) {
                    $ErrorResult | Add-Member -MemberType NoteProperty -Name "HTTPSPath_$($HTTPSPort)$($HTTPSPath -replace '\W', '_')" -Value $ErrorState
                }
                foreach ($Port in $ValidCertPort) {
                    $ErrorResult | Add-Member -MemberType NoteProperty -Name "ValidCert_Port$($Port)" -Value $ErrorState
                }
                $Results += $ErrorResult
            }

        }


        if ($Results.Count -gt 0) {
            return , $Results
        }
    }

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}

