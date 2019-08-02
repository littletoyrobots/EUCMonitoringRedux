<#
.SYNOPSIS
Returns current timestamp in nanosecond format

.DESCRIPTION
Long description

.PARAMETER DateTime
Optional parameter if you want to specify a datetime

.EXAMPLE
Get-InfluxTimeStamp

.EXAMPLE
Get-InfluxTimeStamp -DateTime (Get-Date)

.NOTES
General notes
#>

function Get-InfluxTimestamp {
    [CmdletBinding()]
    Param (
        [datetime]$DateTime
    )

    Begin {

    } # Begin

    Process {
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Converting to Universal Time"

        if ($null -eq $DateTime) {
            $DateTime = Get-Date
        }

        $utcDate = $DateTime.ToUniversalTime()
        # Convert to a Unix time as a double, noticed that it gets all the seconds down in the decimal if cast as a double.
        $unixTime = [double]((Get-Date -Date $utcDate -UFormat %s))
        # multiply seconds to move the decimal place.
        $nano = $unixTime * 1000000000
        # casting as an int64 gets rid of the decimal and scientific notation.
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Returning $([int64]$nano)"
        return [int64]$nano
    } # Process

    End {
        # Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    } # End
}

# Get-InfluxTimestamp