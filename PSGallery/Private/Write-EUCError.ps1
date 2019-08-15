function Write-EUCError {
    [CmdletBinding()]
    Param
    (   
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 

        [Parameter(Mandatory = $false)] 
        [Alias('LogPath')] 
        [string]$Path
    )
    
    Begin {
        # Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
    }

    Process {
        # Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] "
        if (($null -ne $Path) -and ("" -ne $Path)) {
            if (-Not (Test-Path $Path)) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Creating Log File: $Path"
                try {
                    New-Item $Path -Force -ItemType File | Out-Null
                }
                catch {
                    Write-Error "Unable to create log file at $Path"
                }
            }
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] > $Message"
            "[$(Get-Date)] $Message" | Out-File -FilePath $Path -Append
        }
        else {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No log path."
        }

        if ($EventLog) {
            if (![System.Diagnostics.EventLog]::SourceExists("EUCMonitoring")) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Adding EUCMonitoring Event Source."
                New-EventLog -LogName Application -Source "EUCMonitoring"
            }

            Write-EventLog -Logname "Application" -Source "EUCMonitoring" -EventID 17034 -EntryType Information -message "$Message" -category "17034"
        }
    }

    End {
        # Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}