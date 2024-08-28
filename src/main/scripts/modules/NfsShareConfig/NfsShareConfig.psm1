# ********************************************************************
# Ericsson Radio Systems AB                                     MODULE
# ********************************************************************
#
#
# (c) Ericsson Radio Systems AB 2015 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Radio Systems AB, Sweden. The programs may be used
# and/or copied only with the written permission from Ericsson Radio
# Systems AB or in accordance with the terms and conditions stipulated
# in the agreement/contract under which the program(s) have been
# supplied.
#
# ********************************************************************
# Name    : NfsShareConfig.psm1
# Date    : 16/10/2023
# Purpose : Install NFS feature and configure NetAnServer Instrumentation
#           Folder NFS share for ENIQ coordinator blade
#
#
# Usage   : Install-NFS $installParams{}
#
#

Import-Module Logger
Import-Module NetAnServerUtility

$logger = Get-Logger($LoggerNames.Install)

### Function: Install-NFS ###
#
#    Configure NFS share on NetAnServer Instrumentation Folder for ENIQ coordinator blade
#
# Arguments:
#       $installParams @{eniqBlade}
# Return Values:
#       [boolean]
# Throws:
#       None
#
Function Install-NFS() {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$installParams
    )
    $loc = Get-Location
    $powershellVar = "powershell "
    $startTimeforDatacollector = (get-date).AddMinutes(10).ToString("HH:mm")
    $startTimeforParser = (get-date).AddMinutes(20).ToString("HH:mm")
    $startTimeforUserAudit = (get-date).AddMinutes(15).ToString("HH:mm")
    $startTimeforCustomFolderCreation = (get-date).AddMinutes(10).ToString("HH:mm")
    $sharedFolderName = "DDC"
    $nfsServiceName = "NfsService"
    $dataCollectorTaskName = "NetAn_Data_Collector_Start_Up"
    $dataCollectorOnReboot = "NetAn_Data_Collector_On_Reboot"
    $parserTaskName = "NetAn_Parser_Start_Up"
    $dataCollectorDailyStartUp = "NetAn_Data_Collector_Daily_Start_Up"
    $parserSchedule = "NetAn_Parser_Daily_Schedule"
    $userAuditTask = "NetAn_User_Audit_Start_Up"
    $parserNextDaySchedule = "NetAn_Parser_Next_Day_Schedule"
    $dataCollectorFile = $powershellVar + $installParams.dataCollectorScriptPath
    $parserFile = $powershellVar + $installParams.parserScriptPath
    $userAuditFile = $powershellVar + $installParams.userAuditScriptPath

	
    if ((Test-Path $installParams.nfsShareLogDir) -eq 0) {
        try {
            $logger.logInfo("Creating nfs share log directory $($installParams.nfsShareLogDir) ", $false)
             New-Item -ItemType directory $installParams.nfsShareLogDir -ErrorAction stop | Out-Null
            $logger.logInfo("NFS share log directory $($installParams.nfsShareLogDir) created successfully ", $false)
        } catch {
            $errorMessage = $_.Exception.Message
            $logger.logError($MyInvocation," Creating nfs share log directory $($installParams.nfsShareLogDir) failed:  $errorMessage ", $True)
            return $False
        }
         
    }

    $status = Test-ServiceExists $nfsServiceName

    if(!$status) {

        $ScriptBlockNfsService = {
            Import-Module ServerManager
            Import-Module NFS
            Add-WindowsFeature FS-NFS-Service -ErrorAction Stop -WarningAction silentlyContinue
            
        }

        try {
            $logger.logInfo("Installing NFS service", $True)
            Invoke-Command -ScriptBlock $ScriptBlockNfsService -ErrorAction Stop  | Out-Null
            $logger.logInfo("NFS service installed", $True)
        }catch {
            $errorMessage = $_.Exception.Message
            $logger.logError($MyInvocation," NFS service installation failed :  $errorMessage ", $True)
            return $False
        }
    }

    $output = Invoke-Command -ScriptBlock {Get-NfsShare}
    $listOfSharedDir = $($output.name)

    if ($listOfSharedDir -contains $sharedFolderName ) {

        $logger.logInfo("NetAnServer Instrumentation Directory is already NFS share Configured ", $True)

    } else {

        $ScriptBlockNfsShare = {
            New-NfsShare –Name $sharedFolderName –Path $installParams.nfsShareLogDir
			if([System.Environment]::GetEnvironmentVariable("LSTCPIPVER", [System.EnvironmentVariableTarget]::User) -eq "6"){
				$logger.logInfo("ENIQ IPv6 Configuration found.", $True)
				Add-NfsPermissionTask
			}
			else {
			$logger.logInfo("ENIQ IPv4 Configuration found.", $True)
            Grant-NfsSharePermission -Name $sharedFolderName -ClientName $installParams.eniqCoordinator -ClientType "host" -Permission "readonly"
			}
        }
        try {
            $logger.logInfo("Attempting to configure NFS share  ", $True)
            Invoke-Command -ScriptBlock $ScriptBlockNfsShare -ErrorAction Stop | Out-Null
            $logger.logInfo("NetAnServer Instrumentation directory NFS share Configuration successfully done", $True)

        } catch {
            $errorMessage = $_.Exception.Message
            $logger.logError($MyInvocation," Error in NFS Share Configuration :  $errorMessage ", $True)
            return $False
        }
        finally {
            Set-Location $loc
        }
        
    }

    ### Check if Task in Task scheduler already exists  ###
    $isTaskExist = Check-TasksInTaskScheduler

    if (!$isTaskExist) {
        $statusUpdate = Add-TasksInTaskScheduler $installParams
        if ($statusUpdate) {
            $logger.logInfo("Task configuration in task sheduler successfully completed",$False)

        } else {
            $logger.logError($MyInvocation, "Task configuration in Task scheduler failed", $True)
            return $False
        }
    }
    else {
        $logger.logInfo("Task $dataCollectorTaskName is already configured in task sheduler",$True)
    }
    return $True


}

Function AllMachinePermission() {
	
	$time_Stamp=Get-Date -format "dd/MM/yyyy HH:mm:ss"
    $timeStampDefault=Get-Date -Format yyyyMMdd
     
     $first= Test-Path C:\Ericsson\NetAnServer\Logs\Nfs_DDCPermission.log -PathType Leaf
	  
       if(!$first)
	 {
      try
      {
	    New-Item -ItemType File -Path C:\Ericsson\NetAnServer\Logs -Name Nfs_DDCPermission.log 
		$script:log="C:\Ericsson\NetAnServer\Logs\Nfs_DDCPermission.log"
       }
       catch
       {
        $script:log="Error occured while creating the log file"
        EXIT(1)
       }
	  }
     else
     {
		$script:log="C:\Ericsson\NetAnServer\Logs\Nfs_DDCPermission.log"
     } 
	 
$currentTime = Get-Date     
$startTime1 = (Get-Date -Hour 23 -Minute 44).TimeOfDay     
$startTime2 = (Get-Date -Hour 0 -Minute 14).TimeOfDay     
$currentTime = $currentTime.TimeOfDay     


if ($currentTime -ge $startTime1 -or $currentTime -lt $startTime2){
	"------------------------------------------------" >> $script:log
	 "DDC Permissoin Folder Change Started "+$time_Stamp >> $script:log
"-----------------------------------------------" >> $script:log
	Grant-NfsSharePermission -Name DDC -ClientName "All Machines" -ClientType "builtin" -Permission "readonly"
	"DDC folder Permission updated to All Machine read-only"  >> $script:log
}
else {
"------------------------------------------------" >> $script:log
	 "DDC Permissoin Folder Change Started "+$time_Stamp >> $script:log
"-----------------------------------------------" >> $script:log
	Grant-NfsSharePermission -Name DDC -ClientName "All Machines" -ClientType "builtin" -Permission "no-access"
	"DDC folder Permission updated to All Machine no-access"  >> $script:log
}
}

### Function: Check-TasksInTaskScheduler ###
#
#    Check the information of tasks in task scheduler. If they are already
#    exist,return $True
#
# Arguments:
#       None
# Return Values:
#       [boolean]
# Throws:
#       None
#

Function Check-TasksInTaskScheduler() {

    try {
        $schedule = new-object -com("Schedule.Service")
        $schedule.connect()
        $tasks = $schedule.getfolder("\").gettasks(0)
        foreach ($t in $tasks){
            $taskName=$t.Name
            if($taskName -eq $dataCollectorTaskName ){
             return $true
            }
        }
     } catch {
       $errorMessage = $_.Exception.Message
       $logger.logError($MyInvocation," Check Tasks in task scheduler Failed :  $errorMessage ", $True)
       return $False
     }
}


### Function: Add-TasksInTaskScheduler ###
#
#   Add Task in task scheduler for data collector
#
#
# Arguments:
#       $installParams @{eniqBlade}
# Return Values:
#       [boolean]
# Throws:
#       None
#---------------------------------------------------------------------

Function Add-TasksInTaskScheduler() {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$installParams
    )

    
    $scriptBlockCmd = {

        schtasks /create /ru system /sc once /tn $dataCollectorTaskName /tr $dataCollectorFile  /st $startTimeforDatacollector /rl highest | Out-null
        schtasks /create /ru system /sc onstart /tn $dataCollectorOnReboot /tr $dataCollectorFile /rl highest | Out-null
        schtasks /create /ru system /sc minute /mo 15 /tn $parserTaskName /tr $parserFile /st $startTimeforParser /rl highest | Out-null
        schtasks /create /ru system /sc daily /tn $parserSchedule /tr $parserFile /st 23:56 /rl highest | Out-null
        schtasks /create /ru system /sc daily /tn $dataCollectorDailyStartUp /tr $dataCollectorFile /st 00:01 /rl highest | Out-null
        schtasks /create /ru system /sc minute /mo 15 /tn $userAuditTask /tr $userAuditFile /st $startTimeforUserAudit /rl highest | Out-null
        schtasks /create /ru system /sc daily /tn $parserNextDaySchedule /tr $parserFile /st 00:02 /rl highest | Out-null
     }

    try {

        Invoke-Command -ScriptBlock $scriptBlockCmd -errorAction stop

        $logger.logInfo("Task $dataCollectorTaskName added in task scheduler successfully done", $false)
        $logger.logInfo("Task $parserTaskName added in task scheduler successfully done", $false)
        $logger.logInfo("Task added in task scheduler successfully done", $true)
        return $true

    } catch {
        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation," Error Adding Task in task scheduler :  $errorMessage ", $True)
        return $False
    }
}

Function Add-NfsPermissionTask() {
	$taskName = "NetAn_NfsPermission"
	$Netdrive = (Get-ChildItem Env:SystemDrive).value
	$nfsfilepath = "\Ericsson\NetAnServer\Modules\NfsShareConfig\NfsShareConfig.psm1"
	$powershellVar = "powershell "
	$ModulePath = $Netdrive + $nfsfilepath
	
   try {
        # Check if the task already exists
        $isTaskExist = Get-ScheduledTask | Where-Object { $_.TaskName -eq $taskName }

        if (-not $isTaskExist) {
        $action = New-ScheduledTaskAction -Execute $powershellVar -Argument "Import-Module $ModulePath; AllMachinePermission"

		$trigger1 = New-ScheduledTaskTrigger -Daily -At 11:45PM
		$trigger2 = New-ScheduledTaskTrigger -Daily -At 12:15AM

		$taskParams = @{ 
		Action = $action 
		Trigger = @($trigger1, $trigger2) 
		TaskName = 'NetAn_NfsPermission'
        User = 'NT AUTHORITY\SYSTEM'
		RunLevel = "Highest"
		Description = 'Setting NFS share permission for DDC'} 

		Register-ScheduledTask @taskParams
        } else {
            $logger.logInfo("Task $taskName is already configured in the task scheduler", $True)
        }
        # Task creation was successful
        return $True
    } catch {
        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Error creating the task: $errorMessage", $True)
        return $False
    }
}

Export-ModuleMember -Function "Install-NFS","Add-TasksInTaskScheduler","AllMachinePermission","Add-NfsPermissionTask"