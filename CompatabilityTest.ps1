#Future addition- check if your CPU/GPU Is capable of transcoding.
$FFMPEG = "C:\FFMPEG"
$Resources = "$FFMPEG\_Conversion"
If (!( Test-Path -Path $Resources )) { New-Item -Path $FFMPEG -Name "_Conversion" -ItemType "Directory" }   
$GPU = "$Resources\GPU.csv"
If (!( Test-Path -Path $GPU )) { 
    $Url = "https://raw.githubusercontent.com/dmankl/HomeCode/master/GPU.csv"
    $Output = "$GPU"
    Invoke-WebRequest -Uri $Url -OutFile $Output
}
$Compatible = "No"
$GPUs = Import-Csv -Path $GPU 
$graphics = (Get-CimInstance win32_VideoController).VideoProcessor
if ($graphics.Length -gt 1) {
    ForEach ($Graphic in $graphics) {
        if ($GPUs.gpu -contains $Graphic) {
            $Compatible = "Yes"
        }
    }
}
elseif ($GPUs.gpu -contains $graphics) {
    $Compatible = "Yes"
}

if ($Compatible -eq "No") {
    Read-Host "It seems you do not have a compatible CPU/GPU to convert to HEVC, Exiting."
    Break
}
elseif ($Compatible -eq "Yes") {
    Read-Host "Congratulations! You can convert videos!"
}