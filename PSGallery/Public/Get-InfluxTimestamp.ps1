function Get-InfluxTimestamp {
    <#
    .SYNOPSIS
    Short description

    .DESCRIPTION
    Long description

    .EXAMPLE
    $timestamp = Get-InfluxTimeStamp

    .NOTES
    General notes
    #>

    [CmdletBinding()]
    Param ()

    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] $($myinvocation.mycommand)"
    } # Begin

    Process {
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Converting to Universal Time"

        $DateTime = Get-Date
        $utcDate = $DateTime.ToUniversalTime()
        # Convert to a Unix time as a double, noticed that it gets all the seconds down in the decimal if cast as a double.
        $unixTime = [double]((Get-Date -Date $utcDate -UFormat %s))
        # multiply seconds to move the decimal place.
        $nano = $unixTime * 1000000000
        #cast as a int64 gets rid of the decimal and scientific notation.
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Returning $([int64]$nano)"
        return [int64]$nano
    } # Process

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    } # End
}

# Get-InfluxTimestamp