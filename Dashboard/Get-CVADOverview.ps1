$BaseDir = "C:\Monitoring"

# $VerbosePreference = 'SilentlyContinue'
$VerbosePreference = 'Continue'

Import-Module (Join-Path -Path $BaseDir -ChildPath "EUCMonitoringRedux-master\PSGallery\EUCMonitoringRedux.psd1")


$CVADSites = @( # Keep the prepended comma so that the sites work as expected.
    , ("ddc1.mydomain.com", "ddc2.mydomain.com") # DDCs in Site 1
    , ("ddc3.mydomain.com", "ddc4.mydomain.com")  # DDCs in Site 2
)

$WorkloadErrorLog = Join-Path $BaseDir -ChildPath "Workload-Errors.txt"
$WorkloadErrorHistory = Join-Path -Path $BaseDir -ChildPath "Workload-ErrorHistory.txt"

if (Test-Path $WorkloadErrorLog) {
    Remove-Item -Path $ADCErrorLog -Force
}

$TimeStamp = Get-InfluxTimestamp

foreach ($Site in $CVADSites) {
    $CVADWorkloadParams = @{
        Broker        = $Site

        # If you want to uncomment and fill these out, go for it.  If not, it will auto-discover
        # and return a value for each permutation with machines associated.  Each will allow for
        # multiple values
        #    SiteName         = ""
        #    ZoneName         = ""
        #    DesktopGroupName = ""
        #    CatalogName      = ""

        SingleSession = $true
        MultiSession  = $true
        ErrorLog      = $WorkloadErrorLog
    }

    Get-CVADworkload @CVADWorkloadParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}


# If this file exists, we have errors, currently.
if (Test-Path $WorkloadErrorLog) {
    Get-Content $WorkloadErrorLog | Out-File $WorkloadErrorHistory -Append

    # Maybe if you care, add something to send one or both log files.
    <#
    $MailParams = @{
        To         = "sysops@domain.com"
        From       = "EUCMonitoring@domain.com"
        Subject    = "Workload Errors"
        Body       = (Get-Content $ADCErrorLog)
        SmtpServer = "smtp.domain.com"
        Attachments = $WorkloadErrorHistory
    }
    Send-MailMessage @MailParams
    #>
}