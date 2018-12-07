Function Get-RDSLicense {
   
    [cmdletbinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        
        [Parameter(ValueFromPipeline, Mandatory = $false)]
        [string[]]$LicenseType = ""
    )
    
    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] $($myinvocation.mycommand)"

    } #BEGIN
		
    Process { 
        $Results = @()

        $TotalAvailable = -1
        $TotalIssued = -1
        $TotalLicenses = -1

        try { 
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting all available RDS licenses from $ComputerName"

            if ("" -eq $LicenseType) {
                $LicenseType = Get-WmiObject Win32_TSLicenseKeyPack -ComputerName $ComputerName -ErrorAction Stop | `
                    Where-Object TypeAndModel -NotLike "Built-in TS Per Device Cal" | `
                    Select-Object -ExpandProperty TypeAndModel -Unique -ErrorAction Stop
            }

            foreach ($Type in $LicenseType) { 
                $TotalAvailable = 0
                $TotalIssued = 0
                $TotalLicenses = 0

                $LicResults = Get-WmiObject Win32_TSLicenseKeyPack -ComputerName $ComputerName -ErrorAction Stop | `
                    Where-Object TypeAndModel -eq $Type | `
                    Select-Object TypeAndModel, IssuedLicenses, AvailableLicenses, TotalLicenses -ErrorAction Stop
                
                foreach ($License in $LicResults) {
                    $TotalIssued += $License.IssuedLicenses
                    $TotalAvailable += $License.AvailableLicenses
                    $TotalLicenses += $License.TotalLicenses
                }
                $Results += [PSCustomObject]@{
                    Series            = "EUCLicense"
                    Test              = "RdsLicense"
                    Host              = $ComputerName
                    Type              = $Type
                    AvailableLicenses = $TotalAvailable
                    IssuedLicenses    = $TotalIssued
                    TotalLicenses     = $TotalLicenses
                }
            }
        } 
        catch {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Error getting RDS license information"
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_" 
            $Results += [PSCustomObject]@{
                Series            = "EUCLicense"
                Test              = "RdsLicense"
                Host              = $ComputerName
                Type              = $Type
                AvailableLicenses = $TotalAvailable
                IssuedLicenses    = $TotalIssued
                TotalLicenses     = $TotalLicenses
            }
        }

        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Type, Available: $TotalAvailable, Issued: $TotalIssued, Total: $TotalLicenses"
        

        if ($Results.Count -gt 0) {
            return $Results
        }
    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] $($myinvocation.mycommand)"
    }
}

# Test-RDSLicense -ComputerName "keymgr.wataugamc.org" -LicenseType "RDS Per User CAL" -Verbose