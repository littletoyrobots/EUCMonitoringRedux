# By default, Influx assumes UNIX timestamp with nanosecond precision

# Minimum valid timestamp is -9223372036854775806
# Maxmimum value timestamp is 9223372036854775806
$projectRoot = $env:APPVEYOR_BUILD_FOLDER

. "$env:APPVEYOR_BUILD_FOLDER\PSGallery\Public\Get-InfluxTimestamp.ps1"

Describe "how to test timestamp functions" {

    It "does not throw errors" {
        { (Get-InfluxTimestamp) } | Should -Not -Throw
    }

    It "returns an int64" {
        (Get-InfluxTimestamp) | Should -BeOfType [int64]
    }

    It "returns a value less than the max" {
        { Get-InfluxTimestamp -lt 9223372036854775806 } | Should -Be $true
    }

    It "returns a value greater than the lowest accepted value" {
        { Get-InfluxTimestamp -gt -9223372036854775806 } | Should -Be $true
    }

    It "returns a known value for a known datetime" {
        Get-InfluxTimestamp -DateTime ([datetime]"01/01/2020 00:00") | Should -Be 1577854800000000000
    }
}