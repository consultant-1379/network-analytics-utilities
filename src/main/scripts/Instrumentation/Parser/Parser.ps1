# ********************************************************************
# Ericsson Radio Systems AB                                     SCRIPT
# ********************************************************************
#
#
# (c) Ericsson Inc. 2020 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Inc. The programs may be used and/or copied only with
# the written permission from Ericsson Inc. or in accordance with the
# terms and conditions stipulated in the agreement/contract under
# which the program(s) have been supplied.
#
# ********************************************************************
# Name    : Parser.ps1
# Date    : 24/08/2020
# Purpose : parser for NetAnServer application logs

#



Import-Module Logger


$drive = (Get-ChildItem Env:SystemDrive).value
$restoreResourcesPath = "C:\Ericsson\NetAnServer\RestoreDataResources\"
[xml]$xmlObj = Get-Content "$($restoreResourcesPath)\version\supported_NetAnPlatform_versions.xml"
$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")

foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'y') {
            $version = $platformVersionString.'version'
        }
}

$outputLogDir = $drive + "\Ericsson\Instrumentation\DDC\ApplicationLogs"
$outputSystemLogDir = $drive + "\Ericsson\Instrumentation\DDC\SystemLogs"
$sourceLogDir = $drive + "\Ericsson\NetAnServer\NodeManager\$($version)\nm\logs"
$sourceSystemLogDir = $drive + "\PerfLogs\NetAnSystemLogs"
$parseLogDir = $drive + "\Ericsson\Instrumentation\ParserLogs"
$userAuditDir = $drive + "\Ericsson\Instrumentation\UserAudit"
$serverName = $env:COMPUTERNAME + "NetanServer"
#$serverIp = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
$serverIp = '0.0.0.0'
$hostFileData = "$($serverIp)`t$($serverName)"
$hostFile = "hostname.tsv"
$hostFilePath = $outputSystemLogDir + "\" + $hostFile
$timeStamp = $(get-date -Format 'yyyyMMdd')
$backupAndRestore = $drive+"\Ericsson\NetAnServer\Logs\Backup_restore\"+$timeStamp+"_Backup_restore.log"
$outputBackupAndRestore = $outputLogDir+"\"+"Backup_restore"+$timeStamp+".txt"
$logger = Get-Logger("parser")
$logger.timestamp = $(get-date -Format 'yyyyMMdd')

Function Main() {

    $dirStatus = CheckLogDirs
    $parserStatus = StartParser
    Get-hardwareDetails
	Get-driveInfo
    $copyStatus = Copy-LogFile
    Remove-FiveDaysOldFiles
    Windows-ToUnixFileConversion

    If ( Test-Path $backupAndRestore ) {
        Get-Content $backupAndRestore | Set-Content $outputBackupAndRestore
    }


    if(!$dirStatus ) {
        $logger.logInfo("NetAnServer web player logs directory creation failed.", $False)
        Exit
    }

    if($parserStatus ) {

        $logger.logInfo("NetAnServer web player logs are parsed successfully.", $False)
    }
    else {
        $logger.logInfo("NetAnServer web player logs parsing failed.", $False)
    }

    if($copyStatus ) {
        $logger.logInfo("NetAnServer system logs copy to output directory $($outputSystemLogDir)  successfully.", $False)
    }
    else {
        $logger.logInfo("NetAnServer system logs copy to output directory $($outputSystemLogDir) failed.", $False)
    }

}


### Function:  CheckLogDirs ###
#
#    Checks log directory and creates if non-existent
#
# Arguments:
#       None
# Return Values:
#       [boolean]
# Throws:
#       None
#
Function CheckLogDirs() {


    try {

        if(!(Test-Path $parseLogDir)) {
            New-Item -ItemType directory -Path $parseLogDir -ErrorAction stop | Out-Null
        }

        $logger.setLogDirectory($parseLogDir)
        $logger.setLogName('Parser_log.log')


        if(!(Test-Path $outputLogDir)) {

            New-Item -ItemType directory -Path $outputLogDir -ErrorAction stop | Out-Null
            $logger.logInfo("NetAnServer web player output log directory for DDC $($outputLogDir) created.", $False)
        }


        if(!(Test-Path $outputSystemLogDir)) {

            New-Item -ItemType directory -Path $outputSystemLogDir -ErrorAction stop | Out-Null
            $logger.logInfo("NetAnServer system output log directory for DDC $($outputSystemLogDir) created.", $False)
            $hostFileData | out-file $hostFilePath -encoding ASCII
            $logger.logInfo("Hostname file for DDC $($hostFilePath) created.", $False)
        }

        if(!(Test-Path $sourceSystemLogDir)) {
            $logger.logError($MyInvocation,"NetAnServer system log directory $($sourceSystemLogDir) missing. Exiting", $False)
            return $false
        }

        if(!(Test-Path $sourceLogDir)) {
            $logger.logError($MyInvocation,"NetAnServer web player log directory $($sourceLogDir) missing. Exiting", $False)
            return $false
        }

        return $true

    } catch {
        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, " $($errorMessage) ", $true)
        return $false
    }
}

### Function:  StartParser ###
#
#    Parse NetAnServer Application logs and available for DDC
#
# Arguments:
#       None
# Return Values:
#       [boolean]
# Throws:
#       None
#

Function StartParser() {


    $timeStampInLogs = $(get-date -Format 'yyyy-MM-dd')

    # NetAnServer application logs columns
    $auditLogColumns = "Level","HostName","TimeStamp","UTC TimeStamp","SessionId","IPAddress","UserName","Operation","AnalysisId","Argument","Status","InstanceId","ServiceId"
    $userSessionStatisticsLogColumns = "Level","HostName","TimeStamp","UTC TimeStamp","SessionId","IPAddress","UserName","BrowserType","Cookies","LoggedInDuration","MaxOpenFileCount","OpenFileCount","InstanceId","ServiceId"
    $timingLogColumns = "Level","HostName","TimeStamp","UTC TimeStamp","EndTime","Duration","SessionId","IPAddress","UserName","Operation","AnalysisId","Argument","Status","InstanceId","ServiceId"
    $openFilesStatisticsLogColumns = "Level","HostName","TimeStamp","UTC TimeStamp","SessionId","FilePath","ModifiedOn","FileId","ElapsedTime","InactivityTime","InstanceId","ServiceId"
    $documentCacheStatisticsLogColumns = "Level","HostName","TimeStamp","UTC TimeStamp","Path","ModifiedOn","ReferenceCount","InstanceId","ServiceId"
    $memoryStatisticsLogColumns = "Level","HostName","TimeStamp","UTC TimeStamp","SessionId","UserName","AnalysisId","TableId","AnalysisPath","Title","Type","Value","InstanceId","ServiceId"


    # NetAnServer application logs file path
    $auditFilePath = $sourceLogDir + '\AuditLog*.txt'
    $timingLogPath = $sourceLogDir + '\TimingLog*.txt'
    $userSessionStatisticsLogPath = $sourceLogDir + '\UserSessionStatisticsLog*.txt'
    $openFilesStatisticsLogPath = $sourceLogDir + '\OpenFilesStatisticsLog*.txt'
    $documentCacheStatisticsLogPath = $sourceLogDir + '\DocumentCacheStatisticsLog*.txt'
    $memoryStatisticsLogPath = $sourceLogDir + '\MemoryStatisticsLog*.txt'
    $userAuditFile = $userAuditDir + "\*"

    # NetAnServer application logs file path after parsing
    $outputAuditLog = $outputLogDir + '\AuditLog' + $timeStamp +'.txt'
    $outputTimingLog = $outputLogDir + '\TimingLog' + $timeStamp + '.txt'
    $outputUserSessionStatisticsLog = $outputLogDir + '\UserSessionStatisticsLog' + $timeStamp +'.txt'
    $outputOpenFilesStatisticsLog = $outputLogDir + '\OpenFilesStatisticsLog' + $timeStamp +'.txt'
    $outputDocumentCacheStatisticsLog = $outputLogDir + '\DocumentCacheStatisticsLog' + $timeStamp +'.txt'
    $outputMemoryStatisticsLog = $outputLogDir + '\MemoryStatisticsLog' + $timeStamp +'.txt'
    $tempFile = $outputLogDir+ "\tmp.txt"
	$logger.logInfo("Parsing started.", $False)
	$errFlag = 0
    try {
        if (Test-Path ($auditFilePath)) {
			Get-Content $auditFilePath -Exclude "AuditLog.init.txt" | Select-String -pattern $timeStampInLogs, "Level", "String" | Sort-Object -Unique -Descending | Set-Content $outputAuditLog
			(Import-Csv $outputAuditLog -Header $auditLogColumns -Delimiter ';') | Foreach-Object { "{0}`t{1}`t{2}`t{3}`t{4}`t{5}" -f $_."UTC TimeStamp",$_.UserName,$_.Operation,$_.Argument,$_.Status,$_.ServiceId} | Out-File $outputAuditLog
			(New-Item $tempFile -type file -force )
			(Get-Content $outputAuditLog | Select-Object -First 2 | Set-Content $tempFile)
			(Get-Content $tempFile | Sort-Object -Descending| Set-Content $tempFile)
			(Get-Content $outputAuditLog | Select-Object -Skip 2 | Add-Content $tempFile)
			(Get-Content $tempFile | Set-Content $outputAuditLog)
		}
	}
	catch {
		$errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Could not parse audit logs. `n $errorMessage", $False)
        $errFlag = $errFlag + 1
    }
	try {
        if (Test-Path ($timingLogPath)) {
			Get-Content $timingLogPath -Exclude "TimingLog.init.txt"| Select-String -pattern $timeStampInLogs, "Level", "String" | Sort-Object -Unique -Descending | Set-Content $outputTimingLog
			(Import-Csv $outputTimingLog -Header $timingLogColumns -Delimiter ';') | Foreach-Object { "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}" -f $_."UTC TimeStamp",$_.UserName,$_.Operation,$_.Duration,$_.Argument,$_.Status,$_.ServiceId} | Out-File $outputTimingLog
			(New-Item $tempFile -type file -force )
			(Get-Content $outputTimingLog | Select-Object -First 2 | Set-Content $tempFile)
			(Get-Content $tempFile | Sort-Object -Descending| Set-Content $tempFile)
			(Get-Content $outputTimingLog | Select-Object -Skip 2 | Add-Content $tempFile)
			(Get-Content $tempFile | Set-Content $outputTimingLog)
        }
	}
	catch {
		$errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Could not parse timing logs. `n $errorMessage", $False)
        $errFlag = $errFlag + 1
    }
	try {
        if (Test-Path ($userSessionStatisticsLogPath)) {
			Get-Content $userSessionStatisticsLogPath -Exclude "UserSessionStatisticsLog.init.txt"| Select-String -pattern $timeStampInLogs, "Level", "String" |  Sort-Object -Unique -Descending | Set-Content $outputUserSessionStatisticsLog
			(Import-Csv $outputUserSessionStatisticsLog -Header $userSessionStatisticsLogColumns -Delimiter ';') | Foreach-Object { "{0}`t{1}`t{2}`t{3}`t{4}" -f $_."UTC TimeStamp",$_.UserName,$_.OpenFileCount,$_.LoggedInDuration,$_.ServiceId} | Out-File $outputUserSessionStatisticsLog
			(New-Item $tempFile -type file -force )
			(Get-Content $outputUserSessionStatisticsLog | Select-Object -First 2 | Set-Content $tempFile)
			(Get-Content $tempFile | Sort-Object -Descending| Set-Content $tempFile)
			(Get-Content $outputUserSessionStatisticsLog | Select-Object -Skip 2 | Add-Content $tempFile)
			(Get-Content $tempFile | Set-Content $outputUserSessionStatisticsLog)
		}
	}
	catch {
		$errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Could not parse user session statistic logs. `n $errorMessage", $False)
        $errFlag = $errFlag + 1
    }
	try {
        if (Test-Path ($openFilesStatisticsLogPath)) {
			Get-Content $openFilesStatisticsLogPath -Exclude "OpenFilesStatisticsLog.init.txt"| Select-String -pattern $timeStampInLogs, "Level", "String" |  Sort-Object -Unique -Descending | Set-Content $outputOpenFilesStatisticsLog
			(Import-Csv $outputOpenFilesStatisticsLog -Header $openFilesStatisticsLogColumns -Delimiter ';') | Foreach-Object { "{0}`t{1}`t{2}" -f $_."UTC TimeStamp",$_.FilePath,$_.ServiceId} | Out-File $outputOpenFilesStatisticsLog
			(New-Item $tempFile -type file -force )
			(Get-Content $outputOpenFilesStatisticsLog | Select-Object -First 2 | Set-Content $tempFile)
			(Get-Content $tempFile | Sort-Object -Descending| Set-Content $tempFile)
			(Get-Content $outputOpenFilesStatisticsLog | Select-Object -Skip 2 | Add-Content $tempFile)
			(Get-Content $tempFile | Set-Content $outputOpenFilesStatisticsLog)
		}
	}
	catch {
		$errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Could not parse open file statistic logs. `n $errorMessage", $False)
        $errFlag = $errFlag + 1
    }
	try {
        if (Test-Path ($documentCacheStatisticsLogPath)) {
			Get-Content $documentCacheStatisticsLogPath -Exclude "DocumentCacheStatisticsLog.init.txt" | Select-String -pattern $timeStampInLogs, "Level", "String" |  Sort-Object -Unique -Descending | Set-Content $outputDocumentCacheStatisticsLog
			(Import-Csv $outputDocumentCacheStatisticsLog -Header $documentCacheStatisticsLogColumns -Delimiter ';') | Foreach-Object { "{0}`t{1}`t{2}`t{3}" -f $_."UTC TimeStamp",$_.Path,$_.ReferenceCount,$_.ServiceId} | Out-File $outputDocumentCacheStatisticsLog
			(New-Item $tempFile -type file -force )
			(Get-Content $outputDocumentCacheStatisticsLog | Select-Object -First 2 | Set-Content $tempFile)
			(Get-Content $tempFile | Sort-Object -Descending| Set-Content $tempFile)
			(Get-Content $outputDocumentCacheStatisticsLog | Select-Object -Skip 2 | Add-Content $tempFile)
			(Get-Content $tempFile | Set-Content $outputDocumentCacheStatisticsLog)
        }
	}
	catch {
		$errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Could not parse document cache statistic logs. `n $errorMessage", $False)
        $errFlag = $errFlag + 1
    }
	try {
        if (Test-Path ($memoryStatisticsLogPath)) {
			Get-Content $memoryStatisticsLogPath -Exclude "MemoryStatisticsLog.init.txt"| Select-String -pattern $timeStampInLogs, "Level", "String" |  Sort-Object -Unique -Descending | Set-Content $outputMemoryStatisticsLog
			(Import-Csv $outputMemoryStatisticsLog -Header $memoryStatisticsLogColumns -Delimiter ';') | Foreach-Object { "{0}`t{1}`t{2}`t{3}`t{4}`t{5}" -f $_."UTC TimeStamp",$_.AnalysisPath,$_.Title,$_.Type,$_.Value,$_.ServiceId} | Out-File $outputMemoryStatisticsLog
			(New-Item $tempFile -type file -force )
			(Get-Content $outputMemoryStatisticsLog | Select-Object -First 2 | Set-Content $tempFile)
			(Get-Content $tempFile | Sort-Object -Descending| Set-Content $tempFile)
			(Get-Content $outputMemoryStatisticsLog | Select-Object -Skip 2 | Add-Content $tempFile)
			(Get-Content $tempFile | Set-Content $outputMemoryStatisticsLog)
		}
	}
	catch {
		$errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Could not parse memory statistic logs. `n $errorMessage", $False)
        $errFlag = $errFlag + 1
    }
	try {
        if (Test-Path ($userAuditFile)) {
			Copy-Item -Path $userAuditFile -Destination $outputLogDir -Force
		}
	}
	catch {
		$errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Could not copy user audit logs. `n $errorMessage", $False)
        $errFlag = $errFlag + 1
    }
	
	if ($errFlag -ne 7) {
		return $True 
	} else {
		return $false
	}
}
### Function:  Copy-LogFile ###
#
#    Copy NetAnServer system logs from "C:\PerfLogs\NetAnSystemLogs" to
#    C:\Ericsson\Instrumentation\DDC\SystemLogs for DDC collection
#
# Arguments:
#       None
# Return Values:
#       [boolean]
# Throws:
#       None

Function Copy-LogFile() {

     $sourcepath = $sourceSystemLogDir + "\*"

     if (Test-Path ($sourceSystemLogDir)) {

        try {

            Copy-Item -Path $sourcepath -Destination $outputSystemLogDir -Force
            $logger.logInfo("NetAnServer system log files  moved to  $($outputSystemLogDir) done" , $false)

            return $True

        } catch {
            $errorMessage = $_.Exception.Message
            $logger.logError($MyInvocation, "Copy from $($sourcepath) to $($outputSystemLogDir) failed. `n $errorMessage", $False)
            return $false
        }

    } else {
        $logger.logError($MyInvocation, "Logfile $($sourceSystemLogDir))  does not exist " , $false)
        return $False
    }
}


### Function:  Get-hardwareDetails ###
#
#  		Get and store hardware details "C:\PerfLogs\NetAnSystemLogs\Hardware_Details_<timestamp>.tsv file
#
# Arguments:
#       None
# Return Values:
#       [boolean]
# Throws:
#       None

Function Get-hardwareDetails(){

$date = Get-Date -DisplayHint Date
$SystemLogDir = $drive + "\PerfLogs\NetAnSystemLogs"
$path_log = $SystemLogDir+"\Hardware_Details_" + $date.ToString('yyyyMMdd')+".tsv"
If (Test-Path $SystemLogDir+"\Hardware_Details_*.tsv")
{
  Remove-Item $SystemLogDir+"\Hardware_Details_*.tsv"
}
systeminfo /fo csv > C:\Hardware_Details.csv 2> $null
Import-Csv C:\Hardware_Details.csv |  ForEach-Object {
        $systemtype = $_."System Type"
        $bios = $_."BIOS Version"
		$ram = $_."Total Physical Memory"
		$os = $_."OS Name"
		$os_version= $_."OS Version"
		$boottime = $_."System Boot Time"

    }
	del C:\Hardware_Details.csv


$proc = Get-CimInstance CIM_Processor | measure
$proccount = $proc.Count
$type = Get-CimInstance CIM_Processor | select Name
$cputype = $type[0].Name
$speed = Get-CimInstance CIM_Processor | select MaxClockSpeed
$clockspeed = $speed[0].MaxClockSpeed
$cores = Get-CimInstance -ClassName 'Win32_Processor' | Measure-Object -Property 'NumberOfCores' -Sum | select Sum
$numcores = $cores.Sum
$disk_sum= Get-WmiObject Win32_LogicalDisk | Measure-Object -Property 'Size' -Sum | Select Sum
$disk_total = [math]::Round($disk_sum.Sum/1GB,2)
$process = @()
$obj = New-Object -TypeName PSObject
	$obj | Add-Member -MemberType NoteProperty -Name "Server Type" -Value $systemtype
	$obj | Add-Member -MemberType NoteProperty -Name BIOS -Value $bios
	$obj | Add-Member -MemberType NoteProperty -Name "OS Name" -Value $os
	$obj | Add-Member -MemberType NoteProperty -Name "OS Version" -Value $os_version
	$obj | Add-Member -MemberType NoteProperty -Name "System Boot Time" -Value $boottime
	$obj | Add-Member -MemberType NoteProperty -Name "Physical Memory" -value $ram
	$obj | Add-Member -MemberType NoteProperty -Name "Total Disk(GB)" -Value $disk_total
	$obj | Add-Member -MemberType NoteProperty -Name "Processors" -Value $proccount
	$obj | Add-Member -MemberType NoteProperty -Name "CPU Type" -Value $cputype
	$obj | Add-Member -MemberType NoteProperty -Name "CPU Clock Speed(MHz)" -Value $clockspeed
	$obj | Add-Member -MemberType NoteProperty -Name "Total Cores" -Value $numcores
	$process += $obj
	$process | select "Server Type",BIOS,"OS Name","OS Version","System Boot Time", "Physical Memory", "Total Disk(GB)",Processors, "CPU Type", "CPU Clock Speed(MHz)", "Total Cores" | export-csv -delimiter "`t" -path $path_log -force -notypeinformation
}


### Function:  Get-driveInfo ###
#
#  		Get and store capacity and free space of logical drives in "C:\PerfLogs\NetAnSystemLogs\Drive_Info_<timestamp>.tsv file
#
# Arguments:
#       None
# Return Values:
#       [boolean]
# Throws:
#       None

Function Get-driveInfo(){
	$date = Get-Date -DisplayHint Date
	$curr_date = $date.ToString('yyyy-MM-dd-HH:mm:ss')
	$SystemLogDir = $drive + "\PerfLogs\NetAnSystemLogs"
	$path_log = $SystemLogDir+"\Drive_Info_" + $date.ToString('yyyyMMdd')+".tsv"
	If (Test-Path $SystemLogDir+"\Drive_Info_*.tsv"){
		Remove-Item $SystemLogDir+"\Drive_Info_*.tsv"
	}
	$info = @()
	Get-WmiObject -Class Win32_logicaldisk -Filter "DriveType = '3'" | foreach {
	$free_space = [math]::round($_.FreeSpace / 1GB,2)
	$capacity = [math]::round($_.Size / 1GB,2)
	$name = $_.DeviceID
	$obj = New-Object -TypeName PSObject
	$obj | Add-Member -MemberType NoteProperty -Name DateTime -Value $curr_date
	$obj | Add-Member -MemberType NoteProperty -Name Name -Value $name
	$obj | Add-Member -MemberType NoteProperty -Name Capacity -Value $capacity
	$obj | Add-Member -MemberType NoteProperty -Name FreeSpace -value $free_space
	$info += $obj
	}
	$info | select DateTime,Name, Capacity, FreeSpace | export-csv -delimiter "`t" -path $path_log -force -notypeinformation
}

### Function:  Remove-FiveDaysOldFiles###
#
#    Deleting one day old files from
#    C:\Ericsson\Instrumentation\DDC
#
#
# Arguments:
#       None
# Return Values:
#       None
# Throws:
#       None

Function Remove-FiveDaysOldFiles() {

    <# $patternForSystemLog = "*" + $timeStamp + ".tsv"
    $patternForAppLog = "*" + $timeStamp + ".txt" #>

    $scriptBlockRemoveCmd = {

            #Get-ChildItem -Path  $outputSystemLogDir -exclude $patternForSystemLog,$hostFile | Remove-Item -Recurse
			Get-ChildItem $outputSystemLogDir -Recurse -File | Where CreationTime -eq (Get-Date).AddDays(-5)  | Remove-Item -Force
           # Get-ChildItem -Path  $outputLogDir -exclude $patternForAppLog | Remove-Item -Recurse
			Get-ChildItem $outputLogDir -Recurse -File | Where CreationTime -eq (Get-Date).AddDays(-5)  | Remove-Item -Force
           # Get-ChildItem -Path  $userAuditDir -exclude $patternForAppLog | Remove-Item -Recurse
			Get-ChildItem $userAuditDir -Recurse -File | Where CreationTime -eq (Get-Date).AddDays(-5)  | Remove-Item -Force
    }

    try {

        $logger.logInfo("Deleting five days old files", $False)
        Invoke-Command -ScriptBlock $scriptBlockRemoveCmd -errorAction stop

    } catch {

        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Could not delete files. `n $errorMessage", $False)
    }

}

### Function:  Windows-ToUnixFileConversion###
#
#    Files generated in windows convert to unix support
#
# Arguments:
#       None
# Return Values:
#       None
# Throws:
#       None

Function Windows-ToUnixFileConversion() {

    $sytemFiles = $outputSystemLogDir + "\*.tsv"
    $applicationFiles = $outputLogDir + "\*.txt"

    $scriptBlockConversionCmd = {

      Get-ChildItem $sytemFiles | ForEach-Object {
      $contents = [IO.File]::ReadAllText($_) -replace "`r`n?", "`n"
      $utf8 = New-Object System.Text.UTF8Encoding $false
      [IO.File]::WriteAllText($_, $contents, $utf8)
      }
      Get-ChildItem $applicationFiles | ForEach-Object {
      $contents = [IO.File]::ReadAllText($_) -replace "`r`n?", "`n"
      $utf8 = New-Object System.Text.UTF8Encoding $false
      [IO.File]::WriteAllText($_, $contents, $utf8)
      }
    }

    try {

        $logger.logInfo("Converting windows to unix file format support", $False)
        Invoke-Command -ScriptBlock $scriptBlockConversionCmd -errorAction stop

    } catch {

        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Failed to convert from windows to unix file format. `n $errorMessage", $False)
    }


}



Main
