#Future addition- check if your CPU/GPU Is capable of transcoding.
function Confirm-CompatibleHardwareEncoder {
    $Resources = "C:\FFMPEG\_Conversion"
    If (!( Test-Path -Path $Resources )) { New-Item -Path $FFMPEG -Name "_Conversion" -ItemType "Directory" }   
    $Url = "https://raw.githubusercontent.com/dmankl/HomeCode/master/GPU.csv"
    $GPUs = Invoke-WebRequest -Uri $Url -UseBasicParsing | ConvertFrom-Csv
    $graphicsCards = @(Get-CimInstance win32_VideoController)
    $supportedGPU = @()
    ForEach ($Graphic in $graphicsCards) {
        if ($GPUs.gpu -contains $Graphic.VideoProcessor) {
            $supportedGPU += $Graphic
        }
    }
    
    if ($supportedGPU.count -ge 1) {
        return $true
    }
    else {
        return $false
    }
}

if (Confirm-CompatibleHardwareEncoder) {
    Read-Host "Congratulations! You can convert videos!"
}else {
    Read-Host "It seems you do not have a compatible CPU/GPU to convert to HEVC, Exiting."
    Break
}