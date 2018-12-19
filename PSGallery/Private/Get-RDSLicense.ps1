Function Get-RDSLicense {
   
    [cmdletbinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        
        [Parameter(ValueFromPipeline, Mandatory = $false)]
        [string[]]$LicenseType = ""
    )
    
    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"

    } #BEGIN
		
    Process { 
        $Results = @()

        foreach ($Computer in $ComputerName) {
            try { 
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting all available RDS licenses from $Computer"

                if ("" -eq $LicenseType) {
                    $LicenseType = Get-WmiObject Win32_TSLicenseKeyPack -ComputerName $Computer -ErrorAction Stop | `
                        Where-Object TypeAndModel -NotLike "Built-in TS Per Device Cal" | `
                        Select-Object -ExpandProperty TypeAndModel -Unique -ErrorAction Stop
                }

                foreach ($Type in $LicenseType) { 
                    $TotalAvailable = 0
                    $TotalIssued = 0
                    $TotalLicenses = 0

                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting license type $Type"
                    $LicResults = Get-WmiObject Win32_TSLicenseKeyPack -ComputerName $Computer -ErrorAction Stop | `
                        Where-Object TypeAndModel -eq $Type | `
                        Select-Object TypeAndModel, IssuedLicenses, AvailableLicenses, TotalLicenses -ErrorAction Stop

                    foreach ($License in $LicResults) {
                        $TotalIssued += $License.IssuedLicenses
                        $TotalAvailable += $License.AvailableLicenses
                        $TotalLicenses += $License.TotalLicenses
                    }
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Type, Available: $TotalAvailable, Issued: $TotalIssued, Total: $TotalLicenses"
                    $Results += [PSCustomObject]@{
                        Series            = "RdsLicense"
                        Host              = $Computer
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
                    Series            = "RdsLicense"
                    Host              = $Computer
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
    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}
