function ConvertTo-InfluxLineProtocolTemp {
    param (
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [object[]]$InputObject,
        [string]$SeriesName,
        [int64]$Timestamp,
        [switch]$IncludeTimeStamp
    )

    Begin { }

    Process { }

    End { }
}