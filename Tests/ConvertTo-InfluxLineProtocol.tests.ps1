

. "$env:APPVEYOR_BUILD_FOLDER\PSGallery\Public\ConvertTo-InfluxLineProtocol.ps1"

Describe "how to test converting to Influx Line Protocol" {
    It "Should return `$null for empty InputObject" {
        $null | ConvertTo-InfluxLineProtocol | Should -Be $null
    }

    It "Should return a known value for a known object" {
        [PSCustomObject]@{
            Series = "SeriesName"
            Tag    = "TagName"
            Value  = 1234
        } | ConvertTo-InfluxLineProtocol | Should -Be "SeriesName,Tag=TagName Value=1234"
    }

    It "Should return a known value for a known object with a supplied timestamp" {
        [PSCustomObject]@{
            Series = "SeriesName"
            Tag    = "TagName"
            Value  = 1234
        } | ConvertTo-InfluxLineProtocol -Timestamp 5678 | Should -Be "SeriesName,Tag=TagName Value=1234 5678"
    }

    It "Should properly escape commas" {
        [PSCustomObject]@{
            Series = "SeriesName"
            Tag    = "Tag,Name"
            Value  = 1234
        } | ConvertTo-InfluxLineProtocol | Should -Be "SeriesName,Tag=Tag\,Name Value=1234"
    }

    It "Should properly escape `=" {
        [PSCustomObject]@{
            Series = "SeriesName"
            Tag    = "Tag=Name"
            Value  = 1234
        } | ConvertTo-InfluxLineProtocol | Should -Be "SeriesName,Tag=Tag\=Name Value=1234"
    }

    It "Should properly escape spaces" {
        [PSCustomObject]@{
            Series = "SeriesName"
            Tag    = "Tag Name"
            Value  = 1234
        } | ConvertTo-InfluxLineProtocol | Should -Be "SeriesName,Tag=Tag\ Name Value=1234"
    }

    It "Should ignore empty string properties" {
        [PSCustomObject]@{
            Series = "SeriesName"
            Tag    = "TagName"
            Tag1   = ""
            Value  = 1234
        } | ConvertTo-InfluxLineProtocol | Should -Be "SeriesName,Tag=TagName Value=1234"
    }

    It "Should ignore `$null valued properties" {
        [PSCustomObject]@{
            Series = "SeriesName"
            Tag    = "TagName"
            Var1   = $null
            Value  = 1234
        } | ConvertTo-InfluxLineProtocol | Should -Be "SeriesName,Tag=TagName Value=1234"
    }

    It "Should throw error if no Series specified" {
        { [PSCustomObject]@{
                Tag   = "TagName"
                Value = 1234
            } | ConvertTo-InfluxLineProtocol } | Should -Throw "[ConvertTo-InfluxLineProtocol] Series Blank"
    }

    It "Should return known value if Series specified" {
        [PSCustomObject]@{
            Tag   = "TagName"
            Value = 1234
        } | ConvertTo-InfluxLineProtocol -Series "SeriesName" | Should -Be "SeriesName,Tag=TagName Value=1234"
    }

    It "Should override Series if specified by parameter" {
        [PSCustomObject]@{
            Series = "SeriesName"
            Tag    = "TagName"
            Value  = 1234
        } | ConvertTo-InfluxLineProtocol -Series "NewSeriesName" | Should -Be "NewSeriesName,Tag=TagName Value=1234"
    }
}