Function Get-XdLicense {
    <#
    .SYNOPSIS
Returns some simple stats on a License Server
    
    .DESCRIPTION
Returns some simple stats on a License Server
    
    .PARAMETER ComputerName
Target License server to grab information from.
    .PARAMETER LicenseType
Citrix License Type, commonly XDT / MPS

    
    .NOTES
    .CHANGE CONTROL
    Name                    Version         Date                Change Detail
    Adam Yarborough         1.0             20/06/2018          Function Creation
    #>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,
        [string[]]$LicenseType = ""
    )
    
    Begin { 
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Loading Citrix Licensing Powershell Snapin"
        $ctxsnap = add-pssnapin Citrix.Licensing.* -ErrorAction SilentlyContinue
        $ctxsnap = get-pssnapin Citrix.Licensing.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Citrix Licensing Powershell Snapin Load Failed"
            Write-Error "Unable to load Citrix Licensing Powershell Snapin "
            Return
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Citrix Licensing SDK Snapin Loaded"
        }
    }

    Process {
        $Results = @()

        foreach ($Computer in $ComputerName) {
            try { 
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting license certificate from $Computer"
         
                $Cert = Get-LicCertificate -AdminAddress $Computer
            
                if ("" -eq $LicenseType) {
                    $LicenseType = "MPS", "XDT" # "MDT", "XDS" are deprecated. 
                }
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting all available XD licenses from $Computer"
                $LicResults = Get-LicInventory -AdminAddress $Computer -CertHash $cert.CertHash
                    
                foreach ($Type in $LicenseType) { 
                    $Status = "UP"
                    $State = 2
                    $TotalAvailable = 0
                    $TotalIssued = 0
                    $TotalLicenses = 0

                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting license type $Type "
                    foreach ($License in $LicResults) {
                        if ($License.LicenseProductName -eq $Type) {
                            $TotalAvailable += ($License.LicensesAvailable - $License.LicenseOverdraft) - $License.LicensesInUse
                            $TotalIssued += $License.LicensesInUse
                            $TotalLicenses += ($License.LicensesAvailable - $License.LicenseOverdraft)          
                        }
                    }

                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Type, Available: $TotalAvailable, Issued: $TotalIssued, Total: $TotalLicenses"
                    $Results += [PSCustomObject]@{
                        Series            = "XdLicense"
                        Host              = $Computer
                        Status            = $Status
                        State             = $State
                        Type              = $Type    
                        AvailableLicenses = $TotalAvailable
                        IssuedLicenses    = $TotalIssued
                        TotalLicenses     = $TotalLicenses
                    }
                }

          
            }
            catch { 
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Error getting XD license information"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_" 
                $Results += [PSCustomObject]@{
                    Series            = "XdLicense"
                    Host              = $Computer
                    Status            = "Error"
                    State             = -1
                    Type              = "Error"    
                    AvailableLicenses = -1
                    IssuedLicenses    = -1
                    TotalLicenses     = -1
                }
            }

        }
        
        if ($Results.Count -gt 0) {
            return $Results
        }
    }

    End { 
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}

# Test-XdLicense -ComputerName "xen-license" -Verbose