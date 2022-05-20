#Region Whole

#Region Intro
<#  Batch Convert to HEVC with FFMPEG using Nvidia graphics card or using your cpu
    This Script uses FFMPEG, If you do not have it then it will download it and put it in the right location
    The defaults For the conversion process are good but if you want better quality lower the number on line# 111 or 114
    If your video card is not capable of decoding HEVC video files will appear in the error log saying "Small Converted Video For",
    and the video path\name and adds it to the exclusion list to prevent multiple attempts.
    Uses ffprobe that is downloaded with ffmpeg to check if a file is already HEVC and skips it then adds it to the exclusion list.
    This script will make an Exclusion List, Log File, And an Error Log in a folder name "_Conversion",
    this helps speed up the processes if you need to stop the script and pick back up where you left off.
    Enjoy. -Dmankl
#>
#EndRegion Intro

#Region Functions
#Function to display Folder selector and exit script if cancelled
Function Get-Folder {
    Write-Host "Please select the folder you want to convert." -ForegroundColor Black -BackgroundColor White
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
        SelectedPath        = $LoadedDefaults.Path
        ShowNewFolderButton = $false
    }
    $Res = $FolderBrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
    if ($Res -ne "OK") {
        Break
    }
    else {
        Return     $FolderBrowser.SelectedPath 
    }
}
#Function to write into Logs
Function Show-Time($string) {
    $dateTimeNow = Get-Date -Format "HH:mm-MM.dd.yy"
    $outStr = "" + $dateTimeNow + " " + $string 
    Write-Output $outStr
}
function Confirm-CompatibleHardwareEncoder {
    $Url = "https://raw.githubusercontent.com/dmankl/HomeCode/master/GPU.csv"
    $GPUs = Invoke-WebRequest -Uri $Url -UseBasicParsing | ConvertFrom-Csv
    $graphicsCards = @(Get-CimInstance win32_VideoController) | Where-Object { $_.Name -like "NVIDIA*" -or $_.Name -like "AMD*" }
    $supportedGPU = @()
    ForEach ($Graphic in $graphicsCards) {
        if ($GPUs.gpu -contains $Graphic) {
            $supportedGPU += $Graphic
        }
    }
    if ($supportedGPU.count -ge 0) {
        if ($graphicsCards.Name -like "NVIDIA*") {
            Return "NVIDIA"
        }
        if ($graphicsCards.Name -like "AMD*") {
            Return "AMD"
        }
        else {
            Return "CPU"
        }
    }
    else {
        return $false
    }
}
#EndRegion Functions

<#Region Verification
if (Confirm-CompatibleHardwareEncoder -eq $False) {
    Read-Host "It seems you do not have a compatible CPU/GPU to convert to HEVC, Tryinng using CPU."
    
}
Write-Host "Verifying/Creating Supporting files."
#EndRegion Verification#>

#Region FFMPEG Files
$FFMPEG = "C:\FFMPEG"
$Resources = "$FFMPEG\_Conversion"
$Encoder = "$FFMPEG\bin\ffmpeg.exe"
If (!( Test-Path -Path $Encoder )) {
    if (!(Test-Path "C:\Temp")) {
        New-Item -Path "C:\" -Name "Temp" -ItemType "Directory"
    }
    if (!(Test-Path "$FFMPEG\bin")) {
        New-Item -Path "$FFMPEG" -Name "bin" -ItemType "Directory"
    }
    $Url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    $Output = "C:\Temp\ffmpeg.zip"
    Invoke-WebRequest -Uri $Url -OutFile $Output
    Expand-Archive -LiteralPath $Output -DestinationPath "C:\Temp"
    Copy-Item "C:\Temp\ffmpeg*\*" -Destination "$FFMPEG" -Recurse
    Remove-Item $Output
}
else {
    Write-Host "Found The files, Lets get started."
}
$Env:Path += "$FFMPEG\bin\"
#EndRegion FFMPEG Files

#Region Resource Files
$Probe = "$FFMPEG\bin\ffprobe.exe"
If (!( Test-Path -Path $Resources )) { New-Item -Path $FFMPEG -Name "_Conversion" -ItemType "Directory" }   
$Log = "$Resources\ConversionLog.csv"
If (!( Test-Path -Path $Log )) { 
    $Logs = [pscustomobject]@{
        'Event' = ''
    }
    Export-Csv -InputObject $Logs -Path $Log -Delimiter "|" -NoTypeInformation -Encoding utf8
}
$Xclude = "$Resources\Exclude.Csv"
If (!( Test-Path -Path $Xclude )) { 
    $Xclusions = [pscustomobject]@{
        'Path' = ''
        'File' = ''
    }
    Export-Csv -InputObject $Xclusions -Path $Xclude -Delimiter "|" -NoTypeInformation -Encoding utf8
}
$Rename = "$Resources\Rename.csv"
If (!( Test-Path -Path $Rename )) {     
    $Renames = [pscustomobject]@{
        'Path' = 'Null'
    }
    Export-Csv -InputObject $Renames -Path $Rename -Delimiter "|" -NoTypeInformation -Encoding utf8
}
$ErrorList = "$Resources\ErrorList.csv"
if (!(Test-Path $ErrorList)) {
    $Errors = [pscustomobject]@{
        'Error' = ''
        'File'  = ''
    }
    Export-Csv -InputObject $Errors -Path $ErrorList -Delimiter "|" -NoTypeInformation -Encoding utf8
}
$Default = "$Resources\Defaults.csv"
If (!( Test-Path -Path $Default )) { 
    $Defaults = [pscustomobject]@{
        'Path'    = ''
        'RanOnce' = ''
    }
    Export-Csv -InputObject $Defaults -Path $Default -Delimiter "|" -NoTypeInformation -Encoding utf8
}
$LoadedDefaults = Import-Csv -Path $Default -Delimiter "|"
$FileList = Import-Csv -Path $Xclude -Delimiter "|"
$Errors = Import-Csv -Path $ErrorList -Delimiter "|"
Clear-Host
#Endregion Resource Files

#Introduction
Write-Host "HEVC Conversion by DMANKL." -ForegroundColor Green
Write-host "This script is to convert videos into the HEVC codec."
#Provide SourceCode
Write-host "Current source code can be found at https://raw.githubusercontent.com/dmankl/HomeCode/master/HEVC_Conversion.ps1"
Write-Host "Warning! This script will modify files, exit now if you do not want this." -ForegroundColor DarkRed -BackgroundColor White
Read-Host "Press Enter to start."

#Region RanOnce
if ($LoadedDefaults.RanOnce -ne "Yes") {
    $Title = "Baseline"
    $Message = "Would you like to exclude your already converted files?"
    $Options = "&Yes", "&No"
    $DefaultChoice = 0
    $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

    switch ($Result) {
        "0" {
            #Creates/Adds Converted Videos to Exclusion List
            #Gets Directory 
            $Directory = Get-Folder
            Write-Host "Please wait while the exclusion list is being created."
            $Videos = Get-ChildItem $Directory -Recurse -Exclude "*_MERGED*" | Where-Object { $FileList.File -notcontains $_.BaseName -and $_.extension -in ".mp4", ".mkv", ".avi", ".m4v", ".wmv" } | ForEach-Object { $_.FullName } | Sort-Object 
            Foreach ($Video in $Videos) {
                $Vidtest = & $Probe -v error -show_format -show_streams $Video
                $Vid = (Get-Item "$Video").Basename
                if ($Vidtest -contains "codec_name=hevc") {
                    Write-Host "$Vid is already converted." -ForegroundColor Cyan
                    Write-Output "$Video | $Vid" | Out-File -encoding utf8 -FilePath $Xclude -Append
     
                }
            } 
            #Stores RanOnce into default CSV
            $LoadedDefaults | ForEach-Object { $LoadedDefaults.RanOnce = "Yes" } 
            $LoadedDefaults | Export-Csv -Encoding utf8 -Path $Default -Delimiter "|" -NoTypeInformation
        }
        "1" {
            #Stores RanOnce into default CSV
            $LoadedDefaults | ForEach-Object { $LoadedDefaults.RanOnce = "Yes" } 
            $LoadedDefaults | Export-Csv -Encoding utf8 -Path $Default -Delimiter "|" -NoTypeInformation
        }
  
    }
}
else {
    $Title = "Reset Defaults"
    $Message = "Do you need to reset your default settings, Press enter to continue?"
    $Options = "&Yes", "&No"

    $DefaultChoice = 1
    $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)
    switch ($Result) {
        "0" {
            Remove-Item $Default
            if (!(Test-path $default)) {
                Write-host "Reset complete,Exiting script.."
                Break
            }
        }
        "1" {
            Continue
        }
    }
}
#EndRegion RanOnce

#Region Script
if ($null -eq $Directory) {
    #Gets Directory 
    $Directory = Get-Folder
}

#Removes Commas
Write-host "Please wait while we verify video names will not ruin exclusion files."
$Videos = Get-ChildItem $Directory -Recurse -Exclude "*_MERGED*" | ForEach-Object { $_.FullName } | Sort-Object 
foreach ($Video in $Videos) {
    if ($Video.Contains(",")) {
        $Vidz = $Video -Replace ',', ''
        $Path = Split-Path $Vidz
        $VidBase = $Video.Basename
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -ItemType Directory
        }
        if (!(Test-Path $Vidz)) {
            Move-item -path $Video -Destination $Vidz
        }
        else {
            Write-Host "Duplicate $Vidbase Found, Please move manually."
            Write-Output "Duplicate file found | $Video" | Out-File -encoding utf8 -FilePath $ErrorList -Append
        }
    }
}
Clear-Variable -Name "Videos"
#Stores Directory into default CSV
$LoadedDefaults | ForEach-Object { $LoadedDefaults.Path = "$Directory" } 
$LoadedDefaults | Export-Csv -Encoding utf8 -Path $Default -Delimiter "|" -NoTypeInformation

#Transcript And Log Functions
$version = $PSVersionTable.PSVersion.toString()
If ($version -gt 5.9) { Start-Transcript -Path "$Log" -Append -UseMinimalHeader } 
Else { Start-Transcript -Path "$Log" -Append }

#Real start of the script       
#Gets The Videos To Convert, displays the amount of videos, progressbar 
Write-Host "Looking For Video Files. Please wait as this may take a while depending on the amount of files in the directories."
$Videos = Get-ChildItem $Directory -Recurse -Exclude "*_MERGED*" | Where-Object { $FileList.File -notcontains $_.BaseName -and $_.extension -in ".mp4", ".mkv", ".avi", ".m4v", ".wmv" } | ForEach-Object { $_.FullName } | Sort-Object 
$Count = $Videos.count
Show-Time "---Starting--Conversion--Process---"
Write-Host "$Count Videos to be processed." 

#Region VideoBatch
Foreach ($Video in $Videos) {
    #Video Scanner
    $Vidtest = & $Probe -v error -show_format -show_streams $Video 

    #Filename information 
    $RootDirectory = Split-Path $Video
    $Vid = (Get-Item "$Video").Basename
    $Output = "$RootDirectory\$($Vid)_MERGED.mkv"
    $Final = "$RootDirectory\$Vid.mkv"

    #DuplicateCheck
    $FileList = Import-Csv -Path $Xclude -Delimiter "|"
    $Files = $FileList.File
    if ($Files -contains $Vid) {
        Write-host "Found duplicate file- $Vid"
        Write-Output "Possible duplicate | $Video" | Out-File -encoding utf8 -FilePath $ErrorList -Append
    } 

    #Check If A Conversion Was Interrupted, Removes temp file if it was interrupted
    #If it was just not renamed it will rename it
    If ( Test-Path $Output ) {
        If ( Test-Path $Final ) {
            Remove-item $Output
            Show-Time
            Write-host "Previous $Vid Conversion failed. Removing The Traitor From Your Computer." -ForegroundColor Yellow 
            Write-output "Previous File Removed | $Video" | Out-File -encoding utf8 -FilePath $ErrorList -Append
        }
        Else {
            Rename-Item $Output -NewName $Final 
        }
    }           
            
    #Possible Duplicate check, Verifies there is another file, Checks if there was a converted file
    if ($Video -ne $Final) {            
        If ( Test-Path $Final ) {
            $FVidtest = & $Probe -v error -show_format -show_streams $Video 
            if ($FVidtest -contains "codec_name=hevc") {
                #If converted file is already HEVC removes about to be converted file
                Remove-Item $Video
                Write-Host "Found Already Converted file, Removing Non Converted File"
                Write-Output "Converted file found. | $Video" | Out-File -encoding utf8 -FilePath $ErrorList -Append
                Continue
            }
            else {
                #Removes video that would be duplicate
                Remove-Item $Final
                Write-Host "Found Duplicate Non-Converted file, Removing Non Converted File"
                Write-output "Non -Converted file found. | $Final" | Out-File -encoding utf8 -FilePath $ErrorList -Append
            }
        }
    }
           
    #Checks if video is already HEVC, if it is then it will be added to exclusion list then move to the next video
    if ($Vidtest -contains "codec_name=hevc") {
        Write-Host "$Vid is already converted." -ForegroundColor Cyan
        Write-Output "$Video | $Vid" | Out-File -encoding utf8 -FilePath $Xclude -Append
    } 
    else {   
        #Converts video If it is not already HEVC
        #Gets Current File Size
        $OSize = [math]::Round(( Get-Item $Video ).Length / 1MB, 2 )        
        Show-Time
        Write-Host "Processing $Vid, It is currently $OSize MBs. Please Wait."
                
        #Converts video Depending on onfirm-CompatibleHardwareEncoder Function.
        switch (Confirm-CompatibleHardwareEncoder) {
            "AMD" {
                if ($Vidtest -contains "codec_name=mov_text") {
                    & $Encoder -i $Video -hide_banner -loglevel 8 -map 0:v -map 0:a -map 0:s? -c:v hevc_amf -rc constqp -qp 27 -b:v 0k -c:a copy -c:s srt "$Output"
                }
                else {
                    & $Encoder -i $Video -hide_banner -loglevel 8 -map 0:v -map 0:a -map 0:s? -c:v hevc_amf -rc constqp -qp 27 -b:v 0k -c:a copy -c:s copy "$Output"
                }
            }
            "CPU" {
                if ($Vidtest -contains "codec_name=mov_text") {                            
                    & $Encoder -i $Video -hide_banner -loglevel 8 -map 0:v -map 0:a -map 0:s? -c:v libx265 -rc constqp -qp 27 -b:v 0k -c:a copy -c:s srt "$Output"
                }
                else {
                    & $Encoder -i $Video -hide_banner -loglevel 8 -map 0:v -map 0:a -map 0:s? -c:v libx265 -rc constqp -crf 27 -b:v 0k -c:a copy -c:s copy "$Output"                         
                }
            }
            "NVIDIA" {
                if ($Vidtest -contains "codec_name=mov_text") {
                    & $Encoder -hwaccel cuvid -i $Video -hide_banner -loglevel 8 -map 0:v -map 0:a -map 0:s? -c:v hevc_nvenc -rc constqp -qp 27 -b:v 0k -c:a copy -c:s srt "$Output"
                }
                else {
                    & $Encoder -hwaccel cuvid -i $Video -hide_banner -loglevel 8 -map 0:v -map 0:a -map 0:s? -c:v hevc_nvenc -rc constqp -qp 27 -b:v 0k -c:a copy -c:s copy "$Output"
                }
            }

        }
   
        #Region PostConversion Checks

        #Verifies a file was created -if it isnt then something went wrong with the conversion
        switch (Test-Path $Output ) {
            "$True" {
                                    
                #Gets converted Video Sizes for Comparison
                $CSize = [math]::Round(( Get-Item $Output ).Length / 1MB, 2 )

                Show-Time
                Write-Host "$Vid Processed Size is $CSize MBs. Let's Find Out Which File To Remove."
                    
                #Removes output video file if it was converted incorrectly, adds to the exclusion list   
                If ( $CSize -lt 10 ) {
                    Remove-item $Output
                    Write-host "Something Went Wrong. Converted File Too Small. Removing The Traitor From Your Computer and placed on exclusion list." -ForegroundColor Red
                    Write-output "Small Video Output | $Video" | Out-File -encoding utf8 -FilePath $ErrorList -Append
                    Write-Output "$Video | $Vid" | Out-File -encoding utf8 -FilePath $Xclude -Append                    
                    Continue 
                }
                 
                #Removes Original file if it is bigger than the converted file
                If ( $OSize -gt $CSize ) {
                    Remove-Item $Video
                    #Checks that the Original file was deleted, if not it tried to remove again
                    if (Test-Path $Video) {
                        Start-Sleep -Seconds 15
                        Write-host "Waiting 15 Seconds."
                        Remove-Item $Video
                    }   
                    #If the Original File was removed , it renames the temp file
                    If (!( Test-Path $Video )) {
                        Write-Host "Original File Removed. Keeping The Converted File." -ForegroundColor Green
                        Rename-Item $Output -NewName $Final
                        Write-Output "$Video | $Vid" | Out-File -encoding utf8 -FilePath $Xclude -Append
                        Continue 
                    }
                    Else {
                        Write-Host "Couldnt Remove Old $Vid File." -ForegroundColor Red
                        Write-output "Couldnt Remove Video Possibly In Use | $Video" | Out-File -encoding utf8 -FilePath $ErrorList -Append
                        Add-Content $Rename "$Output" -Encoding "utf8"
                    }
                    Continue 
                }
    
                #Removes Converted File if it is bigger than the original file
                If ( $OSize -lt $CSize ) {
                    Remove-Item $Output
                    if (Test-Path $Output) {
                        Start-Sleep -Seconds 15
                        Write-host "Waiting 15 Seconds."
                        Remove-Item $Output
                    }    
                    Write-Host "Converted File Removed. Keeping The Original File." -ForegroundColor Yellow
                    Write-Output "$Video | $Vid" | Out-File -encoding utf8 -FilePath $Xclude -Append
                    Continue 
                }  
    
                #Removes Original file if the converted and original files are the same size, then tries again if it cant remove it
                If ( $OSize -eq $CSize ) {
                    Remove-Item $Video
                    if (Test-Path $Video) {
                        Start-Sleep -Seconds 15
                        Write-host "Waiting 15 Seconds."
                        Remove-Item $Video
                        Rename-Item $Output -NewName $Final
                    }  
                    Write-Host "Same Size. Removing Original."
                    Write-output "$Vid | $Final" | Out-File -encoding utf8 -FilePath $Xclude -Append
                    Continue 

                }
            }
            "$False" {
                #If a video file was not produced it will be added to exclusion list
                Show-Time
                Write-Host "Conversion Failed. Adding $Vid To The Error and Exclusion List." -ForegroundColor Red 
                Write-output "Conversion Failed | $Video" | Out-File -encoding utf8 -FilePath $ErrorList -Append
                Write-Output "$Video | $Vid" | Out-File -encoding utf8 -FilePath $Xclude -Append
            }
        }
  
        #Endregion PostConversion Checks
    }
}
#EndRegion VideoBatch
#EndRegion Script

#Region RenameFile
#Renames Files that were not able to be renamed 
$RFileList = Get-Content -Path $Rename
if ($RFileList.Length -gt 2) { 
    $Title = "Rename"
    $Message = "Would you like to rename the files that were unable to be renamed?"
    $Options = "&Yes", "&No"

    $DefaultChoice = 0
    $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

    switch ($Result) {
        "0"	{
            #Gets files from the $Rename file and tries to rename them while removing themm from the CSV
            $RVideos = Get-ChildItem $Directory -Recurse  | Where-Object { $_ -in $RFileList -and $_.extension -in ".mkv" } | ForEach-Object { $_.FullName } | Sort-Object
            $Count = $RVideos.count
            Show-Time "---Starting--Renaming--Process---"
            Write-Host "$Count Videos to be processed."

            #Renaming Processing
            Foreach ($RVideo in $RVideos) {
                $RVid = (Get-Item "$RVideo").fullname -Replace '_MERGED', ''
                If ( Test-Path $RVideo ) {
                    If ( Test-Path $RVid ) {
                        Remove-item $RVid
                    }
                    Write-Host "Processing $RVid"                
                    Get-Item $RVideo | Rename-Item -NewName $RVid 
                    if (Test-Path $RVid) {
                        $Rename | Where-Object { $_.event -ne $RVideo } | Export-Csv -encoding utf8 -Path $Rename -Delimiter "|"
                        Write-host "Renamed $RVid"
                    }
                }
                else {
                    $Rename | Where-Object { $_.event -ne $RVideo } | Export-Csv -encoding utf8 -Path $Rename -Delimiter "|"
                    Write-Host "Could Not Find $RVideo, Removed from Rename list."
                }
            }
        }
        "1"	{ Continue }
    }
}
#EndRegion RenameFile

#Region END
Write-Host "All Videos In $Directory Have Been Converted. Logs, Exclusions, And Error Lists Can Be Found In $Resources" -ForegroundColor Black -BackgroundColor White
Stop-Transcript
Read-Host -Prompt "Current source code can be found at https://raw.githubusercontent.com/dmankl/HomeCode/master/HEVC_Conversion.ps1"
#EndRegion END

#Region FUTURE
<#
Look to add to script
Quality Varitation as a factor of removing one or the other
If a HEVC is already converted, remove the smaller .. better quality one
Add a Saving space counter/record

Considerations
Make a folder and add files into it instead of removing, then add a function to remove unwanted files by questioning
Add a function to convert to HEVC even if file is bigger than 264 version

Future Additions
Add GUI
Add test to see if Hardware/Software is possible
Add test to see if 264 files are in the exclusion list
Change defaults to json
Add AMD commands 
#>
#EndRegion FUTURE

#EndRegion Whole