

# This assumes single site.  
$CitrixWorkloadBrokers = "ddc1", "ddc2" 

# CitrixADCAddress is for NSIPs and will return system stats
$CitrixADCaddress = "10.1.2.3", "10.1.2.4"
# CitrixADCGatewayAddress is for gateway users, lbvserver stats, etc. 
$CitrixADCgatewayaddress = "10.1.2.5"

$ADCCred = (Get-Credential -Message "Please use your ADC Login") # We will address this soon. 

$RdsLicenseServers = "rdslic1", "rdslic2"
$XdLicenseServers = "xdlic1", "xdlic2"

# Grabbing Timestamp at the beginning so that all results share the same timestamp.  It helps
# with collation in Grafana.  
$TimeStamp = Get-InfluxTimestamp
$Results = @()

<# Workload Section #>

$WorkloadParams = @{
    ComputerName  = $CitrixWorkloadBrokers; # Put your brokers here. 
    XdDesktop     = $true;
    XdServer      = $true;
    WorkerHealth  = $true;
    BootThreshold = 7;
    Highload      = 8000
}
$Results += Test-EUCWorkload @WorkloadParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

<# 
If you have multiple sites, you can uncomment and duplicate these
as many times as necessary.
$WorkloadParams = @{
    ComputerName  = "ddc1", "ddc2"; # Put your brokers here. 
    XdDesktop     = $true;
    XdServer      = $true;
    WorkerHealth  = $true;
    BootThreshold = 7;
    Highload      = 8000
}
$Results += Test-EUCWorkload @WorkloadParams
#> 

<# ADC Section #>


$ADCParams = @{
    ADC           = $CitrixADCAddress;
    CitrixADC     = $true;
    SystemStats   = $true;
    GatewayUsers  = $false;
    LoadBalance   = $false;
    ContentSwitch = $false;
    Cache         = $false; # Not yet implemented
    Compression   = $false; # Not yet implementeed
    SSLOffload    = $false; # Not yet implemented
    Credential    = $ADCCred
}
$Results += Test-EUCADC @ADCParams

$ADCParams = @{
    ADC           = $CitrixADCGatewayAddress;
    CitrixADC     = $true;
    SystemStats   = $false;
    GatewayUsers  = $true;
    LoadBalance   = $true;
    ContentSwitch = $true;
    Cache         = $false; # Not yet implemented
    Compression   = $false; # Not yet implementeed
    SSLOffload    = $false; # Not yet implemented
    Credential    = $ADCCred
}
$Results += Test-EUCADC @ADCParams

<#
$ADCCred = (Get-Credential -Message "Please use your ADC Login") # We will address this soon. 

$ADCParams = @{
    ADC           = $CitrixADCaddress;
    CitrixADC     = $true;
    GatewayUsers  = $true;
    LoadBalance   = $true;
    ContentSwitch = $true;
    Cache         = $false; # Not yet implemented
    Compression   = $false; # Not yet implementeed
    SSLOffload    = $false; # Not yet implemented
    Credential    = $ADCCred
}
$Results += Test-EUCADC @ADCParams
#>


$RDSLicenseParams = @{
    ComputerName = $RdsLicenseServers;
    RdsLicense   = $true;
    XdLicense    = $false
}
$Results += Test-EUCLicense @RDSLicenseParams

<#
$RDSLicenseParams = @{
    ComputerName = $RdsLicenseServers;
    RdsLicense   = $true;
    XdLicense    = $false
}
$Results += Test-EUCLicense @RDSLicenseParams
#> 

$XdLicenseParams = @{
    ComputerName = $XdLicenseServers;
    RdsLicense   = $false;
    XdLicense    = $true
}
$Results += Test-EUCLicense @XdLicenseParams

<#

$XdLicenseParams = @{
    ComputerName = "xdlic"
    RdsLicense   = $false;
    XdLicense    = $true
}
$Results += Test-EUCLicense @XdLicenseParams

#>



ConvertTo-InfluxLineProtocol -InputObject $Results -Timestamp $TimeStamp