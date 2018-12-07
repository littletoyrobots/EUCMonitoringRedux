function Test-EUCLicense {
    [CmdletBinding()]
    param (        # Will return session information based on site, catalog, delivery group, etc
        
        [string[]]$ComputerName,   

        [switch]$XdLicense,
        [string[]]$XdLicenseType = "",

        [switch]$RdsLicense,
        [string[]]$RdsLicenseType = ""
    )

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"

    } #BEGIN
		
    Process { 
        $Results = @()

        foreach ($Computer in $ComputerName) {
            if ($XdLicense) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Xd License Enabled"
                $Results += Get-XdLicense -ComputerName $Computer -LicenseType $XdLicenseType
            }
            if ($RdsLicense) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] RDS License Enabled"
                $Results += Get-RDSLicense -ComputerName $Computer -LicenseType $RdsLicenseType
            }
            # ...
        }

        if ($Results.Count -gt 0) {
            return $Results
        }

    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"

    }

}

. ../Private/Get-RDSLicense.ps1
. ../Private/Get-XdLicense.ps1
write-host "$(Get-Date)"
Test-EUCLicense -ComputerName "xa-ddc14.wataugamc.org" -XdLicense -RdsLicense -Verbose
write-host "$(get-date)"