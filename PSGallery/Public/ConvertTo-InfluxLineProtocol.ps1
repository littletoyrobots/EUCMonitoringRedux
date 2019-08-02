Function ConvertTo-InfluxLineProtocol {
    <#
    .SYNOPSIS
    Takes any psobject, and returns a string in Influx Line Protocol.  Not good with objects that have arrays as
    properties currently.

    .DESCRIPTION
    This will take almost any object and return a string in Influx Line Protocol.  It's opinionated about how it
    does this, and will make any properties that are strings and turn them into tags.  Others will be added
    however powershell evaluates them in a string.  This can lead to mixed results with properties that contain
    arrays.  There are other implementations of this, but

    .PARAMETER InputObject
    Target object(s) of results you wish to convert into Influx LIne Protocol

    .PARAMETER Series
    Specifies the series name for the returned string.  Will override any Series properties of passed object.

    .PARAMETER Timestamp
    Specifies a influx line protocol supported timestamp, best tested with nanosecond format.

    .PARAMETER IncludeTimeStamp
    Will fetch current timestamp in nanosecond format and include it in returned string.

    .EXAMPLE
    ConvertTo-InfluxLineProtocol $MyObj -IncludeTimeStamp

    .EXAMPLE
    $Timestamp = Get-InfluxTimeStamp
    $MyObj | ConvertTo-InfluxLineProtocol -Timestamp $Timestamp

    .NOTES
    General notes
    #>
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [object[]]$InputObject,

        [Parameter(Mandatory = $false)]
        [string]$Series,

        [int64]$Timestamp,

        [switch]$IncludeTimeStamp
    )
    Begin {
        # Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)]"
        if (($null -ne $Timestamp) -or (0 -ne $Timestamp)) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Using provided timestamp: $Timestamp"
            $IncludeTimeStamp = $true
        }
        elseif ($IncludeTimeStamp) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Fetching timestamp"
            try { $Timestamp = Get-InfluxTimestamp }
            catch { Throw "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Error getting InfluxTimestamp" }
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] No timestamp"
        }
    } #BEGIN

    Process {
        # We grab here so that all output will have the same associated timestamp.
        # Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Converting results to Influx Line Protocol"

        foreach ($Obj in $InputObject) {
            # Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Converting obj $($Result.Host)"

            <#
            The format for Influx Line Protocol looks like
            SeriesName,tag1=tagvalue DataPoint1=datavalue timestamp

            I've decided to treat all strings as tags, everything else as data parameters.
            #>

            $ParamString = ""
            # If you specified the Series, use it, else look for a Series property in the object.
            # The \W matches any non-word character, \$& anchors all text matched
            #  "What ever !@#" -replace "\W", "\$&"   yields     "What\ ever\ \!\@\#"
            if ("" -ne $Series) { $SeriesString = $Series -replace "\W", "\$&" }
            else { $SeriesString = "$($Obj.Series)" -replace "\W", "\$&" }

            # If we can't find a specified Series name or a Series property, then we won't be able to convert
            # propertly.  Abort!
            if ("" -eq $SeriesString) {
                throw "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Series Blank!"
            }

            $Obj.PSObject.Properties | ForEach-Object {
                # Skip the empty values, they'll cause errors
                if ($null -eq $_.Value) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $($_.Name)'s value is null... skipping"
                }
                elseif ("" -eq $_.Value) {
                    Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $($_.Name)'s value is empty string... skipping"
                }

                # We've already determined series above..
                elseif ($_.Name -eq "Series") { }

                # If its a string, we'll treat it as a tag
                elseif ($_.Value -is [string]) {
                    # So, this is a little tricky, Thank you GoDaddy certs...
                    # And digicert, and wildcart certs.
                    $SeriesString += ",$($_.Name)=$($_.Value.trim() -replace ',', '\,' -replace '=', '\=' -replace '"', '\"')"
                }

                # Handles Integers, Floatin Points and Booleans just fine. Hopefully the ToString() of
                # whatever value you plays well.
                else {
                    if ( $ParamString -eq "" ) { $ParamString = "$($_.Name)=$($_.Value)" }
                    else { $ParamString += ",$($_.Name)=$($_.Value)" }
                }
            }


            if (("" -ne $ParamString) -and ("" -ne $SeriesString)) {
                # Was using \W instead of Regex::Escape() for special character inclusion.
                # $& refers to the match.  Changed mind on this.  Will mangle hostnames.

                $SeriesString = $SeriesString -replace " ", "\ "
                # $SeriesString = $SeriesString -replace "\W", "\$&"
                $ParamString = $ParamString -replace " ", "\ "
                # $ParamString = $ParamString -replace "\W", "\$&"


                if ($IncludeTimeStamp) { $PostParams = "$SeriesString $ParamString $timeStamp" }
                else { $PostParams = "$SeriesString $ParamString" }
                # Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $PostParams"

                Write-Output $PostParams
            }
            else {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No additional test data"
            }

        }

    } #PROCESS

    End {
        #    Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}




