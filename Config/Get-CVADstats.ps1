Import-Module EUCMonitoringRedux

# Copy and paste this per site.
$TimeStamp = Get-InfluxTimestamp

$CVADWorkloadParams = @{
    Broker        = "ddc1.mydomain.com", "ddc2.mydomain.com"; # Put your brokers here.

    #    SiteName         = ""
    #    ZoneName         = ""
    #    DesktopGroupName = ""
    #    CatalogName      = ""

    SingleSession = $true;
    MultiSession  = $true;
    ErrorLog      = $WorkloadErrorLog
}

Get-CVADworkload @CVADWorkloadParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
