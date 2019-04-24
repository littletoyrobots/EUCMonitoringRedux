# This is for single-site configuration.  Its easiest to copy this file and
# edit the copy per site.   Do not comment out any of these lines.  We suggest
# using fqdn for servernames, so any valid certificate checks associated will pass.

$BaseDir = "C:\Monitoring"
$CVADDesktops = $true
$CVADServers = $true
$CVADWorkerHealth = $true    # If you want to fine tune which worker health checks are run, see below.

############################
# Citrix Apps and Desktops #
############################

# These brokers can be either Delivery Controllers or Cloud Connectors, but not both.
# If you require multi-site, it might be worth reviewing further down.
$CVADBrokers = $null          # Put your brokers here.  Example value: "ddc1.domain.com", "ddc2.domain.com"

# If On-Premises:
$CVADControllers = $null      # Put your Citrix delivery controllers here. e.g "ddc1.domain.com", "ddc2.domain.com"

# If Citrix Cloud:
# 1 - Login to https://citrix.cloud.com
# 2 - Navigate to "Identity and Access Management"
# 3 - Click "API Access"
# 4 - Enter a name for Secure Client and click Create Client.
# 5 - Once Secure Client is created, download Secure Client Credentials file,
#     and save to C:\Monitoring\secureclient.csv
# 6 - Uncomment the following line.
# Set-XDCredentials -CustomerId "%Customer ID%" -SecureClientFile "C:\Monitoring\secureclient.csv" -ProfileType CloudApi -StoreAs "CloudAdmin"
$CVADCloudConnectors = $null          # Put your Citrix cloud connectors here. e.g. "cc1.domain.com", "cc2.domain.com"

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
$CitrixADCGateways = $null  # These would be your ADC Gateway IP, $needs ADCCred defined

#####################
# Licensing Servers #
#####################
$RdsLicenseServers = $null  # Put your RDS license servers here.
$CVADLicenseServers = $null   # Put your Citrix license servers here.

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

##########
# Output #
##########

$OutputInfluxDataProtocol = $true   # This is used for Telegraf
$GenerateReportHTML = $true
$ReportHTMLPath = "$BaseDir\EUCMonitoring.html"


# $ErrorsToTSDB = $true

# Test Specific, Temporary files. Overwritten with each run.
$WorkloadErrorLog = "$BaseDir\Workload-Errors.txt"
$WorkerHealthErrorLog = "$BaseDir\WorkerHealth-Errors.txt"
$ADCErrorLog = "$BaseDir\ADC-Errors.txt"
$InfraErrorLog = "$BaseDir\Infra-Errors.txt"

# After everything is done, the above logs will be combined into $ErrorLog, and a running log
# $ErrorHistory, so that previous errors can be reviewed.
$ErrorLog = "$BaseDir\CurrentErrorLog.txt"
$ErrorHistory = "$BaseDir\ErrorLog.txt"


#########################################
# End of easy implementation config.    #
# Edit below this line with discretion. #
# Or not, whatever, I'm just a comment. #
#########################################

Import-Module C:\Monitoring\EUCMonitoring\PSGallery\EUCMonitoringRedux.psm1
# Import-Module EUCMonitoringRedux
$TimeStamp = Get-InfluxTimestamp
$Global:ProgressPreference = 'SilentlyContinue' # Stop that little popup.
$WarningPreference = 'SilentlyContinue' # Telegraf doesn't differientiate between different powershell streams

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "You must be administrator in order to execute this script"
}

# Out with the old.
if (Test-Path $WorkloadErrorLog) { Remove-Item $WorkloadErrorLog -Force }
if (Test-Path $WorkerHealthErrorLog) { Remove-Item $WorkerHealthErrorLog -Force }
if (Test-PAth $ADCErrorLog) { Remove-Item $ADCErrorLog -Force }
if (Test-Path $InfraErrorLog) { Remove-Item $InfraErrorLog -Force }
if (Test-Path $ErrorLog) { Remove-Item $ErrorLog -Force }

# Results initialization
$CVADWorkload = @()
$CVADWorkerHealth = @()
$ADCResults = @()
$RDSLicenses = @()
$CVADLicenses = @()
$InfraResults = @()


# If you have multiple sites, just copy this section and invoke using
# the brokers associated with each site.

# Workload session
if ($null -ne $CitrixBrokers) {
    $CVADWorkload = @()
    $CVADWorkerHealth = @()

    # Test for Desktop Sessions
    $CVADWorkloadParams = @{
        Broker   = $CVADBrokers; # Put your brokers here.
        ErrorLog = $WorkloadErrorLog
    }
    if ($Desktops) { $CVADWorkloadParams.SingleSession = $true }
    if ($Servers) { $CVADWorkloadParams.MultiSession = $true }

    $CVADWorkload = Get-CVADworkload @CVADWorkloadParams
    $CVADWorkload | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp

    if ($WorkerHealth) {
        if ($CVADDesktops) {
            $CVADwhParams = @{
                Broker             = $CVADBrokers;
                SingleSession      = $true;
                ActiveOnly         = $false; # If enabled, will ignore worker checks for machines in maintenance
                BootThreshold      = 30; # If number of days since boot goes above this, treat as health issue
                LoadThreshold      = 8000; # If load index goes above this, treat as health issue
                DiskSpaceThreshold = 90; # If disk space usage above this percent, treat as health issue
                DiskQueueThreshold = 2; # If current disk queue length goes above this, treat as health issue
                ErrorLog           = $WorkerHealthErrorLog
            }
            $CVADWorkerHealth += Get-CVADworkerhealth @CVADwhParams
        }
        if ($CVADServers) {
            $CVADwhParams = @{
                Broker             = $CVADBrokers;
                Multisession       = $true;
                ActiveOnly         = $false;
                BootThreshold      = 7;
                LoadThreshold      = 8000;
                DiskSpaceThreshold = 90;
                DiskQueueThreshold = 2;
                ErrorLog           = $WorkerHealthErrorLog
            }
            $CVADWorkerHealth += Get-CVADworkerhealth @CVADwhParams
        }

        if ($OutputInfluxDataProtocol) {
            $CVADWorkerHealth | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
        }
    }
}

# ! Placeholder for RDS

# ! Placeholder for VMware

# Netscalers
$ADCResults = @()
if ($null -ne $CitrixADCs) {
    foreach ($ADC in $CitrixADCs) {
        $ADCParams = @{
            ADC        = $CitrixADC; # Example value = "10.1.2.3","10.1.2.4"
            Credential = $ADCCred;
            ErrorLog   = $ADCErrorLog
        }

        $ADCResults += Get-CADCsystem @ADCParams
    }
    if ($OutputInfluxDataProtocol) {
        $ADCResults | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
    }
}

# Netscaler Gateways, now called Citrix ADC Gateway

if ($null -ne $CitrixADCGateways) {
    foreach ($ADC in $CitrixADCGateways) {
        $ADCParams = @{
            ADC        = $ADC; # Example value = "10.1.2.3","10.1.2.4"
            Credential = $ADCCred;
            ErrorLog   = $ADCErrorLog
        }

        $ADCResults += Get-CADCcsvserver @ADCParams
        $ADCResults += Get-CADCgatewayusers @ADCParams
        $ADCResults += Get-CADCgslbvserver @ADCParams
        $ADCResults += Get-CADChttp @ADCParams
        $ADCResults += Get-CADCip @ADCParams
        $ADCResults += Get-CADClbvserver @ADCParams
        $ADCResults += Get-CADCssl @ADCParams
        $ADCResults += Get-CADCsslcertkey @ADCParams
        $ADCResults += Get-CADCsystem @ADCParams
        $ADCResults += Get-CADCtcp @ADCParams

        if ($OutputInfluxDataProtocol) {
            $ADCResults | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
        }
    }
}



# Licensing
if ($null -ne $RdsLicenseServers) {
    $RDSLicenseParams = @{
        ComputerName = $RdsLicenseServers; # Example value = "rds-license1", "rds-license2"
        ErrorLog     = $InfraErrorLog
    }
    $RDSLicenses += Get-RDSLicense @RDSLicenseParams

    if ($OutputInfluxDataProtocol) {
        $RDSLicenses | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
    }

    $RDSLicenseParams = @{
        Series       = "RdsLicensing";
        ComputerName = $RdsLicenseServers;
        Ports        = 135, 443;
        Services     = "TermService", "TermServLicensing", "UmRdpService";
        ErrorLog     = $InfraErrorLog
    }

    $RdsResults = Test-EUCServer @RDSLicenseParams
    $InfraResults += $RdsResults

    if ($OutputInfluxDataProtocol) {
        $RdsResults | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
    }
}

if ($null -ne $XdLicenseServers) {
    $CVADLicenseParams = @{
        ComputerName = $CVADLicenseServers; # Example value = "xd-license1", "xd-license2"
        ErrorLog     = $InfraErrorLog
    }
    $CVADLicenses = Test-EUCLicense @XdLicenseParams

    if ($OutputInfluxDataProtocol) {
        $CVADLicenses | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
    }

    $XdLicenseParams = @{
        Series       = "CVADlicense";
        ComputerName = $XdLicenseServers;
        Ports        = 7279, 27000, 8082, 8083;
        Services     = "Citrix Licensing", "CitrixWebServicesforLicensing";
        ErrorLog     = $ErrorLog
    }

    $CVADResults = Test-EUCServer @XdLicenseParams
    $InfraResults += $CVADResults

    if ($OutputInfluxDataProcol) {
        $CVADResults | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
    }
}

# Server checks.
if ($null -ne $ADServers) {
    $ADParams = @{
        Series        = "AD";
        ComputerName  = $ADServers; # Example value = "dc1", "dc2"
        Ports         = 389, 636;
        Services      = "Netlogon", "ADWS", "NTDS";
        ValidCertPort = 636;
        ErrorLog      = $ErrorLog
    }
    Test-EUCServer @ADParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $SQLServers) {
    $SQLParams = @{
        Series       = "SQL";
        ComputerName = $SQLServers; # Example value = "sql1", "sql2"
        Ports        = 1433;
        Services     = "MSSQLServer";
        ErrorLog     = $ErrorLog
    }
    Test-EUCServer @SQLParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $AppVServers) {
    $AppVParams = @{
        Series       = "AppV";
        ComputerName = $AppVServers; # Example value = "appv1", "appv2"
        Ports        = 8080;
        Services     = "W3SVC";
        ErrorLog     = $ErrorLog
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
        ErrorLog      = $ErrorLog
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
        HTTPSPort    = 443;
        ErrorLog     = $ErrorLog
    }
    Test-EUCServer @DirectorParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $CVADControllers) {
    $XdControllerParams = @{
        Series       = "CVADController";
        ComputerName = $CVADControllers; # Example value = "ddc1", "ddc2"
        Ports        = 80;
        Services     = "CitrixBrokerService", "CitrixHighAvailabilityService", "CitrixConfigSyncService", "CitrixConfigurationService", "CitrixConfigurationLogging", "CitrixDelegatedAdmin", "CitrixADIdentityService", "CitrixMachineCreationService", "CitrixHostService", "CitrixEnvTest", "CitrixMonitor", "CitrixAnalytics", "CitrixAppLibrary", "CitrixOrchestration";
        ErrorLog     = $ErrorLog
    }
    Test-EUCServer @XdControllerParams | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
}

if ($null -ne $PVSServers) {
    $ProvisioningParams = @{
        Series       = "PVS";
        ComputerName = $PVSServers; # Example value = "pvs1", "pvs2"
        Ports        = 54321;
        Services     = "BNPXE", "BNTFTP", "PVSTSB", "soapserver", "StreamService";
        ErrorLog     = $InfraErrorLog
    }
    $PVSResults = Test-EUCServer @ProvisioningParams
    $InfraResults += $PVSResults

    if ($OutputInfluxDataProtocol) {
        $PVSResults | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
    }
}

if ($null -ne $WEMBrokers) {
    $WEMParams = @{
        Series       = "WEM";
        ComputerName = $WEMBrokers; # Example value = "wembroker1", "wembroker2"
        Ports        = 8286;
        Services     = "Norskale Infrastructure Service";
        ErrorLog     = $InfraErrorLog
    }
    $WEMResults = Test-EUCServer @WEMParams
    $InfraResults += $WEMResults

    if ($OutputInfluxDataProtocol) {
        $WEMResults | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
    }
}

if ($null -ne $UPSServers) {
    $UPSParams = @{
        Series       = "UPS";
        ComputerName = $UPSServers; # Example Value = "print1", "print2"
        Ports        = 7229;
        Services     = "UpSvc", "CitrixXTEServer";
        ErrorLog     = $InfraErrorLog
    }
    $UPSResults = Test-EUCServer @UPSParams
    $InfraResults += $UPSResults

    if ($OutputInfluxDataProtocol) {
        $UPSResults | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
    }
}

if ($null -ne $FASServers) {
    $FASParams = @{
        Series       = "FAS";
        ComputerName = $FASServers; # Example Value = "fas1", "fas2"
        Ports        = 135;
        Services     = "CitrixFederatedAuthenticationService";
        ErrorLog     = $InfraErrorLog
    }
    $FASResults = Test-EUCServer @FASParams
    $InfraResults += $FASResults

    if ($OutputInfluxDataProtocol) {
        $FASResults | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
    }
}

if ($null -ne $CVADCloudConnectors) {
    $CCParams = @{
        Series       = "CVADCC";
        ComputerName = $CCServers; # Example Value = "cc1", "cc2"
        Ports        = 80;
        Services     = "CitrixWorkspaceCloudADProvider", "CitrixWorkspaceCloudAgentDiscovery", "CitrixWorkspaceCloudAgentLogger", "CitrixWorkspaceCloudAgentSystem", "CitrixWorkspaceCloudAgentWatchDog", "CitrixWorkspaceCloudCredentialProvider", "CitrixWorkspaceCloudWebRelayProvider", "CitrixConfigSyncService", "CitrixHighAvailabilityService", "Citrix NetScaler Cloud Gateway", "XaXdCloudProxy", "RemoteHCLServer", "SessionManagerProxy";
        ErrorLog     = $InfraErrorLog
    }
    $CCResults = Test-EUCServer @CCParams
    $InfraResults += $CCResults

    if ($OutputInfluxDataProtocol) {
        $CCResults | ConvertTo-InfluxLineProtocol -Timestamp $TimeStamp
    }
}



$content = Get-Content $ErrorLog
if ($null -ne $content) {
    $content | Out-File -FilePath $ErrorHistory -Append
    if ($ErrorsToTSDB) {
        foreach ($ErrorLogItem in $content) {
            "ErrorLog $($ErrorLogItem.Trim() ) $TimeStamp"
        }
    }
}