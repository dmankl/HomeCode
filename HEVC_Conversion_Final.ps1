#Batch Convert to HEVC using ffmpeg
#This Script uses En$Encoder, If you do not have it you can download it here: https://ffmpeg.zeranoe.com/builds/
#Extract it to a location and update the $Encoder Variable to match the location
#The defaults For the conversion process are good but if you want better quality lower the number on line# 
#If your video card is not capable of decoding HEVC video files will appear in the error log saying "Small Converted Video For" and the video path\name
#This script will make an Exclusion List, Log File, And an Error Log in a folder name "_Conversion" this helps speed up the processes if you need to
#stop the script and pick back up where you left off.
#Enjoy. -Dmankl

    #Set Dependancies and Verify Working Files and Directories are there
    $Directory = Read-Host -Prompt 'Input Location'
    $Encoder = 'C:\ffmpeg\bin\ffmpeg.exe'
        IF(!(Test-Path -Path $Encoder)){ Write-Host "Encoder Not Found, Please Make Sure To Update Location In Script For Your Location" -ForegroundColor Black -BackgroundColor White
            Read-Host -Prompt "Press Enter To Exit Script"
            Break }
    $Resources = "$Directory\_Conversion"
        If(!(Test-Path -Path $Resources)) { New-Item -Path $Directory -Name "_Conversion" -ItemType "Directory"}   
    $Xclude = "$Resources\Exclude.txt"
        If(!(Test-Path -Path $Xclude)) { New-Item -Path $Resources -Name "Exclude.txt" -ItemType "File"}
    $Log = "$Resources\ConversionLog.txt"
        If(!(Test-Path -Path $Log)) { New-Item -Path $Resources -Name "ConversionLog.txt" -ItemType "File"}
    $ErrorList = "$Resources\ErrorList.txt"
        If(!(Test-Path -Path $ErrorList)) { New-Item -Path $Resources -Name "ErrorList.txt" -ItemType "File"}
    $FileList = Get-Content -Path "$Xclude" | Sort-Object

#Transcript And Log Functions
    $PSVersion = $PSVersionTable.PSVersion.toString()
    If ($PSVersion -lt 5.2) {Start-Transcript -Path "$Log" -Append}
    If ($PSVersion -gt 6) {Start-Transcript -Path "$Log" -Append -UseMinimalHeader} 
    Function Write-Log($string) {
    $dateTimeNow = Get-Date -Format "MM.dd.yyyy - HH:mm:ss"
    $outStr = "" + $dateTimeNow +" "+$string 
    Write-Output $outStr }

#Gets The Videos To Convert
    $Videos = Get-ChildItem $Directory -Recurse -Exclude "*_MERGED*" | Where-Object { $_ -notin $FileList -and $_.extension -in ".mp4",".mkv",".avi",".m4v",".wmvstop" } | ForEach-Object { $_.FullName } | Sort-Object
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
        If ((Get-Item $Video | Measure-Object Length -Sum).Sum /1MB -lt 10) {
            Write-Log
            Write-host "Original File Too Small, Skipping file and Adding it to the Exclusion List."
            Add-Content $Xclude "$Video"
            Continue }     

        If (Test-Path $Output) {
            Remove-item $Output
            Write-Log
            Write-host "Previous $Vid Was Interrupted, Removing The Traitor From Your Computer." -ForegroundColor Yellow 
            Add-Content $ErrorList "Cleaned Up Previous $Vid File." }
          
#Execution And Verification
    Write-Log
    Write-Host "Processing $Vid Please Wait."
    & $Encoder -hwaccel auto -i $Video -hide_banner -loglevel panic -c:v hevc_nvenc -c:a copy -x265-params crf=28 -c:s copy "$Output"
        
        If (Test-Path $Output) {        
            Write-Log
            Write-Host "$Vid Processed, Let's Find Out Which File To Remove."
        
        #Cleanup    
        If ((Get-Item $Output | Measure-Object Length -Sum).Sum /1MB -lt 10) {
            Remove-item $Output
            Write-Log
            Write-host "Something Went Wrong, Converted File Too Small. Removing The Traitor From Your Computer." -ForegroundColor Red
            Add-Content $ErrorList "Small Converted Video For $Vid, Placed on Exclude List."
            Add-Content $Xclude "$Video"
            Continue }

        If ((Get-Item $Video | Measure-Object Length -Sum).Sum -gt (Get-Item $Output | Measure-Object Length -Sum).Sum) {
            Remove-Item $Video
            If (!(Test-Path $Video)) {
                Write-Log
                Write-Host "Original File Removed, Keeping The Converted File." -ForegroundColor Green
                Rename-Item $Output -NewName $Final
                Add-Content $Xclude "$Final" 
                } Else {
                    Write-Host "Couldnt Remove Old $Vid File." -ForegroundColor Red
                    Add-Content $ErrorList "Removal Failure For $Video File, Video May Be In Use." }
                Continue }

        If ((Get-Item $Video | Measure-Object Length -Sum).Sum -lt (Get-Item $Output | Measure-Object Length -Sum).Sum) {
            Remove-Item $Output
            Write-Log
            Write-Host "Converted File Removed, Keeping The Original File."
            Add-Content $Xclude "$Video"
            Continue }  

        If ((Get-Item $Video | Measure-Object Length -Sum).Sum -eq (Get-Item $Output | Measure-Object Length -Sum).Sum) {
            Remove-Item $Output
            Write-Log
            Write-Host "Same Size, Removing Converted."
            Add-Content $Xclude "$Video"
            Continue }
                
        } Else {
            Write-Log
            Write-Host "Conversion Failed, Adding $Vid To The Error List." -ForegroundColor Red }
            Add-Content $ErrorList "Conversion Failed For $Video" }
Write-Log
Write-Host "All Videos In $Directory Have Been Converted. Logs, Exclusions, And Error Lists Can Be Found In $Resources"
Stop-Transcript
Read-Host -Prompt "Press Enter To Exit Script"