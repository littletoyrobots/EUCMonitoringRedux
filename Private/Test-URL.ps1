function Test-URL {
    <#
.SYNOPSIS
    Tests connectivity to a URL
.DESCRIPTION
    Tests connectivity to a URL
.PARAMETER Url
    The URL to be tested
.NOTES
    Current Version:        1.0
    Creation Date:          07/02/2018
.CHANGE CONTROL
    Name                    Version         Date                Change Detail
    David Brett             1.0             07/02/2018          Function Creation
    Adam Yarborough         1.1             05/06/2018          Change to true/false
    David Brett             1.2             16/06/2018          Updated Function Parameters
    Adam Yarborough         1.3             30/11/2018          Rearrange and 
.EXAMPLE
    None Required
#>

    [CmdletBinding()]
    Param
    (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$Url
    )

    Begin { 
        Write-Verbose "[$(Get-Date) BEGIN  ] Starting $($myinvocation.mycommand)"
        Write-Verbose "[$(Get-Date) BEGIN  ] Setting Security Protocol"
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    } #Begin

    Process {
        Write-Verbose "[$(Get-Date) PROCESS] Starting $($myinvocation.mycommand)"
        Write-Verbose "[$(Get-Date) PROCESS] Connecting to URL: $URL"
        $HTTP_Status = 400

        # Setup Request Object
        $HTTP_Request = [System.Net.WebRequest]::Create("$URL")

        #Check for Response
        try {
            $HTTP_Response = $HTTP_Request.GetResponse() 
        }
        catch {
            Write-Verbose "[$(Get-Date) PROCESS] Failure"
            return $false
            break
        }
    
        #Extract Response Code
        $HTTP_Status = [int]$HTTP_Response.StatusCode
	
        If ($HTTP_Status -eq 200) { 
            Write-Verbose "[$(Get-Date) PROCESS] Status 200 - OK"
            $HTTP_Response.Close()
            return $true 
        }
        else {
            Write-Verbose "[$(Get-Date) PROCESS] Status $HTTP_Status"
            $HTTP_Response.Close()
            return $false
        }
    } # Process

    End { 
        Write-Verbose "[$(Get-Date) END    ] Ending $($myinvocation.mycommand)"
    } # End
}
