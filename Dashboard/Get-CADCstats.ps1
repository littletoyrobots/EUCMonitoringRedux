$BaseDir = "C:\Monitoring"
$CitrixADCGateways = "10.240.1.53"
$ADCUser = "nsroot"         # Or whatever

# Generate a credential for storage by running this as the
#> Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "C:\Monitoring\ADCcred.txt"

$VerbosePreference = 'SilentlyContinue' #
# $VerbosePreference = 'Continue'


$ADCPass = Get-Content -Path (Join-Path -Path $BaseDir -ChildPath "ADCcred.txt") | ConvertTo-SecureString
$ADCCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ADCUser, $ADCPass

$ADCErrorLog = Join-Path -Path $BaseDir -ChildPath "ADC-Errors.txt"
$ADCErrorHistory = Join-Path -Path $BaseDir -ChildPath "ADC-ErrorHistory.txt"

Import-Module (Join-Path -Path $BaseDir -ChildPath "EUCMonitoringRedux-master\PSGallery\EUCMonitoringRedux.psd1")

# Do the things.
if ($null -ne $CitrixADCGateways) {
    $ADCResults = @()
    $TimeStamp = Get-InfluxTimestamp

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