Function Get-TheThing {
   
    [cmdletbinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName
    )
    
    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] $($myinvocation.mycommand)"

    } #BEGIN
		
    Process { 
        Write-Verbose "[$(Get-Date) PROCESS] Description of what's occuring..."
        
    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] $($myinvocation.mycommand)"

    }
}