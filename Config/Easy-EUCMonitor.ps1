# This is for single-site configuration.  Its easiest to copy this file and 
# edit the copy per site.   Do not comment out any of these lines.  We suggest
# using fqdn for servernames, so any valid certificate checks associated will pass.

############################
# Citrix Apps and Desktops #
############################
# These brokers can be either Delivery Controllers or Cloud Connectors, but not both.  
$XdDesktopBrokers = $null   # Put your brokers here.  Example value: "ddc1.domain.com", "ddc2.domain.com"
$XdServerBrokers = $null    # Put your brokers here.  Example value: "ddc1.domain.com", "ddc2.domain.com"

# If On-Premises:
$XdControllers = $null      # Put your Citrix delivery controllers here. e.g "ddc1.domain.com", "ddc2.domain.com"

# If Citrix Cloud: 
# 1 - Login to https://citrix.cloud.com
# 2 - Navigate to "Identity and Access Management"
# 3 - Click "API Access"
# 4 - Enter a name for Secure Client and click Create Client.
# 5 - Once Secure Client is created, download Secure Client Credentials file,
#     and save to C:\Monitoring\secureclient.csv
# 6 - Uncomment the following line. 
# Set-XDCredentials -CustomerId "%Customer ID%" -SecureClientFile "C:\Monitoring\secureclient.csv" -ProfileType CloudApi -StoreAs "CloudAdmin"
$CCServers = $null          # Put your Citrix cloud connectors here. e.g. "cc1.domain.com", "cc2.domain.com"

#################################
# RDS Site coming in the future #
#################################

#################
# VMware Too... #
#################

###############
# Citrix ADCs #
###############

# Here's a simple way to save a password without leaving it in plaintext.  There are surely better ways,
# and you should use them. 
# 
# Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "C:\Monitoring\ADCcred.txt"
# 
# Then uncomment the following three lines
# $ADCUser = "nsroot"         # Or whatever
# $ADCPass = Get-Content -Path "C:\Monitoring\ADCcred.txt" | ConvertTo-SecureString
# $ADCCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ADCUser, $ADCPass

# $ADCCred = (Get-Credential) # Uncomment this for testing. 

$CitrixADCs = $null         # These would be your NSIPs, needs $ADCCred defined
$CitrixADCGateways = $null  # These would be your ADC Gateway IPs, $needs ADCCred defined

#####################
# Licensing Servers #
#####################
$RdsLicenseServers = $null  # Put your RDS license servers here.
$XdLicenseServers = $null   # Put your Citrix license servers here. 

##################################
# Common Microsoft Server groups #
##################################
$ADServers = $null          # Put your Domain Controllers here.
$SQLServers = $null         # Put your SQL Servers here.
$AppVServers = $null        # Put your AppV Servers here. 

###############################
# Common Citrix Server groups #
###############################
$StoreFrontServers = $null  # E.g - "store1.domain.org", "store2.domain.org"
$StoreFrontPaths = "/Citrix/StoreWeb"   # Can be multiple paths.  
$DirectorServers = $null    # Put your director servers here.

$PVSServers = $null         # Put your provisioning servers here.
$WEMBrokers = $null         # Put your WEM brokers here.
$UPSServers = $null         # Put your UPS servers here.
$FASServers = $null         # Put your FAS servers here.

#########################################
# End of easy implementation config.    #
# Edit below this line with discretion. #
#########################################

Import-Module C:\Monitoring\EUCMonitoring\PSGallery\EUCMonitoringRedux.psm1
# Import-Module EUCMonitoringRedux 
$TimeStamp = Get-InfluxTimestamp
$Global:ProgressPreference = 'SilentlyContinue' # Stop that little popup.  
$WarningPreference = 'SilentlyContinue' # Telegraf doesn't differientiate between different powershell streams

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "You must be administrator in order to execute this script"
}

# Workload
if ($null -ne $XdDesktopBrokers) {
    $XdDesktopParams = @{
        ComputerName  = $XdDesktopBrokers; # Put your brokers here. 
        XdDesktop     = $true;
        XdServer      = $false;
        WorkerHealth  = $true;
        BootThreshold = 7;
        LoadThreshold = 8000;
    }
    Test-EUCWorkload @XdDesktopParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $XdServerBrokers) {
    $XdServerParams = @{
        ComputerName  = $XdServerBrokers; # Put your brokers here. Example value = "ddc1", "ddc2"
        XdDesktop     = $false;
        XdServer      = $true;
        WorkerHealth  = $true;
        BootThreshold = 7;
        LoadThreshold = 8000    
    }
    Test-EUCWorkload @XdServerParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

# ! Placeholder for RDS 

# ! Placeholder for VMware

# Netscalers
if ($null -ne $CitrixADCs) {
    $ADCParams = @{
        CitrixADC     = $CitrixADCs; # Example value = "10.1.2.3","10.1.2.4"
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
}

# Netscaler Gateways, now called Citrix ADC Gateway

if ($null -ne $CitrixADCGateways) {
    $ADCParams = @{
        CitrixADC     = $CitrixADCGateways; # Example value = "10.1.2.5"
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
}

# Licensing
if ($null -ne $RdsLicenseServers) {
    $RDSLicenseParams = @{
        ComputerName = $RdsLicenseServers; # Example value = "rds-license1", "rds-license2"
        RdsLicense   = $true;
        XdLicense    = $false
    }
    Test-EUCLicense @RDSLicenseParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

    $RDSLicenseParams = @{
        Series       = "RdsLicensing";
        ComputerName = $RdsLicenseServers;
        Ports        = 7279, 27000, 8082, 8083;
        Services     = "TermService", "TermServLicensing", "UmRdpService"
    }
    Test-EUCServer @RdsLicenseParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $XdLicenseServers) {
    $XdLicenseParams = @{
        ComputerName = $XdLicenseServers; # Example value = "xd-license1", "xd-license2"
        RdsLicense   = $false;
        XdLicense    = $true
    }
    Test-EUCLicense @XdLicenseParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
    
    $XdLicenseParams = @{
        Series       = "XdLicense";
        ComputerName = $XdLicenseServers;
        Ports        = 7279, 27000, 8082, 8083;
        Services     = "Citrix Licensing", "CitrixWebServicesforLicensing"
    }
    Test-EUCServer @XdLicenseParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

# Server checks.  
if ($null -ne $ADServers) {
    $ADParams = @{
        Series        = "AD"; 
        ComputerName  = $ADServers; # Example value = "dc1", "dc2"
        Ports         = 389, 636; 
        Services      = "Netlogon", "ADWS", "NTDS";
        ValidCertPort = 636 
    }
    Test-EUCServer @ADParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $SQLServers) {
    $SQLParams = @{
        Series       = "SQL";
        ComputerName = $SQLServers; # Example value = "sql1", "sql2"
        Ports        = 1433;
        Services     = "MSSQLServer"
    }
    Test-EUCServer @SQLParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $AppVServers) {
    $AppVParams = @{
        Series       = "AppV";
        ComputerName = $AppVServers; # Example value = "appv1", "appv2"
        Ports        = 8080;
        Services     = "W3SVC"
    }
    Test-EUCServer @AppVParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $StoreFrontServers) {
    $StorefrontParams = @{
        Series        = "Storefront";
        ComputerName  = $StoreFrontServers; # Example value = "storefront1", "storefront2"
        Ports         = 80, 443;
        Services      = "W3SVC", "NetTcpPortSharing", "CitrixSubscriptionsStore", "WAS", "CitrixDefaultDomainService", "CitrixCredentialWallet", "CitrixConfigurationReplication";
        HTTPPath      = $StoreFrontPaths;
        HTTPPort      = 80;
        HTTPSPath     = $StoreFrontPaths;
        HTTPSPort     = 443;
        ValidCertPort = 443;
    }
    Test-EUCServer @StorefrontParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $DirectorServers) {
    $DirectorParams = @{
        Series       = "Director";
        ComputerName = $DirectorServers; # Example value = "director1", "director2"
        Ports        = 80, 443;
        HTTPPath     = "/Director/LogOn.aspx?cc=true";
        HTTPPort     = 80;
        HTTPSPath    = "/Director/LogOn.aspx?cc=true";
        HTTPSPort    = 443
    }
    Test-EUCServer @DirectorParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
} 

if ($null -ne $XdControllers) {
    $XdControllerParams = @{
        Series       = "XdController";
        ComputerName = $XdControllers; # Example value = "ddc1", "ddc2"
        Ports        = 80;
        Services     = "CitrixBrokerService", "CitrixHighAvailabilityService", "CitrixConfigSyncService", "CitrixConfigurationService", "CitrixConfigurationLogging", "CitrixDelegatedAdmin", "CitrixADIdentityService", "CitrixMachineCreationService", "CitrixHostService", "CitrixEnvTest", "CitrixMonitor", "CitrixAnalytics", "CitrixAppLibrary", "CitrixOrchestration"
    }
    Test-EUCServer @XdControllerParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $PVSServers) {
    $ProvisioningParams = @{
        Series       = "Provisioning";
        ComputerName = $PVSServers; # Example value = "pvs1", "pvs2"
        Ports        = 54321;
        Services     = "BNPXE", "BNTFTP", "PVSTSB", "soapserver", "StreamService"
    }
    Test-EUCServer @ProvisioningParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $WEMBrokers) {
    $WEMParams = @{
        Series       = "WEM";
        ComputerName = $WEMBrokers; # Example value = "wembroker1", "wembroker2"
        Ports        = 8286;
        Services     = "Norskale Infrastructure Service"
    }
    Test-EUCServer @WEMParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $UPSServers) {
    $UPSParams = @{
        Series       = "UPS";
        ComputerName = $UPSServers; # Example Value = "print1", "print2"
        Ports        = 7229;
        Services     = "UpSvc", "CitrixXTEServer"
    }
    Test-EUCServer @UPSParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $FASServers) {
    $FASParams = @{
        Series       = "FAS";
        ComputerName = $FASServers; # Example Value = "fas1", "fas2"
        Ports        = 135;
        Services     = "CitrixFederatedAuthenticationService"
    }
    Test-EUCServer @FASParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $CCServers) {
    $CCParams = @{
        Series       = "CC";
        ComputerName = $CCServers; # Example Value = "cc1", "cc2"
        Ports        = 80;
        Services     = "CitrixWorkspaceCloudADProvider", "CitrixWorkspaceCloudAgentDiscovery", "CitrixWorkspaceCloudAgentLogger", "CitrixWorkspaceCloudAgentSystem", "CitrixWorkspaceCloudAgentWatchDog", "CitrixWorkspaceCloudCredentialProvider", "CitrixWorkspaceCloudWebRelayProvider", "CitrixConfigSyncService", "CitrixHighAvailabilityService", "Citrix NetScaler Cloud Gateway", "XaXdCloudProxy", "RemoteHCLServer", "SessionManagerProxy"
    }
    Test-EUCServer @CCParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
} 
