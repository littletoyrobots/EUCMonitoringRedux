function Test-EUCLicense {
    [CmdletBinding()]
    param (        
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

        
        if ($XdLicense) {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Xd License Enabled"
            $Results += Get-XdLicense -ComputerName $ComputerName -LicenseType $XdLicenseType
        }
        if ($RdsLicense) {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] RDS License Enabled"
            $Results += Get-RDSLicense -ComputerName $ComputerName -LicenseType $RdsLicenseType
        }
        # ...
        

        if ($Results.Count -gt 0) {
            return $Results
        }

    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }

}

