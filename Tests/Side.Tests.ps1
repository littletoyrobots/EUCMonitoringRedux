


Test-EUCLicense -ComputerName "ddc1" -XdLicense -RdsLicense -Verbose

Test-EUCServer -Series "XdController" -ComputerName "ddc1", "ddc2" -Ports 80, 443 -Verbose  

# Must be run per site. 


$Input = [PSCustomObject]@{
    Series     = "TestSeries"
    Host       = "HostName"
    Test       = "TestName"
    Temp       = 111
    Giggles    = $true
    Percentage = 97
}
ConvertTo-InfluxLineProtocol -InputObject $Input, $Input -Verbose