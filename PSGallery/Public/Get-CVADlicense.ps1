Function Get-CVADlicense {
    <#
    .SYNOPSIS
    Returns some simple stats on a License Server

    .DESCRIPTION
    Returns some simple stats on a License Server

    .PARAMETER ComputerName
    Target License server to grab information from.

    .PARAMETER LicenseType
    Citrix License Type, commonly XDT / MPS

    #>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        [parameter(ValueFromPipeline = $true)]
        [string[]]$LicenseType,

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias("LogPath")]
        [string]$ErrorLog
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Loading Citrix.Licensing Powershell Snapins"
        $ctxsnap = Get-PSSnapin -Registered Citrix.Licensing.* -ErrorAction SilentlyContinue | Add-PSSnapin -PassThru

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Citrix.Licensing Powershell Snapins Load Failed"
            Throw "Unable to load Citrix.Licensing Powershell Snapins"
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Citrix.Licensing Powershell Snapins Loaded"
        }
    }

    Process {
        $Results = @()

        foreach ($Computer in $ComputerName) {
            try {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting license certificate from $Computer"

                $Cert = Get-LicCertificate -AdminAddress $Computer -ErrorAction STOP

                if (($null -eq $LicenseType) -or ("" -eq $LicenseType)) {
                    $LicenseType = "MPS", "XDT" # "MDT", "XDS" are deprecated.
                }
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting all available Citrix licenses from $Computer"
                $LicResults = Get-LicInventory -AdminAddress $Computer -CertHash $cert.CertHash

                foreach ($Type in $LicenseType) {

                    $TotalAvailable = 0
                    $TotalIssued = 0
                    $TotalLicenses = 0

                    #Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting license type $Type "
                    foreach ($License in $LicResults) {
                        if ($License.LicenseProductName -eq $Type) {
                            $TotalAvailable += ($License.LicensesAvailable - $License.LicenseOverdraft) - $License.LicensesInUse
                            $TotalIssued += $License.LicensesInUse
                            $TotalLicenses += ($License.LicensesAvailable - $License.LicenseOverdraft)
                        }
                    }

                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Type: $Type, Available: $TotalAvailable, Issued: $TotalIssued, Total: $TotalLicenses"

                    $Results += [PSCustomObject]@{
                        PSTypeName        = 'EUCMonitoring.CVADlicense'
                        Series            = "CVADLicense"
                        Server            = $Computer
                        Type              = $Type
                        AvailableLicenses = $TotalAvailable
                        IssuedLicenses    = $TotalIssued
                        TotalLicenses     = $TotalLicenses
                    }
                }

            }
            catch [System.InvalidOperationException] {
                if ($ErrorLog) {
                   Write-EUCError -Message "[$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message) - Ensure Citrix Licensing WMI service started" -Path $ErrorLog
                }
                else {
                    Write-Verbose "[$(Get-Date)] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message) - Ensure Citrix Licensing WMI service started"
                }
                throw $_
            }
            catch {
                if ($ErrorLog) {
                    Write-EUCError -Message "[$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" -Path $ErrorLog
                }
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)"
                }
                throw $_
            }

        }

        if ($Results.Count -gt 0) {
            return $Results
        }
    }

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Returned $($Results.Count) value(s)"
    }
}

# Test-XdLicense -ComputerName "xen-license" -Verbose