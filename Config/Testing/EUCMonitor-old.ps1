
Import-Module EUCMonitoringRedux
$TimeStamp = Get-InfluxTimestamp

# Workload
$XdDesktopParams = @{
    ComputerName  = $null; # Put your brokers here. Example value = "ddc1", "ddc2"
    XdDesktop     = $true;
    XdServer      = $false;
    WorkerHealth  = $true;
    BootThreshold = 7;
    Highload      = 8000
}
Test-EUCWorkload @XdDesktopParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

$XdServerParams = @{
    ComputerName  = $null; # Put your brokers here. Example value = "ddc1", "ddc2"
    XdDesktop     = $false;
    XdServer      = $true;
    WorkerHealth  = $true;
    BootThreshold = 7;
    Highload      = 8000
}
Test-EUCWorkload @XdServerParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

# Netscalers
$ADCParams = @{
    CitrixADC     = $null;
    SystemStats   = $true;
    GatewayUsers  = $false;
    LoadBalance   = $false;
    ContentSwitch = $false;
    Cache         = $false; # Not yet implemented
    Compression   = $false; # Not yet implementeed
    SSLOffload    = $false; # Not yet implemented
    Credential    = $ADCCred
}
Test-EUCADC @ADCParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

# Netscaler Gateways, now called Citrix ADC Gateway
$ADCCred = (Get-Credential) # This won't work.
$ADCParams = @{
    CitrixADC     = $null; # Example value = "10.1.2.5"
    SystemStats   = $false;
    GatewayUsers  = $true;
    LoadBalance   = $true;
    ContentSwitch = $true;
    Cache         = $false; # Not yet implemented
    Compression   = $false; # Not yet implementeed
    SSLOffload    = $false; # Not yet implemented
    Credential    = $ADCCred
}
Test-EUCADC @ADCParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

# Licensing
$RDSLicenseParams = @{
    ComputerName = $null; # Example value = "rds-license1", "rds-license2"
    RdsLicense   = $true;
    XdLicense    = $false
}
Test-EUCLicense @RDSLicenseParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

$XdLicenseParams = @{
    ComputerName = $null; # Example value = "xd-license1", "xd-license2"
    RdsLicense   = $false;
    XdLicense    = $true
}
Test-EUCLicense @XdLicenseParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

# Server checks.  
$ADParams = @{
    Series        = "AD"; 
    ComputerName  = $null; # Example value = "dc1", "dc2"
    Ports         = 389, 636; 
    Services      = "Netlogon", "ADWS", "NTDS";
    ValidCertPort = 636 
}
Test-EUCServer @ADParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

$SQLParams = @{
    Series       = "SQL";
    ComputerName = $null; # Example value = "sql1", "sql2"
    Ports        = 1433;
    Services     = "MSSQLServer"
}
Test-EUCServer @SQLParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

$AppVParams = @{
    Series       = "AppV";
    ComputerName = $null; # Example value = "appv1", "appv2"
    Ports        = 8080;
    Services     = "W3SVC"
}
Test-EUCServer @AppVParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

$StorefrontParams = @{
    Series        = "Storefront";
    ComputerName  = $null; # Example value = "storefront1", "storefront2"
    Ports         = 80, 443;
    Services      = "W3SVC", "NetTcpPortSharing", "CitrixSubscriptionsStore", "WAS", "CitrixDefaultDomainService", "CitrixCredentialWallet", "CitrixConfigurationReplication";
    HTTPPath      = "/Citrix/StoreWeb";
    HTTPPort      = 80
    HTTPSPath     = "/Citrix/StoreWeb";
    HTTPSPort     = 443
    ValidCertPort = 443;
}
Test-EUCServer @StorefrontParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

$DirectorParams = @{
    Series       = "Director";
    ComputerName = $null; # Example value = "director1", "director2"
    Ports        = 80, 443;
    HTTPPath     = "/Director/LogOn.aspx?cc=true";
    HTTPPort     = 80;
    HTTPSPath    = "/Director/LogOn.aspx?cc=true";
    HTTPSPort    = 443
}
Test-EUCServer @DirectorParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

$XdControllerParams = @{
    Series       = "XdController";
    ComputerName = $null; # Example value = "ddc1", "ddc2"
    Ports        = 80;
    Services     = "CitrixBrokerService", "CitrixHighAvailabilityService", "CitrixConfigSyncService", "CitrixConfigurationService", "CitrixConfigurationLogging", "CitrixDelegatedAdmin", "CitrixADIdentityService", "CitrixMachineCreationService", "CitrixHostService", "CitrixEnvTest", "CitrixMonitor", "CitrixAnalytics", "CitrixAppLibrary", "CitrixOrchestration"
}
Test-EUCServer @XdControllerParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

$ProvisioningParams = @{
    Series       = "Provisioning";
    ComputerName = $null; # Example value = "pvs1", "pvs2"
    Ports        = 54321;
    Services     = "BNPXE", "BNTFTP", "PVSTSB", "soapserver", "StreamService"
}
Test-EUCServer @ProvisioningParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

$WEMParams = @{
    Series       = "WEM";
    ComputerName = $null; # Example value = "wembroker1", "wembroker2"
    Ports        = 8286;
    Services     = "Norskale Infrastructure Service"
}
Test-EUCServer @WEMParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

$UPSParams = @{
    Series       = "UPS";
    ComputerName = $null; # Example Value = "print1", "print2"
    Ports        = 7229;
    Services     = "UpSvc", "CitrixXTEServer"
}
Test-EUCServer @UPSParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

# FAS, CC
$FASParams = @{
    Series       = "FAS";
    ComputerName = $null; # Example Value = "fas1", "fas2"
    Ports        = 135;
    Services     = "CitrixFederatedAuthenticationService"
}
Test-EUCServer @FASParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp


$CCParams = @{
    Series       = "CC";
    ComputerName = $null; # Example Value = "cc1", "cc2"
    Ports        = 80;
    Services     = "CitrixWorkspaceCloudADProvider", "CitrixWorkspaceCloudAgentDiscovery", "CitrixWorkspaceCloudAgentLogger", "CitrixWorkspaceCloudAgentSystem", "CitrixWorkspaceCloudAgentWatchDog", "CitrixWorkspaceCloudCredentialProvider", "CitrixWorkspaceCloudWebRelayProvider", "CitrixConfigSyncService", "CitrixHighAvailabilityService", "Citrix NetScaler Cloud Gateway", "XaXdCloudProxy", "RemoteHCLServer", "SessionManagerProxy"
}
Test-EUCServer @CCParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

