function Install-VisualizationSetup {
    <#
    .SYNOPSIS
        Sets up the EUC Monitoring Platform Influx / Grafana platform
    .DESCRIPTION
        Sets up the EUC Monitoring Platform Influx / Grafana platform.  Requires internet connection to Github.
    .PARAMETER MonitoringPath
        Determines the
    .INPUTS
        None
    .OUTPUTS
        None
    .NOTES
        Current Version:        1.1
        Creation Date:          19/03/2018
    .CHANGE CONTROL
        Name                    Version         Date                Change Detail
        Hal Lange               1.0             16/04/2018          Initial Creation of Installer
        Adam Yarborough         1.1             11/07/2018          Integration of Hal's work and updating.
    .PARAMETER MonitoringPath
        Folder path to download files needed for monitoring process
    .EXAMPLE
        None Required

    #>


    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false, ValueFromPipeline = $true)][string]$MonitoringPath = "C:\Monitoring",
        #    [parameter(Mandatory = $false, ValueFromPipeline = $true)][string]$DashboardPath = (Join-Path -Path (get-location).Path -ChildPath "Dashboard"),
        [parameter(Mandatory = $false, ValueFromPipeline = $true)][string]$GrafanaVersion = "https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-6.2.4.windows-amd64.zip",
        [parameter(Mandatory = $false, ValueFromPipeline = $true)][string]$InfluxVersion = "https://dl.influxdata.com/influxdb/releases/influxdb-1.7.6_windows_amd64.zip",
        [parameter(Mandatory = $false, ValueFromPipeline = $true)][string]$NSSMVersion = "https://nssm.cc/release/nssm-2.24.zip",
        [parameter(Mandatory = $false, ValueFromPipeline = $true)][string]$TelegrafVersion = "https://dl.influxdata.com/telegraf/releases/telegraf-1.11.0_windows_amd64.zip"
    )

    begin {
        If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Throw "You must be administrator in order to execute this script"
        }
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    }

    process {
        #Base Directory for Install
        Write-Output "[$(Get-Date)] Install location set to $MonitoringPath"
        # Get the dashboard config.
        if ( test-path $MonitoringPath ) {
            Write-Output "[$(Get-Date)] $MonitoringPath directory already Present"
        }
        else {
            New-Item $MonitoringPath -ItemType Directory
            Write-Output "[$(Get-Date)] EUCMonitoring directory created: $MonitoringPath"
        }

        # EUCMonitoring Specific
        #$DashboardConfig = "$MonitoringPath\Dashboard"
        #$dashDatasource = "$DashboardConfig\DataSource.json"
        #$dashboards = @(
        #    "CADC-Overview.json",
        #    "CVAD-Overview.json"
        #)

        <#
        TODO - Get the dashboard config.
        if ( test-path $DashboardConfig ) {
            Write-Output "[$(Get-Date)]  Dashboard directory already Present"
        }
        else {
            New-Item $DashboardConfig -ItemType Directory
            Write-Output "[$(Get-Date)]  EUC Monitoring Dashboard Directory Created $DashboardConfig"
        }
        #>

        #open FW for Grafana
        Write-Output "[$(Get-Date)] Opening Firewall Rules for Grafana"


        $Catch = New-NetFirewallRule -DisplayName "EUCMonitoring-grafana-server" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow -Description "Allow Grafana Server"
        Write-Output "[$(Get-Date)] Opening Firewall Rules for InfluxDB"
        $Catch = New-NetFirewallRule -DisplayName "EUCMonitoring-influxdb" -Direction Inbound -LocalPort 8086 -Protocol TCP -Action Allow -Description "Allow InfluxDB Server" -AsJob

        function GetAndInstall ( $Product, $DownloadFile, $Dest ) {
            $DownloadLocation = (Get-Item Env:Temp).value  #Use the Temp folder as Temp Download location
            $zipFile = "$DownloadLocation\$Product.zip"
            Write-Output "[$(Get-Date)] Downloading $Product to $zipfile"
            if ( ($DownloadFile -match "http://") -or ($DownloadFile -match "https://") ) {
                $Catch = Invoke-WebRequest $DownloadFile -outFile $zipFile
            }
            else {
                Copy-Item $DownloadFile -Destination "$DownloadLocation\$Product.zip"
            }

            Write-Output "[$(Get-Date)] Installing $Product to $Dest"
            # Expand-Archive -LiteralPath "$DownloadLocation\$Product.zip"
            $shell = New-Object -ComObject shell.application
            $zip = $shell.NameSpace($ZipFile)
            foreach ( $item in $zip.items() ) {
                $shell.Namespace($Dest).CopyHere($item)
            }
            $Catch = ""
            Write-Verbose $Catch
        }


        #Install Grafana
        GetAndInstall "Grafana" $GrafanaVersion $MonitoringPath
        $Grafana = (get-childitem $MonitoringPath | Where-Object { $_.Name -match 'graf' }).FullName

        #Install InfluxDB
        GetAndInstall "InfluxDB" $InfluxVersion $MonitoringPath
        $Influx = (get-childitem $MonitoringPath | Where-Object { $_.Name -match 'infl' }).FullName
        # When taking in a user supplied path, need to change, this will make sure there's a appended '/'
        # then strip away drive letter and change backslashs to forward( '\' to '/' ), and get rid of any
        # double slashes.  Then we'll updated the influxdb.conf.
        $IDataPath = "$MonitoringPath/".replace((resolve-path $MonitoringPath).Drive.Root, '').replace("\", "/").Replace("//", "/")
        $content = [System.IO.File]::ReadAllText("$Influx\influxdb.conf").Replace("/var/lib/influxdb", "/$($IDataPath)InfluxData/var/lib/influxdb")
        [System.IO.File]::WriteAllText("$Influx\influxdb.conf", $content)
        [Environment]::SetEnvironmentVariable("Home", $Influx, "Machine")

        #Install NSSM
        GetAndInstall "NSSM" $NSSMVersion $MonitoringPath

        #Install Telegraf
        GetAndInstall "Telegraf" $TelegrafVersion $MonitoringPath

        #Setup Services
        $NSSM = (get-childitem $MonitoringPath | Where-Object { $_.Name -match 'nssm' }).FullName
        $NSSMEXE = "$nssm\win64\nssm.exe"
        Write-Output "[$(Get-Date)] Installing EUCMonitoring-grafana-server as a service"
        & $nssmexe Install "EUCMonitoring-grafana-server" $Grafana\bin\grafana-server.exe
        # & $nssmexe Set "Grafana Server" DisplayName "Grafana Server"
        Write-Output "[$(Get-Date)] Installing EUCMonitoring-influxdb as a service"
        & $nssmexe Install "EUCMonitoring-influxdb" $Influx\influxd.exe -config influxdb.conf
        # & $nssmexe Set "InfluxDB Server" DisplayName "InfluxDB Server"
        Write-Output "[$(Get-Date)] Starting Services"
        start-service "EUCMonitoring-grafana-server"
        start-service "EUCMonitoring-influxdb"
        Write-Output "[$(Get-Date)] Creating EUCMonitoring database on InfluxDB"
        & $Influx\influx.exe -execute 'Create Database EUCMonitoring'

        # need to import eventually grafana pages.
        Push-Location $grafana\bin
        #    & .\Grafana-cli.exe plugins install btplc-status-dot-panel
        #    & .\Grafana-cli.exe plugins install vonage-status-panel
        #    & .\Grafana-cli.exe plugins install briangann-datatable-panel
        & .\Grafana-cli.exe plugins install grafana-piechart-panel
        Write-Output "[$(Get-Date)] Restarting Grafana Server"
        stop-service "EUCMonitoring-grafana-server"
        start-service "EUCMonitoring-grafana-server"

        Write-Output "[$(Get-Date)] Setting up Grafana..."
        start-sleep 10

        # Setup Grafana
        Write-Output "[$(Get-Date)] You need to change your default admin password for Grafana. "
        Write-Output "The initial login will be admin / admin"
        Start-Process "http://localhost:3000"
        $Credential = (Get-Credential -Username admin -Message "Input your new Grafana admin password")

        $pair = "admin:$($Credential.GetNetworkCredential().Password)"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $basicAuthValue = "Basic $base64"
        $headers = @{ Authorization = $basicAuthValue }

        Write-Output "[$(Get-Date)] Setting up Grafana Datasource"
        $datasourceURI = "http://localhost:3000/api/datasources"
        # $inFile = $dashDatasource

        $Body = @{
            name      = "EUCMonitoring"
            type      = "influxdb"
            url       = "http://localhost:8086"
            database  = "EUCMonitoring"
            access    = "proxy"
            basicAuth = $false
        }

        $Catch = Invoke-WebRequest -Uri $datasourceURI -Method Post -Body (Convertto-Json $Body) -Headers $headers -ContentType "application/json" -UseBasicParsing

        Write-Output "[$(Get-Date)] Skipping Dashboard Import, please do manually after configuring Telegraf"

        #Write-Output "[$(Get-Date)] Setting up Grafana Dashboards"
        #Write-Output "[$(Get-Date)] Using $DashboardConfig\Dashboards"
        #$dashs = get-childitem $PSScriptRoot\*.json
        #$dashboardURI = "http://localhost:3000/api/dashboards/import"
        #foreach ( $dashboard in $dashs ) {
        #    $inFile = $dashboard.fullname
        #    $Catch = Invoke-WebRequest -Uri $dashboardURI -Method Post -infile $infile -Headers $headers -ContentType "application/json"
        #}


        #        Write-Output "[$(Get-Date)] Setting up Grafana Homepage"
        #        $Catch = Invoke-WebRequest -URI "http://localhost:3000/api/search?query=EUCMonitoring" -outfile .\home.json -header $headers -UseBasicParsing
        #        $GrafanaConfig = Get-Content -Raw -Path .\home.json | ConvertFrom-Json
        #        $SiteID = $GrafanaConfig.id
        #        $GrafanaConfig = "{""theme"": """",""homeDashboardId"":$SiteID,""timezone"":""browser""}"
        #        Remove-Item .\home.json


        # $Catch = Invoke-WebRequest -URI "http://localhost:3000/api/org/preferences" -method PUT -body $GrafanaConfig -header $headers -ContentType "application/json" -UseBasicParsing

        # This is to avoid the assigned and never used checks.
        Pop-Location

        # Purely to pass variable checks
        $Catch = ""
        Write-Verbose $Catch

        $Telegraf = (get-childitem $MonitoringPath | Where-Object { $_.Name -match 'Telegraf' }).FullName
        Write-Output "[$(Get-Date)] Configuring Telegraf"
        Write-Output "[$(Get-Date)] Overwriting Telegraf config"
        @"
[agent]
    interval = "5m"
[[outputs.influxdb]]
    url = "http://127.0.0.1:8086" # Required
    database = "EUCMonitoring" # Required

[[inputs.exec]]
    # Use forward slashes for the path. Change if needed.
    commands = [
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $(Join-Path $MonitoringPath -ChildPath "Get-CADCOverview.ps1")",
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $(Join-Path $MonitoringPath -ChildPath "Get-CADVOverview.ps1")"
    ]
    timeout = "5m"
    data_format = "influx"
"@ | Out-File (Join-Path $Telegraf -ChildPath "telegraf.conf" ) -Force
        Write-Output "[$(Get-Date)] Installing telegraf as a service"
        Start-Process "$Telegraf\telegraf.exe" -ArgumentList "--service install --service-name=EUCMonitoring-telegraf --service-display-name=EUCMonitoring-telegraf --config=$Telegraf\telegraf.conf" -Wait

        Write-Output "`nNOTE: Grafana, Influx, and Telegraf are now installed as services."
        Get-Service EUCMonitoring* | Select-Object Status, Name, StartType
        Write-Output "`nTo follow up, configure Telegraf instance in $MonitoringPath as described in Readme.md by testing"
        Write-Output "the input.exec scripts, start the service as appopriate user and then inport the dashboards to grafana."
        #Write-Output "Please edit the json config template, setting the Influx enabled to true amongst your other changes"
        #Write-Output "and save as euc-monitoring.json.`n"
        #& "C:\Windows\System32\notepad.exe" $MonitoringPath\euc-monitoring.json

        #Write-Output "After configuring, run Begin-EUCMonitoring under appropriate privs.  Each refresh cycle"
        #Write-Output "it will upload to local influxdb as a single timestamp. You might want to invoke it like:"
        #Write-Output "> $MonitoringPath\Begin-EUCMonitor.ps1 -MonitoringPath $MonitoringPath"
        #Write-Output " - or - "
        #Write-Output "> Set-Location $MonitoringPath; .\Begin-EUCMonitor.ps1"
    }

    end {

    }
}

# If you want to overwrite any of these with local paths to the .zip, you can and it will work for
# offline installs.
$Params = @{
    MonitoringPath  = "C:\Monitoring"
    GrafanaVersion  = "https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-6.2.5.windows-amd64.zip"
    InfluxVersion   = "https://dl.influxdata.com/influxdb/releases/influxdb-1.7.6_windows_amd64.zip"
    NSSMVersion     = "https://nssm.cc/release/nssm-2.24.zip"
    TelegrafVersion = "https://dl.influxdata.com/telegraf/releases/telegraf-1.11.0_windows_amd64.zip"
}
Install-VisualizationSetup @Params