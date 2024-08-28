# ********************************************************************
# Ericsson Radio Systems AB                                     SCRIPT
# ********************************************************************
#
#
# (c) Ericsson Inc. 2017 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Inc. The programs may be used and/or copied only with
# the written permission from Ericsson Inc. or in accordance with the
# terms and conditions stipulated in the agreement/contract under
# which the program(s) have been supplied.
#
# ********************************************************************
# Name    : CustomFolderTask.ps1
# Date    : 07/11/2017
# Revision: PA1
# Purpose : #  Creation of scheduled task for Custom Folder Creation script for Ericsson Network Analytics Server
#
# Usage   : CustomFolderTask.ps1
#
#

param(
    [switch] $DISABLE
)

$drive = (Get-ChildItem Env:SystemDrive).value
$powershellVar = "powershell "
$startTimeforCustomFolderCreation = (get-date).AddMinutes(10).ToString("HH:mm")
$customLibFolderCreation = "Custom_Library_Folder_Creation"
$customFolderDir = $drive + "\Ericsson\NetAnServer\Scripts\User_Maintenance\CustomFolderCreation\"
$customFolderCreationFile = $powershellVar + $customFolderDir + "CustomFolderCreation.ps1"
$minutes=10


### Function: Check-TasksInTaskScheduler ###
#
#    Check the task status in task scheduler. If it already exists,
#    return $True
#
# Arguments:
#       None
# Return Values:
#       [boolean]
# Throws:
#       None
#

Function Check-TaskInTaskScheduler() {

    try {
        $schedule = new-object -com("Schedule.Service")
        $schedule.connect()
        $tasks = $schedule.getfolder("\").gettasks(0)
        foreach ($task in $tasks) {
            $taskName=$task.Name
            If ($taskName -eq $customLibFolderCreation ) {
                return $true
            }
        }
    } catch {
        $errorMessage = $_.Exception.Message
        customWrite-host(" Check Tasks in task scheduler Failed :  $($errorMessage)")
        return $False
    }
}


### Function: Update-TasksInTaskScheduler ###
#
#   Add or delete task in task scheduler for custom folder creation
#
# Arguments:
#       [switch] $DISABLE
# Return Values:
#       [boolean]
# Throws:
#       None
#---------------------------------------------------------------------

Function Update-TaskInTaskScheduler() {
    param(
        [switch] $DISABLE
    )
    
    $scriptBlockCmd = {
        schtasks /create /ru system /sc minute /mo $minutes /tn $customLibFolderCreation /tr $customFolderCreationFile /st $startTimeforCustomFolderCreation /rl highest | Out-null
    }
    
    $scriptBlockCmdDelete = {
        schtasks /delete /tn $customLibFolderCreation /f | Out-null
    }

    try {
        If (-not $DISABLE) {
            Invoke-Command -ScriptBlock $scriptBlockCmd -errorAction stop
            return $true
        } Else {
            Invoke-Command -ScriptBlock $scriptBlockCmdDelete -errorAction stop
            return $true
        }

    } catch {
        $errorMessage = $_.Exception.Message
        customWrite-host(" Error updating task in task scheduler :  $($errorMessage)")
        return $False
    }
}

Function customWrite-host($text) {
    Write-Host $text -ForegroundColor White
}


### CustomFolderTask ###
#
#    Create or delete custom folder creation task in task scheduler
#
# Arguments:
#       [switch] $DISABLE
# Return Values:
#       None
# Throws:
#       None
#

$isTaskExist = Check-TaskInTaskScheduler

If (!$isTaskExist) {
    If (-not $DISABLE) {
        $statusUpdate = Update-TaskInTaskScheduler
        If ($statusUpdate) {
            customWrite-host(" Custom folder task created in task scheduler")
        } Else {
            customWrite-host(" Task configuration in Task scheduler failed")
        }
    } Else {
        customWrite-host(" Custom folder task doesn't exist in task scheduler")
    }
} Else {
    If ($DISABLE) {
        $statusUpdate = Update-TaskInTaskScheduler -DISABLE
        If ($statusUpdate) {
            customWrite-host(" Custom folder task removed in task scheduler")
        } Else {
            customWrite-host(" Task configuration in Task scheduler failed")
        }
    } Else {
        customWrite-host(" Custom folder task is already configured in task scheduler")
    }
}