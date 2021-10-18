#Future addition- check if your CPU/GPU Is capable of transcoding.
function Confirm-CompatibleHardwareEncoder {
    $Url = "https://raw.githubusercontent.com/dmankl/HomeCode/master/GPU.csv"
    $GPUs = Invoke-WebRequest -Uri $Url -UseBasicParsing | ConvertFrom-Csv
    $graphicsCards = @(Get-CimInstance win32_VideoController) | Where-Object {$_.VideoProcessor -like "NVIDIA*"} | ForEach-Object {$_.VideoProcessor -Replace 'NVIDIA ', ''}
    $supportedGPU = @()
    ForEach ($Graphic in $graphicsCards) {
        if ($GPUs.gpu -contains $Graphic) {
            $supportedGPU += $Graphic
        }
    }
    if ($supportedGPU.count -ge 0) {
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
