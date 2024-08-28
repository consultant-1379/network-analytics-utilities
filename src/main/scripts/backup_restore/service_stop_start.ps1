# ********************************************************************
# Ericsson Radio Systems AB                                     Script
# ********************************************************************
#
#
# (c) Ericsson Radio Systems AB 2020 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Radio Systems AB, Sweden. The programs may be used 
# and/or copied only with the written permission from Ericsson Radio 
# Systems AB or in accordance with the terms and conditions stipulated 
# in the agreement/contract under which the program(s) have been 
# supplied.
#
# ********************************************************************
# Name    : service_stop_start.ps1
# Date    : 21/08/2020
# Purpose : Stop and Start below mentioned NetAnServer Services
#              1) PostgreSQL
#              2) NetAnServer server
#              3) NetAnServer Node Manager
# Usage   : service_stop_start.ps1 $requestType
# ********************************************************************




Param(
  [Parameter(Mandatory=$True)]
  [string]$requestType

)

Import-Module Logger
Import-Module NetAnServerUtility

$drive = (Get-ChildItem Env:SystemDrive).value
$restoreResourcesPath = "C:\Ericsson\NetAnServer\RestoreDataResources\"
[xml]$xmlObj= Get-Content -Path "$($restoreResourcesPath)\version\supported_NetAnPlatform_versions.xml"
$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")

foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'y') {
            $version = $platformVersionString.'version'
        }
}
$Version = $version.Replace(".","")

$global:logger = Get-Logger("Backup_restore")
$backupRestoreLocation = $drive + "\Ericsson\NetAnServer\Logs\Backup_restore"
New-Item $backupRestoreLocation -type Directory -ea SilentlyContinue | Out-Null
$logger.setLogDirectory($backupRestoreLocation)
$logger.timestamp = $(get-date -Format 'yyyyMMdd')

$postgres_service = "postgresql-x64-" +(((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).MajorVersion) | measure -Maximum).Maximum

$serviceList = @($postgres_service,"Tss" + $Version,"WpNmRemote" + $Version)

Function Main {

    $ScriptBlockStopService = {
        param($Version)
        #net stop WpNmRemote$Version
		StopService WpNmRemote$Version
		#write-host ("after wpnm")
       # net stop Tss$Version
		StopService Tss$Version
       # net stop $postgres_service
		StopService $postgres_service
    }

    $ScriptBlockStartService = {

        #net start $postgres_service
		StartService $postgres_service
        #net start Tss$Version
		StartService Tss$Version
        #net start WpNmRemote$Version
		StartService  WpNmRemote$Version
    }

    if ($requestType -eq "stop") {

            try {

                $logger.logInfo("Backup procedure started. ", $False)
                $logger.logInfo("NetAnServer Services stopping ", $False)
                #checkServiceStatus
                Invoke-Command -ScriptBlock $ScriptBlockStopService -ArgumentList $Version -ErrorAction Stop  | Out-Null
                $logger.logInfo("NetAnServer Services stopped successfully.", $False)
                $logger.logInfo("NetAnServer successfully prepared for Backup.", $False)

            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, " $($errorMessage) ", $False)
                Exit 1

            }
    }

    ElseIf ($requestType -eq "start") {

            try {

                $logger.logInfo("NetAnServer Services starting  ", $False)
                #checkServiceStatus
                Invoke-Command -ScriptBlock $ScriptBlockStartService -ArgumentList $Version -ErrorAction Stop  | Out-Null
                $logger.logInfo("NetAnServer Services started successfully. ", $False)
                $logger.logInfo("Backup procedure completed.", $False)

            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, " $($errorMessage) ", $false)
                Exit 1

            }

    }

    Else {

        $logger.logError($MyInvocation,"Entered wrong request type parameter.", $false)
        Exit 1
    }
}


Function checkServiceStatus {

    foreach ($service in $serviceList) {

        if ((Test-ServiceRunning $service)) {

          $logger.logInfo("$($service) is running .", $false)
        }
        else {

          $logger.logInfo("$($service) is stopped.", $false)
        }
    }
}



Function StopService($service) {
	stageEnter($MyInvocation.MyCommand)
	
	$serviceExists = Test-ServiceExists "$($service)"
    $logger.logInfo("Service $($service) found: $serviceExists", $True)
	
	if ($serviceExists) {
		Set-Service "$($service)" -StartupType Manual
        $isRunning = Test-ServiceRunning "$($service)"

        if (!$isRunning) {
            $logger.logInfo("Server is already stopped....", $True)
        } else {

            try {
                $logger.logInfo("Stopping service....", $True)
                Stop-Service -Name "$($service)" -ErrorAction stop -WarningAction SilentlyContinue
				while($isRunning){
				Start-Sleep -s 10
				$isRunning = Test-ServiceRunning "$($service)"
				}
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not stop service. `n $errorMessage", $True)
				stageExit($MyInvocation.MyCommand)
				Exit
            }
        }

    } else {
        $logger.logError($MyInvocation, "Service $($service) not found.
            Please check server install was executed correctly")
       stageExit($MyInvocation.MyCommand)
		Exit
    }
	
	stageExit($MyInvocation.MyCommand)
}



Function StartService($service) {
    stageEnter($MyInvocation.MyCommand)

    $logger.logInfo("Preparing to Start NetAn Server", $True)
    $serviceExists = Test-ServiceExists $($service)
    $logger.logInfo("Service $($installParams.serviceNetAnServer) found: $serviceExists", $True)
    if ($serviceExists) {
		
		Set-Service $($service) -StartupType Automatic
        $isRunning = Test-ServiceRunning $($service)

        if ($isRunning) {
            $logger.logInfo("NetAn Server is already running....", $True)
        } else {

            try {
                $logger.logInfo("Starting service....", $True)
                Start-Service -Name $($service) -ErrorAction stop -WarningAction SilentlyContinue
				while(!$isRunning){
				Start-Sleep -s 25
				$isRunning = Test-ServiceRunning $($service)
				$logger.logInfo("Service $($service) is Running: $isRunning", $True)

				}
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not start service. `n $errorMessage", $True)
            }
        }

       stageExit($MyInvocation.MyCommand)

    } else {
        $logger.logError($MyInvocation, "Service $($installParams.serviceNetAnServer) not found.
            Please check server install was executed correctly")
       stageExit($MyInvocation.MyCommand)
		Exit
    }
}
Function stageEnter([string]$myText) {
    $Script:stage=$Script:stage+1
    $logger.logInfo("------------------------------------------------------", $True)
    $logger.logInfo("|         Entering Stage $($Script:stage) - $myText", $True)
    $logger.logInfo("|", $True)
    $logger.logInfo("", $True)
	
}



Function stageExit([string]$myText) {
    $logger.logInfo("", $True)
    $logger.logInfo("|", $True)
    $logger.logInfo("|         Exiting Stage $($Script:stage) - $myText", $True)
    $logger.logInfo("------------------------------------------------------`n", $True)
write-host "final"

}
Main