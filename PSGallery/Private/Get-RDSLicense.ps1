Function Get-RDSLicense {
    <#
    .SYNOPSIS
    Returns RDS Licensing info
    
    .DESCRIPTION
    Returns 
    
    .PARAMETER ComputerName
    Gets the TSLicenseKeyPack on the specified computers. 

    Type the NetBIOS name, an IP Address, or a fully qualified domain name (FQDN) of a remote computer.
    
    .PARAMETER LicenseType
    The 'TypeAndModel' of the license pack.  If specified, will return only the licenses of that TypeAndModel.
    If unspecified, includes all but "Built-in TS Per Device Cal"
    
    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .EXAMPLE
    Get-RDSLicense -ComputerName "rdslic1", "rdslic2"

    .EXAMPLE
    Get-RDSLicense -ComputerName "rdslic1.domain.org" -LicenseType "RDS Per User CAL"
    
    .NOTES
    Current Version:    1.0
    Creation Date:      2019/01/01

    .CHANGE CONTROL
    Name                 Version         Date            Change Detail
    Adam Yarborough      1.0             2019/01/01      Function Creation
    #>
    
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
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Querying available licenses"
                    $LicenseType = Get-CimInstance -ClassName  Win32_TSLicenseKeyPack -ComputerName $Computer -ErrorAction Stop | `
                        Where-Object TypeAndModel -NotLike "Built-in TS Per Device Cal" | `
                        Select-Object -ExpandProperty TypeAndModel -Unique -ErrorAction Stop
                }

                foreach ($Type in $LicenseType) { 
                    $Status = "UP"
                    $State = 2
                    $TotalAvailable = 0
                    $TotalIssued = 0
                    $TotalLicenses = 0
                    
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting license type $Type"
                    $LicResults = Get-CimInstance -ClassName Win32_TSLicenseKeyPack -ComputerName $Computer -ErrorAction Stop | `
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
                        Status            = $Status
                        State             = $State
                        AvailableLicenses = $TotalAvailable
                        IssuedLicenses    = $TotalIssued
                        TotalLicenses     = $TotalLicenses
                    }
                }
            } 
            catch {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Error getting RDS license information"
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $_" 

                # Write-EUCError -Path $ErrorLog "[$(Get-Date)] [RdsLicense] Exception: $_"
                $Results += [PSCustomObject]@{
                    Series            = "RdsLicense"
                    Host              = $Computer
                    Type              = "ERROR"
                    Status            = "ERROR"
                    State             = -1
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
