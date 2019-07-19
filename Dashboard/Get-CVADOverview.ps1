$BaseDir = "C:\Monitoring"

# Keep this Verbose while testing, change to SilentlyContinue when complete.
# $VerbosePreference = 'SilentlyContinue'
$VerbosePreference = 'Continue'

# Assume the easy-install.
Import-Module (Join-Path -Path $BaseDir -ChildPath "EUCMonitoringRedux-master\PSGallery\EUCMonitoringRedux.psd1")
# Import-Module EUCMonitoringRedux
Import-Module Citrix.Broker.Admin.V2
Import-Module Citrix.Configuration.Admin.V2

<# Citrix Cloud?
Obtain a Citrix Cloud automation credential as follows:

Login to https://citrix.cloud.com/
Navigate to "Identity and Access Management".
Click "API Access".
Enter a name for Secure Client and click Create Client.
Once Secure Client is created, download Secure Client Credentials file (ie. downloaded to C:\Monitoring)
Note the Customer ID located i
#>
# Set-XDCredentials -CustomerId "%Customer ID%" -SecureClientFile "C:\Monitoring\secureclient.csv" -ProfileType CloudApi -StoreAs "CloudAdmin"

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
    Try {
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
    catch {
        Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)"
        Write-Verbose "[$(Get-Date)] [$($myinvocation.mycommand)] Exiting uncleanly."
        "[$(Get-Date)] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" | Out-File $WorkloadErrorLog -Append
        "[$(Get-Date)] [$($myinvocation.mycommand)] Exiting uncleanly." | Out-File $WorkloadErrorLog -Append
    }
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