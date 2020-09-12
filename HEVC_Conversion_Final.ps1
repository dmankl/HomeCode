<#  Batch Convert to HEVC with FFMPEG using Nvidia graphics card or using your cpu
    This Script uses FFMPEG, If you do not have it then it will download it and put it in the right location
    The defaults For the conversion process are good but if you want better quality lower the number on line# 111 or 114
    If your video card is not capable of decoding HEVC video files will appear in the error log saying "Small Converted Video For" and the video path\name and adds it to the exclusion list to prevent multiple attempts.
    This script will make an Exclusion List, Log File, And an Error Log in a folder name "_Conversion" this helps speed up the processes if you need to stop the script and pick back up where you left off.
    Enjoy. -Dmankl
#>
#Set Dependancies and Verify Working Files and Directories are there
$Directory = Read-Host -Prompt 'Input Location'
$Encoder = "C:\ffmpeg\bin\ffmpeg.exe"
If (!( Test-Path -Path $Encoder )) {
    if (!(Test-Path "C:\Temp")) {
        New-Item -Path "C:\" -Name "Temp" -ItemType "Directory"
    }
    if (!(Test-Path "C:\ffmpeg")) {
        New-Item -Path "C:\" -Name "ffmpeg" -ItemType "Directory"
    }
    $Url = "https://ffmpeg.zeranoe.com/builds/win64/static/ffmpeg-20200831-4a11a6f-win64-static.zip"
    $Output = "C:\Temp\ffmpeg.zip"
    Invoke-WebRequest -Uri $Url -OutFile $Output
    Expand-Archive -LiteralPath $Output -DestinationPath "C:\Temp"
    Copy-Item "C:\Temp\ffmpeg*\*" -Destination "C:\ffmpeg" -Recurse
}
$Probe = 'C:\ffmpeg\bin\ffprobe.exe'
$Resources = "$Directory\_Conversion"
If (!( Test-Path -Path $Resources )) { New-Item -Path $Directory -Name "_Conversion" -ItemType "Directory" }   
$Xclude = "$Resources\Exclude.txt"
If (!( Test-Path -Path $Xclude )) { New-Item -Path $Resources -Name "Exclude.txt" -ItemType "File" }
$Log = "$Resources\ConversionLog.txt"
If (!( Test-Path -Path $Log )) { New-Item -Path $Resources -Name "ConversionLog.txt" -ItemType "File" }
$ErrorList = "$Resources\ErrorList.txt"
If (!(Test-Path -Path $ErrorList)) { New-Item -Path $Resources -Name "ErrorList.txt" -ItemType "File" }
$Rename = "$Resources\Rename.txt"
If (!( Test-Path -Path $Rename )) { New-Item -Path $Resources -Name "Rename.txt" -ItemType "File" }
$FileList = Get-Content -Path "$Xclude"

#Type of Transcode
$Title = "Transcode Type"
$Message = "Please choose how you want to transcode your videos"
$Options = "&Hardware Transcode", "&Software Transcode"

$DefaultChoice = 0
$Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

switch ($Result) {
    "0"	{ $Transcode = "Hardware" }
    "1"	{ $Transcode = "Software" }
}

#Transcript And Log Functions
$version = $PSVersionTable.PSVersion.toString()
If ($version -gt 5.9) { Start-Transcript -Path "$Log" -Append -UseMinimalHeader } 
Else { Start-Transcript -Path "$Log" -Append }
Function Write-Log($string) {
    $dateTimeNow = Get-Date -Format "MM.dd.yyyy - HH:mm:ss"
    $outStr = "" + $dateTimeNow + " " + $string 
    Write-Output $outStr 
}

#Gets The Videos To Convert
$Videos = Get-ChildItem $Directory -Recurse -Exclude "*_MERGED*" | Where-Object { $_ -notin $FileList -and $_.extension -in ".mp4", ".mkv", ".avi", ".m4v", ".wmv" } | ForEach-Object { $_.FullName } | Sort-Object
$Count = $Videos.count
Write-Log "---Starting--Conversion--Process---"
Write-Host "$Count Videos to be processed."
            
#Video Batch
Foreach ($Video in $Videos) {
    $Path = Split-Path $Video
    $Vid = (Get-Item "$Video").Basename
    $Output = $Path + "\" + $Vid + '_MERGED' + '.mkv'
    $Final = $Path + "\" + $Vid + '.mkv'

    #Check If A Conversion Was Interrupted
    If ( Test-Path $Output ) {
        If ( Test-Path $Final ) {
            Remove-item $Output
            Write-Log
            Write-host "Previous $Vid Conversion failed, Removing The Traitor From Your Computer." -ForegroundColor Yellow 
            Add-Content $ErrorList "Cleaned Up Previous $Vid File." 
        }
        Else { Rename-Item $Output -NewName $Final }
                
        #Execution And Verification
        Write-host "Please wait, this may take a while."
        $Videos = Get-ChildItem $Directory -Recurse -Exclude "*_MERGED*" | Where-Object { $_ -notin $FileList -and $_.extension -in ".mp4", ".mkv", ".avi", ".m4v", ".wmv" } | ForEach-Object { $_.FullName } | Sort-Object
        $Count = $Videos.count
        Write-Log "---Starting--Conversion--Process---"
        Write-Host "$Count Videos to be processed."
        #Video Batch
        Foreach ( $Video in $Videos ) {
            $Path = Split-Path $Video
            $Vid = ( Get-Item "$Video" ).Basename
            $Output = $Path + "\" + $Vid + '_MERGED' + '.mkv'
            $Final = $Path + "\" + $Vid + '.mkv'
            #Check If A Conversion Process Was Interrupted
            If ( Test-Path $Output ) {
                If ( Test-Path $Final ) {
                    Remove-item $Output
                    Write-Log
                    Write-host "Previous $Vid Conversion failed, Removing The Traitor From Your Computer." -ForegroundColor Yellow 
                    Add-Content $ErrorList "Cleaned Up Previous $Vid File." 
                }
                Else { Rename-Item $Output -NewName $Final }
            }  
            #Execution And Verification
            Write-Log
            Write-Host "Processing $Vid Please Wait."
            $Vidtest = & $Probe -v error -show_format -show_streams $Video 
            if ($Vidtest -contains "codec_name=H264") {
                If ( $Transcode -eq "Hardware" ) {
                    & $Encoder -hwaccel auto -i $Video -hide_banner -loglevel error -map 0:v -map 0:a -map 0:s? -c:v hevc_nvenc -rc constqp -qp 27 -b:v 0k -c:a copy -c:s copy "$Output" 
                }
                If ( $Transcode -eq "Software" ) {
                    & $Encoder -i $Video -hide_banner -loglevel error -map 0:v -map 0:a -map 0:s? -c:v libx265 -rc constqp -crf 27 -b:v 0k -c:a copy -c:s copy "$Output" 
                }
                #Video Sizes for Comparison
                $OSize = [math]::Round(( Get-Item $Video | Measure-Object Length -Sum ).Sum / 1MB, 2 )
                $CSize = [math]::Round(( Get-Item $Output | Measure-Object Length -Sum ).Sum / 1MB, 2 )
                #Verify conversion         
                If ( Test-Path $Output ) {        
                    Write-Log
                    Write-Host "$Vid Processed Size is $CSize MBs, Let's Find Out Which File To Remove." 
                        
                    #Removes small files    
                    If ( $CSize -lt 10 ) {
                        Remove-item $Output
                        Write-host "Something Went Wrong, Converted File Too Small. Removing The Traitor From Your Computer." -ForegroundColor Red
                        Add-Content $ErrorList "Small Converted Video For $Vid, Placed on Exclude List."
                        Add-Content $Xclude "$Video"
                        Continue 
                    }
                    #Compare and remove smaller file
                    If ( $OSize -gt $CSize ) {
                        Remove-Item $Video
                        If (!( Test-Path $Video )) {
                            Write-Host "Original File Removed, Keeping The Converted File." -ForegroundColor Green
                            Rename-Item $Output -NewName $Final
                            If (!( Test-Path $Final )) {
                                Add-Content $ErrorList "Couldnt Rename Converted $Vid. It can be renamed at the end of the script."
                                Add-Content $Rename "$Output"
                            }
                            If ( Test-Path $Output ) {
                                Add-Content $ErrorList "Couldnt Rename Converted $Vid. It can be renamed at the end of the script."
                                Add-Content $Rename "$Output"
                            }
                            Add-Content $Xclude "$Final" 
                            Continue 
                        }
                        Else {
                            Write-Host "Couldnt Remove Old $Vid File." -ForegroundColor Red
                            Add-Content $ErrorList "Removal Failure For $Video File, Video May Be In Use." 
                        }
                        Continue 
                    }
    
                    If ( $OSize -lt $CSize ) {
                        Remove-Item $Output
                        Write-Host "Converted File Removed, Keeping The Original File." -ForegroundColor Yellow
                        Add-Content $Xclude "$Video"
                        Continue 
                    }  
    
                    If ( $OSize -eq $CSize ) {
                        Remove-Item $Output
                        Write-Host "Same Size, Removing Converted."
                        Add-Content $Xclude "$Video"
                        Continue 
                    }
                }
                Else {
                    Write-Log
                    Write-Host "Conversion Failed, Adding $Vid To The Error List." -ForegroundColor Red 
                    Add-Content $ErrorList "Conversion Failed For $Video" 
                }
            }
            
            else {
                Write-Host "$Vid is already converted." -ForegroundColor Cyan
                Add-Content $Xclude "$Video"
            } 
        }  
    }
}   
#Rename Files 
$RFileList = Get-Content -Path $Rename
if (!($null -eq $RFileList)) {      
    $RVideos = Get-ChildItem $Directory -Recurse  | Where-Object { $_ -in $RFileList -and $_.extension -in ".mkv" } | ForEach-Object { $_.FullName } | Sort-Object
    $Count = $RVideos.count
    Write-Log "---Starting--Renaming--Process---"
    Write-Host "$Count Videos to be processed."
        
    Foreach ($RVideo in $RVideos) {
        $RVid = (Get-Item "$RVideo").fullname -Replace '_MERGED', ''
        Write-Host "Processing $RVid"                
        if (Test-Path $RVid) { Remove-Item $RVid }
        Get-Item $RVideo | Rename-Item -NewName { $_.Name -Replace '_MERGED', '' } 
    }
    Remove-Item $Rename  
}
Write-Log
Write-Host "All Videos In $Directory Have Been Converted. Logs, Exclusions, And Error Lists Can Be Found In $Resources" -ForegroundColor Black -BackgroundColor White
Stop-Transcript
Read-Host -Prompt "Press Enter To Exit Script"
