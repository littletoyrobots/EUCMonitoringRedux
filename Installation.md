# Installation instructions for EUCMonitoringRedux

## Pre-requisites

#### Citrix On-Premises

- For Citrix Apps and Desktops, the location that you want to run this script from must have the XenDesktop Powershell SDK Installed. This is most easily installed by just installing Citrix Studio.

#### Citrix Cloud

The Server that you want to run this script from must have the Remote [PowerShell SDK for Applications and Desktops Service](http://download.apps.cloud.com/CitrixPoshSdk.exe):

Obtain a Citrix Cloud automation credential as follows:

- Login to <https://citrix.cloud.com/>
- Navigate to "Identity and Access Management".
- Click "API Access".
- Enter a name for Secure Client and click Create Client.
- Once Secure Client is created, download Secure Client Credentials file (ie. downloaded to C:\Monitoring)

Note the Customer ID located in this same page, this is case sensitive.

```Powershell
Set-XDCredentials -CustomerId "%Customer ID%" -SecureClientFile "C:\Monitoring\secureclient.csv" -ProfileType CloudApi -StoreAs "CloudAdmin"
```

NOTE: In the provided scripts **Broker** or **CloudConnector** should be set as the Citrix Cloud Connectors for the site, the cloud connectors will proxy the connection directly to the Delivery Controller as they are not directly accessible.

#### Others

RDS / VMware support will be forthcoming

## Method 1 - The local try-it-out method

This is somewhat interactive until the initial Grafana user config is able to be bypassed.

NOTE: This will install local instances of influxdb, grafana, and telegraf agent on your machine to `C:\Monitoring`, then allow you to edit and import the dashboards

1. Download [EUCMonitoringRedux](https://github.com/littletoyrobots/EUCMonitoringRedux/archive/master.zip) zip file wherever you like.
1. Create your target install directory, I choose `C:\Monitoring`
1. Right-click the zip -> Properties -> Unblock.
1. Right-click the zip-> Extract All and extract directly to your install directory, `C:\Monitoring`. It should leave a `C:\Monitoring\EUCMonitoringRedux-master` folder.

   Note: If you need a local-only (no internet access) or different directory for the install, edit the params in EUCMonitoringRedux\Config\Install-VisualizationSetup.ps1 at the bottom to point to the paths of the appropriate installer zips. Else, the defaults will fetch the required software for you. If local-only, you might get error messages about grafana plugin installation and some dashboards might not display correctly.

1. In powershell, running as Administrator,

   ```powershell
   set-location C:\Monitoring\EUCMonitoringRedux-master\Config
   .\Install-VisualizationSetup.ps1
   ```

### Configure Telegraf

Telegraf will run powershell scripts for you and push the data straight into your target data source, as long as they output to the correct format. I have some simple scripts to return objects in powershell, and then convert those objects to Influx Line Protocol so that telegraf can handle the transport for me.

1. Go to the base directory, `C:\Monitoring`
1. Edit each of the script files and give them a test run in powershell console. You'll need to change parameters for your environment. You should see no error messages or verbose output when you're complete.
1. Measure the execution of each of these scripts for your environment. By default, the telegraf.conf file is configured to poll every 5 minutes. If any script takes longer than that to execute, there will be issues down the line. This is also a good time to verify that invoking the scripts does not affect your environment's performance negatively.

   ```powershell
   $LastCmd = Get-History -Count 1
   $LastCmd.EndExecutionTime.Subtract($LastCmd.StartExecutionTime).TotalSeconds
   ```

1. Test the telegraf instance and verify no errors in output

   ```powershell
   set-location C:\Monitoring\telegraf
   .\telegraf.exe --config telegraf.conf --test
   ```

1. Set the telegraf service Log On to a user with appropriate permissions to run the scripts. Read-Only administrator role should be fine.
1. Start the EUCMonitoring-telegraf service.

### Log into Grafana

NOTE: As this grows, more scripts and dashboards will be created. There might be one big easy script eventually, or a json fed script that calls the smaller functions, but for now, we're starting small.

1. When the testing is complete, browse to `http://localhost:3000`
1. The initial login will be username: `admin` password: `admin`, and you'll be prompted to change it. Please do.
1. After login, at the top of the page, there will be a drop down where you can select the dashboards you wish to see.

### Uninstall

Note: If you made any changes to the Install-VisualizationSetup, edit Uninstall-VisualizationSetup appropriately.

In powershell, running as Administrator

```powershell
set-location Path\to\EUCMonitoringRedux\Dashboard
.\Uninstall-VisualizationSetup.ps1
```

## Method 2 - Setup environment for long term

1. Install the module. It will soon be available in the PSgallery, but until then, you can create an EUCMonitoringRedux folder in `C:\program files\WindowsPowerShell\Modules\` and copy the PSGallery directory contents there. You'll need to update any scripts invoked by telegraf to import the module by name instead of by path.
1. Install influxdb and grafana on dedicated host. There are many wonderful guides on this online, most involve a linux box somewhere. There are even [Raspberry Pi](https://www.influxdata.com/blog/running-the-tick-stack-on-a-raspberry-pi/) installs
1. Create an EUCMonitoring database on influx

   ```influxql
   InfluxDB shell 1.7.x
   > CREATE DATABASE EUCMonitoring
   ```

1. Unzip telegraf on the endpoint you wish to run the scripts from. Edit telegraf.conf outputs.influxdb url to your long term instance with the database "EUCMonitoring", and to include any scripts you want in the input.exec section after testing them. See `Config\telegraf.conf` for extremely simplified example.
1. From command prompt, run a single telegraf collection, outputting metrics to stdout and make sure you see no errors.

   ```cmd
   set-location C:\Monitoring\telegraf
   .\telegraf.exe --config telegraf.conf --test
   ```

   Note that the encoding is UTF8, so using Notepad++ is preferred. You might get weird encoding errors.

1. Next, to setup as a separate From an elevated command prompt

   ```cmd
   telegraf.exe --service install --service-name=EUCMonitoring-telegraf --service-display-name=EUCMonitoring-telegraf --config=C:\Full\Path\To\telegraf.conf
   ```

1. Reevaluate the method of storing credentials in the sample scripts, or write your own. You might find you want to user something like Marc Kellerman's [Invoke-CommandAs](https://github.com/mkellerman/invoke-commandas) if you want to run the telegraf agent as its default system user.
1. In Grafana, configure EUCMonitoring as an InfluxDB data source
1. Start importing dashboards to the grafana server, making sure to select the EUCMonitoring data source.

## Post Install

### Authentication

Look into authentication of Influx and Grafana. You can create custom dashboards only visible particular users and departments. Update your telegraf.conf if you change InfluxDB's authentication.

### Make your own custom dashboards, or edit some of those provided

You know your environment better than anyone else.

Telegraf has an impressive list of [input plugins](https://github.com/influxdata/telegraf/tree/master/plugins/inputs) to collect data. You can easily collect whatever data your application exposes and then create a Grafana dashboard for it. For example, you could use [win_perf_counters](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/win_perf_counters) and Win10-1809+ / Server 2019's new [User Input Delay Counters](https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds-rdsh-performance-counters) to monitor specific applications that you care about, if you wanted to install the telegraf agent on your workers.

### Create a playlist

You can use playlists to cycle dashboards on TVs without user control. [Learn More](https://grafana.com/docs/reference/playlist/)

### Browse the Grafana Dashboards

Don't feel like you have to do it all. There are tons of great dashboards already created for multiple environments. Here are some suggestions:

- [Unifi Dashboards](https://grafana.com/grafana/dashboards?search=unifi)
- [vSphere Dashboards](https://grafana.com/grafana/dashboards?search=vsphere)

### Set up alerting

While the sample scripts have a section for emailing error logs, that might not be exactly what you're looking for. [Grafana alerts](https://grafana.com/docs/alerting/notifications/) can be set to Email, Slack, PagerDuty, and more.

### Share

Have a great script or dashboard suggestion you'd like to see implemented? Check out [Contributing](https://github.com/littletoyrobots/EUCMonitoringRedux/blob/master/.github/CONTRIBUTING.md) or stop by the #-eucmonitoring channel on [World of EUC on Slack](https://communityinviter.com/apps/worldofeuc/world-of-euc-project) and share it with us!
