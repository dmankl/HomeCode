$Directory = "Z:\media"
Write-Host "Working in $Directory"
$Method = "Exclude"#Rename,Exclude,Verify
$Exclud = "C:\temp\Exclude.txt"
$Filename = "C:\temp\Filename.txt"
$FileList = Get-Content -Path "$Exclud"
if ($null -eq $Method) {
    Write-Host "Please Specify Method"
    Break
}
#Gets The Videos To Convert
$Videos = Get-ChildItem $Directory -Recurse -Exclude "*_MERGED*" | Where-Object { $_ -notin $FileList -and $_.extension -in ".mp4", ".mkv", ".avi", ".m4v", ".wmv"} | ForEach-Object { $_.FullName } | Sort-Object
$Count = $Videos.count
Write-Host "$Count Files to be $Method."
#Video Batch
Foreach ($Video in $Videos) {
    if ($Method -eq "Exclude") {
        Add-Content $Exclud "$Video"
    }
    if ($Method -eq "Rename") {
        if ("$Video" -match ',') {
            $Vidz = $Video -replace ',', ''
            Rename-Item -Path $Video -NewName $Vidz
        }
        if ("$Video" -match ';') {
            $Vidz = $Video -replace ';', ''
            Rename-Item -Path $Video -NewName $Vidz
        }
    } 
    if ($Method -eq "Verify") {
        if ("$Video" -match ',') {
            $Vidz = $Video -replace ',', ''
            Add-Content $Filename "$Video"
        }
        if ("$Video" -match ';') {
            $Vidz = $Video -replace ';', ''
            Add-Content $Filename "$Video"
        }
    }
}


