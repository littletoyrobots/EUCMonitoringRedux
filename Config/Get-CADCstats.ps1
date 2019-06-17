$CitrixADCGateways = "10.1.2.3", "10.2.3.4"
$ADCUser = "nsroot"         # Or whatever
# Generate a credential for storage by
#> Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "C:\Monitoring\ADCcred.txt"

$ADCPass = Get-Content -Path "C:\Monitoring\ADCcred.txt" | ConvertTo-SecureString
$ADCCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ADCUser, $ADCPass

$ADCErrorLog = "C:\Monitoring\ADC-Errors.txt"

# Do the things.
if ($null -ne $CitrixADCGateways) {
    $ADCResults = @()
    $TimeStamp = Get-InfluxTimestamp
    foreach ($ADC in $CitrixADCGateways) {
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
}
