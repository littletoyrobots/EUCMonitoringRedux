Function Get-DomainUser {
   
    [cmdletbinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$OU = "", #hard coded maybe OK
        [string]$Department
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