[![Build status](https://ci.appveyor.com/api/projects/status/2vqac71nlbma0vx2?svg=true)](https://ci.appveyor.com/project/littletoyrobots/eucmonitoringredux)

# EUCMonitoringRedux

## Project Description

This is a continuation of the [EUCMonitoring Platform](http://bretty.me.uk/free-citrix-xendesktop-7-monitoring-platform/) that is based on Powershell and FREE! It will check all the key components of your End User Computer estate and give you a visual dashboard as to its current health. It is currently focused on Citrix but will eventually be branched out to cover VMware and Microsoft Technologies.

This continuation is organized in such a way that you could take advantage of the [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) agent for collecting and reporting metrics. In its simplest form, the telegraf agent works like a scheduled task running every 5 minutes, invoking a powershell script that outputs to [Influx Line Protocol](https://docs.influxdata.com/influxdb/v1.7/write_protocols/line_protocol_tutorial/). Telegraf takes that output and redirects it to any of its supported time series databases. I like [InfluxDB (v1)](https://www.influxdata.com/products/influxdb-overview/). We then configure Grafana to point to InfluxDB and visualize the results. It will create a local log file of any errors it finds, and will eventually make the static HTML file as well.

## Motivation

[Dave Bretty](https://bretty.me.uk) initially created this in order to provide a birds eye view of what's happening in the environment. Along with others in the community, I wanted to extend the functionality he initially created, especially in a more dynamic dashboard. I also want to be able to use building a monitoring platform as a way of teaching new users about various EUC platforms, by way of knowing what to look for.

## Installation

To install and run this software, follow these steps.

### Pre-requisites

#### On-Premises

- For Citrix Apps and Desktops, the server that you want to run this script from must have the XenDesktop Powershell SDK Installed.
- For Citrix Hypervisor, you must also install the XenServer SDK from the [XenServer](https://www.citrix.com/downloads/xenserver/product-software.html) download page.
- VMWare support will be forthcoming.

#### Cloud

The Server that you want to run this script from must have the Remote [PowerShell SDK for Applications and Desktops Service](http://download.apps.cloud.com/CitrixPoshSdk.exe):

Obtain a Citrix Cloud automation credential as follows:

- Login to <https://citrix.cloud.com/>
- Navigate to "Identity and Access Management".
- Click "API Access".
- Enter a name for Secure Client and click Create Client.
- Once Secure Client is created, download Secure Client Credentials file (ie. downloaded to C:\Monitoring)

Note the Customer ID located in this same page, this is case senstitive.

```
Set-XDCredentials -CustomerId "%Customer ID%" -SecureClientFile "C:\Monitoring\secureclient.csv" -ProfileType CloudApi -StoreAs "CloudAdmin"
```

NOTE: **XdServerBrokers/XdDesktopBrokers** should be set as the Citrix Cloud Connector, the cloud connectors will proxy the connection directly to the Delivery Controller as they are not directly accessible.

#### InfluxDB

While Telegraf can export to [various destinations](https://github.com/influxdata/telegraf#output-plugins), InfluxDB is probably the easiest to set up across different platforms.

### Installation Steps

1. Make sure any prerequisites are met.
1. Download the EUCMonitoringRedux Module. Hopefully will have in PSGallery soon.
1. Create `C:\Monitoring`
1. Download Telegraf from [here](https://portal.influxdata.com/downloads)
1. Create the directory `C:\Program Files\Telegraf` on your target machine.
1. Download EUCMonitoring.conf and EUCMonitor.ps1 from [here](https://github.com/littletoyrobots/EUCMonitoringRedux/tree/master/Config)
1. Place telegraf.exem, telegraf.conf, EUCMonitoring.conf, and EUCMonitor.ps1 files in `C:\Program Files\Telegraf`. Unblock those files.
1. Install as a service by running the following in Powershell as an administrator:

```powershell
> "C:\Program Files\Telegraf\telegraf.exe" --service install --config "C:\Program  Files\Telegraf\EUCMonitoring.conf"
```

1. Edit the EUCMonitoring.conf file for your environment. The default values assume a local install.
1. Edit the EUCMonitor.ps1 file for your environment.
1. To check that it works, run:

```powershell
> "C:\Program Files\Telegraf\telegraf.exe" --config "C:\Program Files\Telegraf\EUCMonitoring.conf" --test
```

1. To start collecting data, run:

```powershell
> start-service telegraf
```

## Active Contributors

Dave Brett [@dbretty](https://twitter.com/dbretty) | James Kindon [@james_kindon](https://twitter.com/james_kindon) | Ryan Butler [@ryan_c_butler](https://twitter.com/Ryan_C_Butler) | David Wilkinson [@WilkyIT](https://twitter.com/WilkyIT) | Adam Yarborough [@littletoyrobots](https://twitter.com/littletoyrobots) | Hal Lange [@hal_lange](https://twitter.com/hal_lange) | Ryan Revord [@rsrevord](https://twitter.com/rsrevord) | Alex Spicola [@alexspicola](https://twitter.com/AlexSpicola)
