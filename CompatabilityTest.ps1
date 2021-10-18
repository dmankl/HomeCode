#Future addition- check if your CPU/GPU Is capable of transcoding.
$FFMPEG = "C:\FFMPEG"
$Resources = "C:\FFMPEG\_Conversion"
If (!( Test-Path -Path $Resources )) { New-Item -Path $FFMPEG -Name "_Conversion" -ItemType "Directory" }   
$GPU = "$Resources\GPU.csv"
If (!( Test-Path -Path $GPU )) { 
    $Url = "https://raw.githubusercontent.com/dmankl/HomeCode/master/GPU.csv"
    Invoke-WebRequest -Uri $Url -OutFile $GPU
}
$GPUs = Import-Csv -Path $GPU 
ForEach ($Graphic in (Get-CimInstance win32_VideoController).VideoProcessor) {
    if ($GPUs.gpu -contains $Graphic) {
        $Compatible = "Yes"
    }
}

if ($Compatible -eq "Yes") {
    Read-Host "Congratulations! You can convert videos!"
}else {
    Read-Host "It seems you do not have a compatible CPU/GPU to convert to HEVC, Exiting."
    Break
}