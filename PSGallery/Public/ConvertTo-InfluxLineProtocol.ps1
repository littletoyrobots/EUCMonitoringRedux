Function ConvertTo-InfluxLineProtocol {

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
        if ($null -ne $Timestamp) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Using provided timestamp: $Timestamp"
            $IncludeTimeStamp = $true
        }
        elseif ($IncludeTimeStamp) {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] Fetching timestamp"
            $Timestamp = Get-InfluxTimestamp
        }
        else {
            Write-Verbose "[$(Get-Date) BEGIN  ] [$($myinvocation.mycommand)] No timestamp"
        }
    } #BEGIN

    Process {

        # We grab here so that all output will have the same associated timestamp.
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Converting results to Influx Line Protocol"

        foreach ($Obj in $InputObject) {
            # Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Converting obj $($Result.Host)"

            <#
            The format for Influx Line Protocol looks like
            SeriesName,tag1=tagvalue DataPoint1=datavalue timestamp

            I've decided to treat all strings as tags, everything else as data parameters.
            #>

            $ParamString = ""
            if ("" -ne $Series) { $SeriesString = $Series -replace "\W", "\$&" }
            else { $SeriesString = "$($Obj.Series)" -replace "\W", "\$&" }

            if ("" -eq $SeriesString) {
                throw "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Series Blank!"
            }

            $Obj.PSObject.Properties | ForEach-Object {
                if ($null -eq $_.Value) { }
                elseif ($_.Name -eq "Series") { } # We've already determined series above.
                # If its a string, we'll treat it as a tag
                elseif ($_.Value -is [string]) {
                    # So, this is a little tricky, but get rid of all non-alphanumeric, non-space characters
                    # and trim the remaining whitespace. Thank you GoDaddy certs
                    $SeriesString += ",$($_.Name)=$($_.Value.trim() -replace '/', '\/' -replace '=', '\=')"
                }
                else {
                    if ( $ParamString -eq "" ) { $ParamString = "$($_.Name)=$($_.Value)" }
                    else { $ParamString += ",$($_.Name)=$($_.Value)" }
                }
            }


            if (("" -ne $ParamString) -and ("" -ne $SeriesString)) {
                # Using \W instead of Regex::Escape() for special character inclusion.
                # $& refers to the match.  Changed mind on this.  Will mangle hostnames.

                $SeriesString = $SeriesString -replace " ", "\ "
                # $SeriesString = $SeriesString -replace "\W", "\$&"
                $ParamString = $ParamString -replace " ", "\ "
                # $ParamString = $ParamString -replace "\W", "\$&"


                if ($IncludeTimeStamp) { $PostParams = "$SeriesString $ParamString $timeStamp" }
                else { $PostParams = "$SeriesString $ParamString" }
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] $PostParams"

                Write-Output $PostParams
            }
            else {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] No additional test data"
            }

        }

    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] [$($myinvocation.mycommand)]"
    }
}




