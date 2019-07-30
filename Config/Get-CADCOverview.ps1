$BaseDir = "C:\Monitoring"
Import-Module (Join-Path -Path $BaseDir -ChildPath "EUCMonitoringRedux-master\PSGallery\EUCMonitoringRedux.psd1")

# This is going to default to verbose output, to make sure that you're testing and
#$VerbosePreference = 'SilentlyContinue' #
$VerbosePreference = 'Continue'

#  You can have multiple Gateways as long as the creds work on each, and they're accessible
$CitrixADCGateways = "10.1.2.3", "10.1.2.3"
# I prefer readon-only users.  You don't really want to test run someone else's script with nsroot, do you?
$ADCUser = "notnsroot"

# Generate a credential for storage by running this as the account telegraf runs under.  You probably know a
# better way of doing this. This is just an example.
#> Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "C:\Monitoring\ADCcred.txt"

$ADCPass = Get-Content -Path (Join-Path -Path $BaseDir -ChildPath "ADCcred.txt") | ConvertTo-SecureString
$ADCCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ADCUser, $ADCPass

# If you're just testing and want to see the output without generating a credential file, this script can
# also be run by commenting the above lines and uncommenting this.
# $ADCCred = Get-Credential

$ADCErrorLog = Join-Path -Path $BaseDir -ChildPath "ADC-Errors.txt"
$ADCErrorHistory = Join-Path -Path $BaseDir -ChildPath "ADC-ErrorHistory.txt"

# Do the things.
if ($null -ne $CitrixADCGateways) {
    $ADCResults = @()

    # Its nice to have all the timestamps be the same when you're graphing in Grafana later.
    $TimeStamp = Get-InfluxTimestamp

    # We want the current log to only have just what's wrong with the latest run.
    if (Test-Path $ADCErrorLog) {
        Remove-Item -Path $ADCErrorLog -Force
    }

    foreach ($ADC in $CitrixADCGateways) {
        try {
            $ADCParams = @{
                ADC        = $ADC; # Example value = "10.1.2.3","10.1.2.4"
                Credential = $ADCCred;
                ErrorLog   = $ADCErrorLog
            }

            $ADCResults += Get-CADCcache @ADCParams
            $ADCResults += Get-CADCcsvserver @ADCParams
            $ADCResults += Get-CADCgatewayuser @ADCParams
            $ADCResults += Get-CADCgslbvserver @ADCParams
            $ADCResults += Get-CADChttp @ADCParams
            $ADCResults += Get-CADCip @ADCParams
            $ADCResults += Get-CADClbvserver @ADCParams
            $ADCResults += Get-CADCssl @ADCParams
            $ADCResults += Get-CADCsslcertkey @ADCParams
            $ADCResults += Get-CADCsystem @ADCParams
            $ADCResults += Get-CADCtcp @ADCParams

            $ADCResults | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
        }
        catch {
            Write-Verbose "[$(Get-Date) PROCESS] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)"
            Write-Verbose "[$(Get-Date)] [$($myinvocation.mycommand)] Exiting uncleanly."
            "[$(Get-Date)] [$($myinvocation.mycommand)] [$($_.Exception.GetType().FullName)] $($_.Exception.Message)" | Out-File $ADCErrorLog -Append
            "[$(Get-Date)] [$($myinvocation.mycommand)] Exiting uncleanly." | Out-File $ADCErrorLog -Append
        }
    }
}

# If this file exists, we have errors, currently.
if (Test-Path $ADCErrorLog) {
    Get-Content $ADCErrorLog | Out-File $ADCErrorHistory -Append

    # Maybe if you care, add something to send one or both log files.
    <#
    $MailParams = @{
        To         = "sysops@domain.com"
        From       = "EUCMonitoring@domain.com"
        Subject    = "ADC Errors"
        Body       = (Get-Content $ADCErrorLog)
        SmtpServer = "smtp.domain.com"
        Attachments = $ADCErrorHistory
    }
    Send-MailMessage @MailParams
    #>
}