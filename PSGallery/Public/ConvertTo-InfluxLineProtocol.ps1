Function ConvertTo-InfluxLineProtocol {

    [CmdletBinding()]
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
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Converting obj $($Result.Host)"

            $ParamString = ""
            if ("" -ne $Series) { $SeriesString = $Series }
            else { $SeriesString = "$($Obj.Series)" }

            if ("" -eq $SeriesString) {
                Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] Series Blank!"
            }

            $Obj.PSObject.Properties | ForEach-Object {
                if ($null -eq $_.Value) { }
                elseif ($_.Name -eq "Series") { } # We've already determined series above.
                # If its a string, we'll treat it as a tag
                elseif ($_.Value -is [string]) {
                    # So, this is a little tricky, but get rid of all non-alphanumeric, non-space characters
                    # and trim the remaining whitespace. Thank you GoDaddy certs
                    $SeriesString += ",$($_.Name)=$(($_.Value -replace "[^W ]").trim())"
                }
                else {
                    if ( $ParamString -eq "" ) { $ParamString = "$($_.Name)=$($_.Value)" }
                    else { $ParamString += ",$($_.Name)=$($_.Value)" }
                }
            }


            if (("" -ne $ParamString) -and ("" -ne $SeriesString)) {
                $SeriesString = $SeriesString -replace " ", "\ "
                $ParamString = $ParamString -replace " ", "\ "

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




