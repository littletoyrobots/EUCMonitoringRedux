Function Convert-EUCResultToInfluxFormat {
    <#
    .SYNOPSIS
    Short description
    
    .DESCRIPTION
    Long description
    
    .PARAMETER OU
    Parameter description
    
    .PARAMETER Department
    Parameter description
    
    .EXAMPLE
    An example
    
    .NOTES
    General notes
    #>
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        $SeriesResults,
        [switch]$IncludeTimeStamp
    )
    Begin {
        Write-Verbose "[$(Get-Date) BEGIN  ] $($myinvocation.mycommand)"

    } #BEGIN
		
    Process { 
        Write-Verbose "[$(Get-Date) PROCESS] Initializing variables"
        
        if ($IncludeTimeStamp) {
            Write-Verbose "[$(Get-Date) PROCESS] Fetching timestamp"
            $Timestamp = Get-InfluxTimestamp
        }
        else { 
            Write-Verbose "[$(Get-Date) PROCESS] No timestamp"
        }

        $Series = $SeriesResults.Series
        
        Write-Verbose "[$(Get-Date) PROCESS] Converting results to Influx Line Protocol"
        
        foreach ($Result in $SeriesResults) {
            Write-Verbose "[$(Get-Date) PROCESS] Converting result for $($Result.ComputerName)"
            $ParamString = ""
            
            # Ports
            foreach ( $Port in $Result.PortsUp ) {
                if ( $ParamString -eq "" ) { $ParamString = "Port$Port=1" } 
                else { $ParamString += ",Port$Port=1" }
            }
            foreach ( $Port in $Result.PortsDown ) {
                if ( $ParamString -eq "" ) { $ParamString = "Port$Port=0" } 
                else { $ParamString += ",Port$Port=0" }
            }

            # Services
            foreach ( $Service in $Result.ServicesUp ) {
                if ( $ParamString -eq "" ) { $ParamString = "$Service=1" } 
                else { $ParamString += ",$Service=1" }
            }
            foreach ( $Service in $Result.ServicesDown ) {
                if ( $ParamString -eq "" ) { $ParamString = "$Service=0" } 
                else { $ParamString += ",$Service=0" }
            }

            # Special Tests
            foreach ( $Test in $Result.TestsUp ) {
                if ( $ParamString -eq "" ) { $ParamString = "$Test=1" } 
                else { $ParamString += ",$Test=1" }
            }
            foreach ( $Test in $Result.TestsDown ) {
                if ( $ParamString -eq "" ) { $ParamString = "$Test=0" } 
                else { $ParamString += ",$Test=0" }
            }

            if ( "" -ne $ParamString ) {
                # Stoplight Tests
                if ( "UP" -eq $Result.State ) { $ParamString += ",State=2" }
                elseif ( "DEGRADED" -eq $Result.State ) { $ParamString += ",State=1" }
                else { $ParamString += ",State=0" }
                
                $ParamString = $ParamString -replace " ", "\ "
                if ($IncludeTimeStamp) {
                    $PostParams = "$Series,Server=$($Result.ComputerName) $ParamString $Timestamp"
                }
                else {
                    $PostParams = "$Series,Server=$($Result.ComputerName) $ParamString"
                }
                Write-Verbose "[$(Get-Date) PROCESS] $PostParams"
            }
            else {
                Write-Verbose "[$(Get-Date) PROCESS] No binary Tests data"
            }



            Write-Verbose "[$(Get-Date) PROCESS] Populating additional test data"
            foreach ($Testdata in $Result.TestData) {
                
                $ParamString = ""
                $TestDataName = $TestData.TestName
                $SeriesString = "$Series-$TestDataName,Server=$($Result.ComputerName)"

                <# This is the only tricky part of the script.  This is what we're grabbing:
                # $Result.TestsData has two properties, a string TestName and array TestValues.
                # TestValues are defined by the test, so we take the property name from the PSObject
                # and its value, which are unknown to us.  

                # So here's how gnarly one of these returned objects can look, in JSON form because
                surprisingly, its easier to read.  
{
    "Series":  "Worker",
    "Results":  
    [
        {
            "ComputerName":  "ddc1.mydomain.com",
            "State": "UP",
            "PortsUp": [],
            "PortsDown": [],
            "ServicesUp": [],
            "ServicesDown": [],
            "TestsUp":  
            [
                "XdServer",
                "XdDesktop",
                "XdSessionInfo"
            ],
            "TestsDown":  [],
            "TestData":  
            [
                {
                    "TestName":  "XdServer",
                    "TestValues":  
                    {
                        "SiteName":  "XA7X",
                        "WorkLoad":  "server",  <- Trying to grab both the name, and the value at this level
                        "ConnectedUsers":  269,
                        "DisconnectedUsers":  17,
                        "DeliveryGroupsNotInMaintenance":  9,
                        "DeliveryGroupsInMaintenance":  1,
                        "BrokerMachineOn":  37,
                        "BrokerMachineOff":  0,
                        "BrokerMachineRegistered":  40,
                        "BrokerMachineUnRegistered":  0,
                        "BrokerMachineInMaintenance":  0,
                        "BrokerMachinesGood":  36,
                        "BrokerMachinesBad":  1
                    }
                }, 
                {
                    "TestName": "XdDesktop"
                    ...                            
                }
            ],    
            "Errors": 
            [
                "XA7Z1 has not been booted in 42 days"
            ]
        }
    ]
}, 
{ 
    "Series" : "Something else"
    ...
                #>               
                $TestData.Values.PSObject.Properties | ForEach-Object {
                    # We take string data as tags.
                    if ($_.Value -is [string]) { $SeriesString += ",$($_.Name)=$($_.Value)" }
                    else {
                        if ( $ParamString -eq "" ) { $ParamString = "$($_.Name)=$($_.Value)" } 
                        else { $ParamString += ",$($_.Name)=$($_.Value)" }
                    }
                }

                if ( "" -ne $ParamString ) {
                    $SeriesString = $SeriesString -replace " ", "\ "
                    $ParamString = $ParamString -replace " ", "\ "
                    if ($IncludeTimeStamp) {
                        $PostParams = "$SeriesString $ParamString $timeStamp"
                    }
                    else {
                        $PostParams = "$SeriesString $ParamString"
                    }
                    Write-Verbose "[$(Get-Date) PROCESS] $PostParams"
                }
                else {
                    Write-Verbose "[$(Get-Date) PROCESS] No additional test data"
                }
            }
        }

        Write-Verbose "[$(Get-Date) PROCESS] Creating Parameter String"

    } #PROCESS

    End {
        Write-Verbose "[$(Get-Date) END    ] $($myinvocation.mycommand)"

    }
}

Convert-EUCResultToInflux -Results "wheeee"