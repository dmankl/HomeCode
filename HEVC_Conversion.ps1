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

Function Get-Folder($initialDirectory) {
    [void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowserDialog.RootFolder = 'MyComputer'
    $FolderBrowserDialog.ShowNewFolderButton = $false

    if ($initialDirectory) { 
        $FolderBrowserDialog.SelectedPath = $initialDirectory 
    }
    [void] $FolderBrowserDialog.ShowDialog()
    return $FolderBrowserDialog.SelectedPath
}
#Set Dependancies and Verify Working Files and Directories are there
Write-Host "HEVC Conversion by DMANKL." -ForegroundColor Green
Write-Host "Please enter the filepath where we will be working today." -ForegroundColor Black -BackgroundColor White
$Directory = Get-Folder
Write-Host "Verifying/Creating Supporting files."

#Resource Files
$FFMPEG = "C:\FFMPEG"
$Resources = "$FFMPEG\_Conversion"
If (!( Test-Path -Path $Resources )) { New-Item -Path $FFMPEG -Name "_Conversion" -ItemType "Directory" }   
$Log = "$Resources\ConversionLog.csv"
If (!( Test-Path -Path $Log )) { 
    $Logs = [pscustomobject]@{
        'Event' = ''
    }
    Export-Csv -InputObject $Logs -Path $Log -Delimiter "|" -NoTypeInformation
}
$Xclude = "$Resources\Exclude.Csv"
If (!( Test-Path -Path $Xclude )) { 
    $Xclusions = [pscustomobject]@{
        'Path' = ''
    }
    Export-Csv -InputObject $Xclusions -Path $Xclude -Delimiter "|" -NoTypeInformation
}
$Rename = "$Resources\Rename.txt"
If (!( Test-Path -Path $Rename )) { New-Item -Path $Resources -Name "Rename.txt" -ItemType "File" }
$ErrorList = "$Resources\ErrorList.csv"
if (!(Test-Path $ErrorList)) {
    $Errors = [pscustomobject]@{
        'Error' = ''
        'File'  = ''
    }
    Export-Csv -InputObject $Errors -Path $ErrorList -Delimiter "|" -NoTypeInformation
}
$Default = "$Resources\Defaults.csv"
If (!( Test-Path -Path $Log )) { 
    $Defaults = [pscustomobject]@{
        'Path' = ''
        'Function' = ''
        'Transcode' = ''
    }
    Export-Csv -InputObject $Defaults -Path $Default -Delimiter "|" -NoTypeInformation
}
$FileList = Import-Csv -Path "$Xclude" -Delimiter "|"

#FFMPEG Files
Write-Host "Checking For the necessary files"
$Encoder = "$FFMPEG\bin\ffmpeg.exe"
If (!( Test-Path -Path $Encoder )) {
    if (!(Test-Path "C:\Temp")) {
        New-Item -Path "C:\" -Name "Temp" -ItemType "Directory"
    }
    if (!(Test-Path "$FFMPEG\bin")) {
        New-Item -Path "$FFMPEG" -Name "bin" -ItemType "Directory"
    }
    $Url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-full.7z"
    $Output = "C:\Temp\ffmpeg.zip"
    Invoke-WebRequest -Uri $Url -OutFile $Output
    Expand-Archive -LiteralPath $Output -DestinationPath "C:\Temp"
    Copy-Item "C:\Temp\ffmpeg*\*" -Destination "$FFMPEG" -Recurse
    Remove-Item $Output
}
else {
    Write-Host "Found The files, Lets get started."
}
$Probe = 'C:\ffmpeg\bin\ffprobe.exe'

#Transcript And Log Functions
$version = $PSVersionTable.PSVersion.toString()
If ($version -gt 5.9) { Start-Transcript -Path "$Log" -Append -UseMinimalHeader } 
Else { Start-Transcript -Path "$Log" -Append }
Function Write-Log($string) {
    $dateTimeNow = Get-Date -Format "MM.dd.yyyy - HH:mm:ss"
    $outStr = "" + $dateTimeNow + " " + $string 
    Write-Output $outStr 
}

#Real start of the script
$Title = "Transcode/Other"
$Message = "Would you like to trancode videos, clean up previous transcode jobs, or setup exclusion file"
$Options = "&Transcode", "&Clean Up", "&Setup Exclusion File"

$DefaultChoice = 0
$Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

switch ($Result) {
    "0"	{
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

        #Gets The Videos To Convert
        Write-Host "Looking For Video Files. Please wait as this may take a while depending on the amount of files in the directories."
        $Videos = Get-ChildItem $Directory -Recurse -Exclude "*_MERGED*" | Where-Object { $FileList.path -notcontains $_.FullName -and $_.extension -in ".mp4", ".mkv", ".avi", ".m4v", ".wmv" } | ForEach-Object { $_.FullName } | Sort-Object 
        $Count = $Videos.count
        Write-Log "---Starting--Conversion--Process---"
        Write-Host "$Count Videos to be processed."
        For ($i = 0; $i -le ($Videos.count - 1); $i++) {
            Write-Progress -Activity 'Conversion status' -percentComplete ($i / $Videos.count * 100)
        }    

        #Video Batch
        Foreach ($Video in $Videos) {

            #Filename Stuff
            $Path = Split-Path $Video
            $Vid = (Get-Item "$Video").Basename
            $Output = $Path + "\" + $Vid + '_MERGED' + '.mkv'
            $Final = $Path + "\" + $Vid + '.mkv'

            #Check If A Conversion Was Interrupted
            If ( Test-Path $Output ) {
                If ( Test-Path $Final ) {
                    Remove-item $Output
                    Write-Log
                    Write-host "Previous $Vid Conversion failed. Removing The Traitor From Your Computer." -ForegroundColor Yellow 
                    Write-output "Previous File Removed | $Video" | Out-File -encoding utf8 -FilePath $ErrorList -Append
                }
                Else { Rename-Item $Output -NewName $Final }
            }           
            
            #Execution And Verification
            $Vidtest = & $Probe -v error -show_format -show_streams $Video 
           
            #Checks if video is already HEVC
            if ($Vidtest -contains "codec_name=hevc") {
                Write-Host "$Vid is already converted." -ForegroundColor Cyan
                Write-Output "$Video" | Out-File -encoding utf8 -FilePath $Xclude -Append

            } 
            else {    
                #Current File Size
                $OSize = [math]::Round(( Get-Item $Video ).Length / 1MB, 2 )        
                Write-Log
                Write-Host "Processing $Vid, It is currently $OSize MBs. Please Wait."
                
                #Conversion
                If ( $Transcode -eq "Hardware" ) {
                    if ($Vidtest -contains "codec_name=mov_text") {
                        & $Encoder $Decode -i $Video -hide_banner -loglevel error -map 0:v -map 0:a -map 0:s? -c:v hevc_nvenc -rc constqp -qp 27 -b:v 0k -c:a copy -c:s srt "$Output"
                    }
                    else {
                        & $Encoder $Decode -i $Video -hide_banner -loglevel error -map 0:v -map 0:a -map 0:s? -c:v hevc_nvenc -rc constqp -qp 27 -b:v 0k -c:a copy -c:s copy "$Output"
                    } 
                }
                If ( $Transcode -eq "Software" ) {
                    if ($Vidtest -contains "codec_name=mov_text") {
                        & $Encoder -i $Video -hide_banner -loglevel error -map 0:v -map 0:a -map 0:s? -c:v libx265 -rc constqp -crf 27 -b:v 0k -c:a copy -c:s srt "$Output" 
                    } 
                    else {
                        & $Encoder -i $Video -hide_banner -loglevel error -map 0:v -map 0:a -map 0:s? -c:v libx265 -rc constqp -crf 27 -b:v 0k -c:a copy -c:s copy "$Output" 
                    }
                }

                #Verify conversion         
                If ( Test-Path $Output ) {

                    #Gets Video Sizes for Comparison
                    $CSize = [math]::Round(( Get-Item $Output ).Length / 1MB, 2 )

                    Write-Log
                    Write-Host "$Vid Processed Size is $CSize MBs. Let's Find Out Which File To Remove."
                    
                    #Removes small files    
                    If ( $CSize -lt 10 ) {
                        Remove-item $Output
                        Write-host "Something Went Wrong. Converted File Too Small. Removing The Traitor From Your Computer and placed on exclusion list." -ForegroundColor Red
                        Write-output "Small Video Output | $Video" | Out-File -encoding utf8 -FilePath $ErrorList -Append
                        Write-Output "$Video" | Out-File -encoding utf8 -FilePath $Xclude -Append
                        Continue 
                    }
                    
                    #Compare and remove smaller file
                    If ( $OSize -gt $CSize ) {
                        Remove-Item $Video
                        if (Test-Path $Video) {
                            Start-Sleep -Seconds 15
                            Write-host "Waiting 15 Seconds."
                            Remove-Item $Video
                        }    
                        If (!( Test-Path $Video )) {

                            Write-Host "Original File Removed. Keeping The Converted File." -ForegroundColor Green
                            If ( Test-Path $Final ) { 
                                Rename-item $Final -NewName { $Final.FullName -Replace ".mkv", ".old" } 
                                Write-output "Possible Redundant Video | $Final" | Out-File -encoding utf8 -FilePath $ErrorList -Append
                                $PossDuplicates.Add("$Final")
                            }
                            Rename-Item $Output -NewName $Final
                            <#Possibly Redundant
                            If ( Test-Path $Output ) {
                                Add-Content $ErrorList "Couldnt Rename Converted $Vid. It can be renamed at the end of the script."
                                Add-Content $Rename "$Output"
                            } #>
                            Write-Output "$Final" | Out-File -encoding utf8 -FilePath $Xclude -Append
                            Continue 
                        }
                        Else {
                            Write-Host "Couldnt Remove Old $Vid File." -ForegroundColor Red
                            Write-output "Couldnt Remove Video Possibly In Use | $Video" | Out-File -encoding utf8 -FilePath $ErrorList -Append
                            Add-Content $Rename "$Output" -Encoding "utf8"
                        }
                        Continue 
                    }
    
                    If ( $OSize -lt $CSize ) {
                        Remove-Item $Output
                        if (Test-Path $Output) {
                            Start-Sleep -Seconds 15
                            Write-host "Waiting 15 Seconds."
                            Remove-Item $Output
                        }    
                        Write-Host "Converted File Removed. Keeping The Original File." -ForegroundColor Yellow
                        Write-Output "$Video" | Out-File -encoding utf8 -FilePath $Xclude -Append

                        Continue 
                    }  
    
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
                #If Conversion failed
                Else {
                    Write-Log
                    Write-Host "Conversion Failed. Adding $Vid To The Error and Exclusion List." -ForegroundColor Red 
                    Write-output "Conversion Failed | $Video" | Out-File -encoding utf8 -FilePath $ErrorList -Append
                    Write-Output "$Video" | Out-File -encoding utf8 -FilePath $Xclude -Append

                }
            }
        }  
  
        #Rename Files 
        $RFileList = Get-Content -Path $Rename
        if (!($null -eq $RFileList)) { 
            $Title = "Rename"
            $Message = "Would you like to rename the files that were unable to be renamed?"
            $Options = "&Yes", "&No"

            $DefaultChoice = 0
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0"	{
                    $RVideos = Get-ChildItem $Directory -Recurse  | Where-Object { $_ -in $RFileList -and $_.extension -in ".mkv" } | ForEach-Object { $_.FullName } | Sort-Object
                    $Count = $RVideos.count
                    Write-Log "---Starting--Renaming--Process---"
                    Write-Host "$Count Videos to be processed."
        
                    Foreach ($RVideo in $RVideos) {
                        $RVid = (Get-Item "$RVideo").fullname -Replace '_MERGED', ''
                        If ( Test-Path $RVideo ) {
                            If ( Test-Path $RVid ) {
                                Remove-item $RVid
                            }
                            Write-Host "Processing $RVid"                
                            Get-Item $RVideo | Rename-Item -NewName { $_.Name -Replace '_MERGED', '' } 
                            if (Test-Path $RVid) {
                                Get-Content $Rename -Replace "$RVideo" , "" | out-file -encoding utf8 $Rename
                                Write-host "Renamed $RVid"
                            }
                        }
                        else {
                            Write-Host "Could Not Find $RVideo"
                        }
                    }
                }
                "1"	{ Continue }
            }
        }
    }
    "1" {
        #Cleans Up Conversion Files
        Write-Host "Looking For Video Files. Please wait as this may take a while depending on the amount of files in the directories."
        $CVideos = Get-ChildItem $Directory -Recurse -Exclude "*_MERGED*" | Where-Object { $FileList.path -notcontains $_.FullName -and $_.extension -in ".mp4", ".mkv", ".avi", ".m4v", ".wmv" } | ForEach-Object { $_.FullName } | Sort-Object 
        $Count = $CVideos.count
        Start-Transcript
        foreach ($CVideo in $CVideos) {
            Write-Host "Found $CVideo"
            $CVid = (Get-Item "$CVideo").fullname -Replace '_MERGED', ''
            if (Test-Path $CVideo) {
                if (Test-Path $CVid) {
                    Write-Host "Found unconverted Video. Removing Converted video Just in case." -ForegroundColor Yellow
                    Remove-item $CVideo
                    If (Test-Path $CVideo) {
                        Write-Host "Could Not Remove $CVideo" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "Renaming $CVideo"
                    Rename-Item $CVideo -NewName $CVid
                    If (Test-Path $CVideo) {
                        Write-Host "Could Not Rename $CVideo"
                    }
                    else {
                        Write-Host "Renamed $CVideo Successfully." -ForegroundColor Green
                    }
                }
    
            }    
        }
    }
    "2" {
        #Creates/Adds Converted Videos to Exclusion List
        Write-Host "Looking For Video Files. Please wait as this may take a while depending on the amount of files in the directories."
        $Videos = Get-ChildItem $Directory -Recurse -Exclude "*_MERGED*" | Where-Object { $FileList.path -notcontains $_.FullName -and $_.extension -in ".mp4", ".mkv", ".avi", ".m4v", ".wmv" } | ForEach-Object { $_.FullName } | Sort-Object 
        Foreach ($Video in $Videos) {
            $Vidtest = & $Probe -v error -show_format -show_streams $Video
            $Vid = (Get-Item "$Video").Basename
            #  if ($Vidtest -contains "codec_name=hevc") {
            Write-Host "$Vid is already converted." -ForegroundColor Cyan
            Write-Output "$Video" | Out-File -encoding utf8 -FilePath $Xclude -Append

            #  }
        }
    }
}
#Ends Script and functions
Write-Host "All Videos In $Directory Have Been Converted. Logs, Exclusions, And Error Lists Can Be Found In $Resources" -ForegroundColor Black -BackgroundColor White
Stop-Transcript
Read-Host -Prompt "Press Enter To Exit Script"

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
Change to CSV files
#>
