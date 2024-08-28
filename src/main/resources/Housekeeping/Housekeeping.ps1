# ********************************************************************
# Ericsson Radio Systems AB                                     SCRIPT
# ********************************************************************
#
#
# (c) Ericsson Inc. 2021 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Inc. The programs may be used and/or copied only with
# the written permission from Ericsson Inc. or in accordance with the
# terms and conditions stipulated in the agreement/contract under
# which the program(s) have been supplied.
#
# ********************************************************************
# Name    : Housekeeping.ps1
# Date    : 18/05/2021
# Purpose : #  Housekeeping automation script for Ericsson Network Analytics Server
#               1. Restart Spotfire Server service
#               2. Restart Node Manager service
#               3. Log restart process/errors to log file
#
# Usage   : Housekeeping
#
#

Import-Module Logger
Import-Module NetAnServerUtility -Force

$global:logger = Get-Logger("housekeeping")
$drive = (Get-ChildItem Env:SystemDrive).value

$installParams = @{}
$installParams.Add('installDir', $drive + "\Ericsson\NetAnServer")
$installParams.Add('logDir', $installParams.installDir + "\Logs\Housekeeping")
$installParams.Add('logName', 'housekeeping.log')
$installParams.Add('resourcesDir', $installParams.installDir + "\RestoreDataResources")
$installParams.Add('platformVersionDir', $installParams.resourcesDir + "\version")

$global:currentLogName = ""

# get platform current version num
[xml]$xmlObj = Get-Content "$($installParams.platformVersionDir)\supported_NetAnPlatform_versions.xml"
$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")

foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'y') {
            $serviceVersion = $platformVersionString.'service-version'
        }
}

$serviceList = @("Tss$($serviceVersion)", "WpNmRemote$($serviceVersion)")
$serviceNetAnServer = $serviceList[0]
$serviceNodeManager = $serviceList[1]

Function InitiateLogs() {
    $creationMessage = $null
    

    if ( -not (Test-FileExists($installParams.logDir))) {
        New-Item $installParams.logDir -ItemType directory | Out-Null
        $creationMessage = "Creating new log directory $($installParams.logDir)"
        
    }
    
    $logger.setLogDirectory($installParams.logDir)
    $logger.setLogName($installParams.logName)
    $logger.timestamp = get-date -Format 'yyyyMMdd_HHmmss'

    $global:currentLogName = "$($installParams.logDir)\$($logger.timestamp)_$($installParams.logName)"
    if($creationMessage) {
        $logger.logInfo($creationMessage + "`n", $true)
    }
        
    $logger.logInfo("Housekeeping log created $currentLogName`n", $True)
    $logger.logInfo("Restarting Services`n", $True)

}

Function RestartNetAnServer() {
    
    $serverStopped = Stop-SpotfireService($serviceNetAnServer)
    if (!$serverStopped) {
        HandleError
    }

    $serverStarted = Start-SpotfireService($serviceNetAnServer)
    if (!$serverStarted) {
        HandleError
    }
          
    try {
        $a= Invoke-WebRequest -Uri https://localhost
    }
    catch {
        $logger.logInfo("$($serviceNetAnServer) has started successfully`n", $True)
    }


} 

Function RestartNodeManager() {
     
    $serviceStopped = Stop-SpotfireService($serviceNodeManager)
    if (!$serviceStopped) {
        HandleError
    }

    $serviceStarted = Start-SpotfireService($serviceNodeManager)
    if (!$serviceStarted) {
        $serviceStarted = StopNodeManagerProcesses

        if (!$serviceStarted) { 
            HandleError
        }
    }
        
    $process=1
    while($process.Count -le 1){
        try{
            Start-Sleep -s 1
            $process =  Get-Process -ProcessName "Spotfire.Dxp.Worker.Host" -ea Stop
        }
        catch {        
            $process=$null
        }

        if ($process.Count -gt 1) {
            $logger.logInfo("$($serviceNodeManager) has started successfully`n", $True)
        }

    }    

}

Function StopNodeManagerProcesses() {
    
    $logger.logInfo("Stopping Node Manager processes", $True)
    foreach ($proc in (Get-Process | Where {$_.Path -Like "*C:\Ericsson\NetAnServer\NodeManager*"}).Id) {
        taskkill /F /PID $proc 2>&1 | Out-Null
    }

    $logger.logInfo("Retrying Node Manager start", $True)

    $noErrors = Start-SpotfireService($serviceNodeManager)

    return $noErrors
}

Function HandleError() {
    Invoke-Item $global:currentLogName
    Exit
}

Function Main() {

    InitiateLogs

    RestartNetAnServer
    RestartNodeManager

    foreach ($service in $serviceList)
    {
        if (Test-ServiceRunning "$service" -eq $True) {
	        $logger.logInfo("$service has been restarted successfully`n", $True)
        } else {
            $logger.logError($MyInvocation, "Failed to restart $service")
            HandleError
        }
        
     
    }

}

Main