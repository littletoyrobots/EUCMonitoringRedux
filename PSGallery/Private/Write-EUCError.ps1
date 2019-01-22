function Write-EUCError {
    [CmdletBinding()]
    Param
    (   
        [Parameter(Mandatory = $true, 
            ValueFromPipelineByPropertyName = $true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 

        [Parameter(Mandatory = $false)] 
        [Alias('LogPath')] 
        [string]$Path
    )
    
    begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
    }

    process {
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] "

        if ($null -ne $Path) {
            if (-Not (Test-Path $Path)) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Creating Log File: $Path"
            }
            $Message | Out-File -FilePath $Path -Append
        }
        else {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No log path."
        }
    }

    end {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}