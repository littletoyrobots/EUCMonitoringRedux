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
        [string]$ComputerName,

        [string[]]$LicenseType = ""
    )
    
    Begin { 
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Loading Citrix Licensing Powershell Snapin"
        $ctxsnap = add-pssnapin Citrix.Licensing.* -ErrorAction SilentlyContinue
        $ctxsnap = get-pssnapin Citrix.Licensing.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Citrix Licensing Powershell Snapin Load Failed"
            Return $false 
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Citrix Licensing SDK Snapin Loaded"
        }
    }

    Process {
        $Results = @()

        $TotalAvailable = -1
        $TotalIssued = -1
        $TotalLicenses = -1

        try { 
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting license certificate from $ComputerName"
         
            $Cert = Get-LicCertificate -AdminAddress $ComputerName
            
            if ("" -eq $LicenseType) {
                $LicenseType = "MPS", "XDT" # "MDT", "XDS" are deprecated. 
            }
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting all available XD licenses from $ComputerName"
            $LicResults = Get-LicInventory -AdminAddress $ComputerName -CertHash $cert.CertHash

            foreach ($Type in $LicenseType) { 
                $TotalAvailable = 0
                $TotalIssued = 0
                $TotalLicenses = 0

                foreach ($License in $LicResults) {
                    if ($License.LicenseProductName -eq $Type) {
                        $TotalAvailable += ($License.LicensesAvailable - $License.LicenseOverdraft) - $License.LicensesInUse
                        $TotalIssued += $License.LicensesInUse
                        $TotalLicenses += ($License.LicensesAvailable - $License.LicenseOverdraft)          
                    }
                }

                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Type, Available: $TotalAvailable, Issued: $TotalIssued, Total: $TotalLicenses"
                $Results += [PSCustomObject]@{
                    Series            = "EUCLicense"
                    Test              = "XdLicense"
                    Host              = $ComputerName
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
        }
        if ($Results.Count -gt 0) {
            return $Results
        }
    }

    End { 
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}

# Test-XdLicense -ComputerName "xen-license.wataugamc.org" -Verbose