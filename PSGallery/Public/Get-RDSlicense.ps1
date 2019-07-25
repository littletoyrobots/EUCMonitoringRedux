function Get-RDSLicense {
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

    .PARAMETER IgnoreBuiltIn


    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .EXAMPLE
    Get-RDSLicenseStat -ComputerName "rdslic1", "rdslic2"

    .EXAMPLE
    Get-RDSLicenseStat -ComputerName "rdslic1.domain.org" -LicenseType "RDS Per User CAL"

    #>

    [cmdletbinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        [Parameter(ValueFromPipeline, Mandatory = $false)]
        [string[]]$LicenseType = "",

        [Parameter(ValueFromPipeline)]
        [switch]$IgnoreBuiltIn,

        [Parameter(ValueFromPipeline)]
        [switch]$ErrorObj,

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias("LogPath")]
        [string]$ErrorLogPath
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Setting ErrorActionPreference"
        $PrevError = $ErrorActionPreference
        $ErrorActionPreference = "STOP"
    } #BEGIN

    Process {
        $Results = @()

        foreach ($Computer in $ComputerName) {
            try {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting all available RDS licenses from $Computer"

                # Check to see if we need to revert to Dcom for communication
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

                if (($null -eq $LicenseType) -or ("" -eq $LicenseType)) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Querying available licenses"

                    $LicenseType = $Session | Get-CimInstance -ClassName Win32_TSLicenseKeyPack -ErrorAction STOP | `
                        Where-Object TypeAndModel -NotLike "Built-in TS Per Device Cal" | `
                        Select-Object -ExpandProperty TypeAndModel -Unique -ErrorAction Stop
                }

                foreach ($Type in $LicenseType) {
                    $TotalAvailable = 0
                    $TotalIssued = 0
                    $TotalLicenses = 0

                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Getting license type $Type"

                    $LicResults = $Session | Get-CimInstance -ClassName Win32_TSLicenseKeyPack -ErrorAction Stop | `
                        Where-Object TypeAndModel -eq $Type | `
                        Select-Object TypeAndModel, IssuedLicenses, AvailableLicenses, TotalLicenses -ErrorAction Stop

                    foreach ($License in $LicResults) {
                        $TotalIssued += $License.IssuedLicenses
                        $TotalAvailable += $License.AvailableLicenses
                        $TotalLicenses += $License.TotalLicenses
                    }

                    if ($TotalIssued -gt $TotalLicenses) {
                        if ($ErrorLogPath) {
                            Write-EUCError -Message "[$(Get-Date)] [$($myinvocation.mycommand)] $Computer - License Overcommit of Type: $Type" -Path $ErrorLogPath
                        }
                        else {
                            Write-Verbose "[$(Get-Date)] [$($myinvocation.mycommand)] $Computer - License Overcommit of Type: $Type"
                        }
                    }

                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $Type, Available: $TotalAvailable, Issued: $TotalIssued, Total: $TotalLicenses"

                    $Results += [PSCustomObject]@{
                        PSTypeName        = 'EUCMonitoring.RDSlicense'
                        Series            = "RDSlicense"
                        Server            = $Computer
                        Type              = $Type
                        AvailableLicenses = $TotalAvailable
                        IssuedLicenses    = $TotalIssued
                        TotalLicenses     = $TotalLicenses
                    }
                }
            }
            catch {
                $ErrorActionPreference = $PrevError
                if ($ErrorLogPath) {
                    Write-EUCError -Message "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" -Path $ErrorLogPath
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
    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)] Returned $($Results.Count) value(s)"
    }
}
