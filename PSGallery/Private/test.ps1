function Get-TestValue {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $ADCSession,

        [parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = 'Stat')]
        [ValidateNotNullOrEmpty()]
        $Stat,

        [parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = 'Config')]
        [ValidateNotNullOrEmpty()]
        $Config,

        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [Alias("LogPath")]
        [string]$ErrorLogPath
    )

    write "$ADCSession -> "


    if ($PSBoundParameters.ContainsKey('Stat')) {
        $Uri = "https://$($ADCSession)/nitro/v1/stat/$Stat"
    }
    elseif ($PSBoundParameters.ContainsKey('Config')) {
        $Uri = "https://$($ADCSession)/nitro/v1/config/$Config"
    }
    else {
        $Uri = "NOTHING!!!"
    }

    write "$Uri"
}

Get-TestValue -ADCSession "123123.123123" -Stat "MyBalls"
Get-TestValue -ADCSession "Path" -Config "Whatever"

