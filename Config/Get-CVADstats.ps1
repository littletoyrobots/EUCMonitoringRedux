$BaseDir = "C:\Monitoring"

$TimeStamp = Get-InfluxTimestamp

Import-Module EUCMonitoringRedux

# Copy and paste this per site.
$CVADWorkloadParams = @{
    Broker        = "ddc1.mydomain.com", "ddc2.mydomain.com"; # Put your brokers here.

    # If you want to uncomment and fill these out, go for it.  If not, it will auto-discover
    # and return a value for each permutation with machines associated.
    #    SiteName         = ""
    #    ZoneName         = ""
    #    DesktopGroupName = ""
    #    CatalogName      = ""

    SingleSession = $true;
    MultiSession  = $true;
    ErrorLog      = $WorkloadErrorLog
}

Get-CVADworkload @CVADWorkloadParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
