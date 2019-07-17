function Send-EUCResultToInfluxDB {
    [CmdletBinding()]
    Param(
        [parameter()]$Protocol = "http",
        [parameter()]$InfluxDBServer = "localhost",
        [parameter()]$Port = 8086,
        [parameter()]$DB = "EUCMonitoring",
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$InfluxLineData
    )

    # We want all results to represent the same moment in time, even if that's not true for
    # collation reasons. This is why this step happens at the end.
    # Credit to Ryan Revord for providing workable examples here.
    # $timestamp = Get-InfluxTimestamp
    $InfluxURI = "$Protocol`://$Server`:$Port/write?db=$DB"
    try {
        Write-Verbose "[$(Get-Date) PROCESS] Pushing results to $InfluxURI"
        Invoke-RestMethod -Method "POST" -Uri $InfluxUri -Body $InfluxLineData
    }
    catch {
        Write-Verbose "[$(Get-Date) PROCESS] Failed"
        Write-EUCError
        throw $_
    }
}
