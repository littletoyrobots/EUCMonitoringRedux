# Todo List

1. Look into [Invoke-CommandAs](https://github.com/mkellerman/invoke-commandas) into invoke certain parts as
   a different user (allowing Telegraf to run as system)
1. Breakout dashboard folders for target visualization
   - Grafana Dashboards
   - Azure Monitoring Dashboards
   - Chronograf Dashboards
1. Breakout common dashboard scripts / examples scripts to separate folder
1. Add parameters to support passing a session to the get-CADC commands.
1. Refactor Get-CADCNitroValue to take credentials and IP as well as ADCSession.
1. Static HTML page -> ConvertTo-EUCResultHTML.ps1
1. Read config and tests from JSON file
1. Get Start-EUCMonitor.ps1 working for legacy support
1. Make in-place upgrade script, preferably named Upgrade-VisualizationSetup.ps1
1. Make in-place dashboard upgrade script that can target either local or remote grafana instances (with proper credentials)
