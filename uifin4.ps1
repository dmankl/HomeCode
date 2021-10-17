$FFMPEG = "C:\FFMPEG"
$Resources = "$FFMPEG\_Conversion"
$Log = "$Resources\ConversionLog.csv"
If (!( Test-Path -Path $Log )) { 
    $Logs = [pscustomobject]@{
        'Gpu' = ''
    }
    Export-Csv -InputObject $Logs -Path $Log -Delimiter "|" -NoTypeInformation
}
$B= Import-Csv $Log -Delimiter "|"
$TO= Get-Content C:\Temp\Exclude.txt

foreach ($BS in $TO) {
    
   Write-output "$BS" | Out-File -Encoding "utf8" $Log -Append
    
}

