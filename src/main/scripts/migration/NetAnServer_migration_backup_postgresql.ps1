# ********************************************************************
# Ericsson Radio Systems AB                                     MODULE
# ********************************************************************
#
#
# (c) Ericsson Radio Systems AB 2021 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Radio Systems AB, Sweden. The programs may be used
# and/or copied only with the written permission from Ericsson Radio
# Systems AB or in accordance with the terms and conditions stipulated
# in the agreement/contract under which the program(s) have been
# supplied.
#
# ********************************************************************
# Name    : NetanServer_migration_backup_postgresql.ps1
# Date    : 17/08/2021
# Purpose : Module used to backup NetAnServer data (postgresql database)
#

$backupParams = @{}

$restoreResourcesPath = "C:\Ericsson\NetAnServer\RestoreDataResources\"

# get platform version info
if(Test-Path "$($restoreResourcesPath)\version\supported_NetAnPlatform_versions.xml") {
	[xml]$xmlObj = Get-Content "$($restoreResourcesPath)\version\supported_NetAnPlatform_versions.xml"
	$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")
	
	foreach ($platformVersionString in $platformVersionDetails){
		if ($platformVersionString.'current' -eq 'y') {
			$version = $platformVersionString.'version'
			$serviceVersion = $platformVersionString.'service-version'
		}
	}
}
elseif(Test-Path "$($restoreResourcesPath)\version\version_strings.xml") {
	[xml]$xmlObj = Get-Content "$($restoreResourcesPath)\version\version_strings.xml"
	$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")
	
	foreach ($platformVersionString in $platformVersionDetails){
		if ($platformVersionString.'current' -eq 'y') {
			$version = $platformVersionString.'version'
			$serviceVersion = $platformVersionString.'service-version'
		}
	}
}
elseif(Test-Path "$($restoreResourcesPath)\version\version_string.txt") {
	$platformVersionDetails = Get-Content "$($restoreResourcesPath)\version\version_string.txt"
	$version = $platformVersionDetails
	$serviceVersion = $platformVersionDetails.Replace('.', '')
}
else {
	$logger.logInfo("Unable to determine Platform Version", $true)
	Exit
}

$Script:stage=1.0


$backupParams.Add('backupDir', "C:\Ericsson\Backup")
$backupParams.Add('netanserv_home', "C:\Ericsson\NetAnServer")
$backupParams.Add('tempDir', "C:\Ericsson\tmp")
$backupParams.Add('backupDirRepdb', "$($backupParams.backupDir)\postgresql_backup\")
$backupParams.Add('backupDirLibData', "$($backupParams.backupDir)\library_data_backup\")
$backupParams.Add('backupDirLibAnalysisData', $backupParams.backupDirLibData + "libraries\")
$backupParams.Add('setLogName', 'NetAnDB_Backup.log')
$backupParams.Add('logDir', $backupParams.netanserv_home + "\Logs")
$backupParams.Add('tomcatbin', "$($backupParams.netanserv_home)\Server\$($version)\tomcat\spotfire-bin\")
$backupParams.Add('tempConfigLogFile', $backupParams.logDir + "\command_output_temp.log")
$backupParams.Add('serviceNetAnServerOld', "Tss" + $serviceVersion)
$backupParams.Add('migrationScriptDirectory', $backupParams.tempDir + "\Scripts\migration\")

$password = Get-EnvVariable "NetAnVar"
$platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A',$password ).GetNetworkCredential().Password
$backupParams.Add('platformPassword', $platformPassword)

$modulesDir = "$($backupParams.tempDir)\Scripts\modules"
$originalEnvPath = $env:PSModulePath
$env:PSModulePath = $env:PSModulePath + ";"+$modulesDir
Import-Module Logger
if (Get-Module -Name NetAnServerUtility) { #there is an update in this module which is necessary for this script to work
	Remove-Module NetAnServerUtility
	Copy-Item -Path "$($backupParams.tempDir)\Scripts\modules\NetAnServerUtility\NetAnServerUtility.psm1" -Destination "$($backupParams.netanserv_home)\Modules\NetAnServerUtility\" -force | Out-Null
}
Import-Module NetAnServerUtility
Import-Module NetAnServerConfig
$loc = Get-location

#$global:logger = Get-Logger($LoggerNames.Install)
Logger = Get-Logger($LoggerNames.Install)
$initalinstall = "Backup"

Function InitiateLogs($message) {
    $creationMessage = $null

    If (-not (Test-FileExists($backupParams.logDir))) {
        New-Item $backupParams.logDir -ItemType directory | Out-Null
        $creationMessage = "Creating new log directory $($backupParams.logDir)"
    }

    $logger.setLogDirectory($backupParams.logDir)
    $logger.setLogName($backupParams.setLogName)

    $logger.logInfo("Starting the $message of Ericsson Network Analytics Server.", $True)

    If ($creationMessage) {
        $logger.logInfo($creationMessage, $true)
    }

    $logger.logInfo("$message log created $($backupParams.logDir)\$($logger.timestamp)_$($backupParams.setLogName)", $True)
    Set-Location $loc
}


Function stageEnter([string]$myText) {
    $Script:stage=$Script:stage+0.1
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
}

Function Get-AdminUserName() {
    param(
        [Parameter(Mandatory=$true)]
        [string] $password
        )
    $adminName=Get-Users -all | % { if($_.Group -eq "Administrator") {return $_} } |Select-Object -first 1
    return $adminName.USERNAME
}

#----------------------------------------------------------------------------------
#    Start the NetAnServer Server Service
#----------------------------------------------------------------------------------
Function StartNetAnServer() {
    stageEnter($MyInvocation.MyCommand)
    $service = $backupParams.serviceNetAnServerOld
    $logger.logInfo("Preparing to start NetAnServer Server", $True)
    $startSuccess = Start-SpotfireService($service)

    if ($startSuccess) {
		
		$logger.logInfo("This procedure can take up to 5 mins. Please wait...", $True)
        $timeout = new-timespan -Minutes 5
		$sw = [diagnostics.stopwatch]::StartNew()
		while ($sw.elapsed -lt $timeout){
			$serverState = Get-Service -Name $service
			if($serverState.status -ne "Running"){
				$logger.logError($MyInvocation,"$($service) failed to Start", $True)
				Exit
			}
			start-sleep -seconds 2
		}
            
        try {
            $a= Invoke-WebRequest -Uri https://localhost
        }
        catch {
            $logger.logInfo("$($service) has started successfully`n", $True)
			Set-Variable -Name "serchk" -value $($service) -scope global
        }
        stageExit($MyInvocation.MyCommand)

    } else {
        $logger.logError($MyInvocation, "Could not start service.", $True)
        Exit
    }
}
#----------------------------------------------------------------------------------
#    Stop the NetAnServer Server Service
#----------------------------------------------------------------------------------
Function StopNetAnServer($service) {
    stageEnter($MyInvocation.MyCommand)
	
    $stopSuccess = Stop-SpotfireService($service)

    if ($stopSuccess) { 
		$logger.logInfo("$($service) has stopped successfully`n", $True)	
        stageExit($MyInvocation.MyCommand)

    } else {
        $logger.logError($MyInvocation, "Could not stop $service service.", $True)
        MyExit($MyInvocation.MyCommand)
    }
}

Function BackupLibraryContents() {
    stageEnter($MyInvocation.MyCommand)
    $adminUser=Get-AdminUserName $backupParams.platformPassword
    $backupParams.Add('adminUser', $adminUser)
    $ErrorActionPreference = "Stop"
    try {

        $commandMap = [ordered]@{
            "export config" = "export-config -t $($backupParams.platformPassword) --force";
            "set config prop" = "set-config-prop --name=information-services.clear-data-source-passwords-on-export --value=False";
            "import config" = "import-config -t $($backupParams.platformPassword) -c `"Changing config to retain passwords on export.`"";
            "export users" = "export-users $($backupParams.backupDirLibData)users.txt -i true -t $($backupParams.platformPassword) --force";
            "export groups" = "export-groups $($backupParams.backupDirLibData)groups.txt -t $($backupParams.platformPassword) -m true -u true --force";
            "export library" = "export-library-content --file-path=$($backupParams.backupDirLibAnalysisData)library_content_all --item-type=all_items --library-path=/ --user=$($backupParams.adminUser) -t $($backupParams.platformPassword) --force";
            "export rules" = "export-rules -p $($backupParams.backupDirLibData)rules.json -t $($backupParams.platformPassword) --force"
        }

        If(!(test-path $backupParams.backupDirLibData))
            {
                New-Item -ItemType Directory -Force -Path $backupParams.backupDirLibData | Out-Null
            }

        If(!(test-path $backupParams.backupDirLibAnalysisData))
            {
                New-Item -ItemType Directory -Force -Path $backupParams.backupDirLibAnalysisData | Out-Null
            }

        foreach ($stage in $commandMap.GetEnumerator()) {
            if ($stage) {
                Start-Sleep 10
                $params = @{}
                $params.spotfirebin = $backupParams.tomcatbin   #Tomcat bin directory
                $logger.logInfo("Executing Stage $($stage.key)", $true)

            if ($stage.key -eq "export rules"){
                
                    $counter = 0
                    $logger.logInfo("Export Rules in progress", $true)
                    Start-Sleep 30
                    $Status = (Get-Service $serchk).Status
                    if ( $Status -ne 'Running') 
                    {
                    do 
                        {
							if($counter -eq 5){
                            break}
                            $counter++
                            Start-Sleep 10
                            
                        } until ((Get-Service $serchk).Status -eq 'Running')
                    }
                        }

                $command = $stage.value
				$successful = Use-ConfigTool $command $params $backupParams.tempConfigLogFile

                # if importing config, then need to restart server after config re-imported
                if ($stage.key -eq "import config"){
                    $logger.logInfo("Restarting server....", $True)
					stageExit($MyInvocation.MyCommand)
                    StopNetAnServer($backupParams.serviceNetAnServerOld)
                    StartNetAnServer
                }

               

                if ($successful) {
                    $logger.logInfo("Stage $($stage.key) executed successfully", $true)
                    continue
                } else {
                    $logger.logError($MyInvocation, "Error while executing Stage $($stage.key)", $True)
                    Write-Error "Stage Failed."
                }
            }
			}

    }
    catch {

        $errorMessageLibraryExport = $_.Exception.Message
        $logger.logError($MyInvocation, "`n $errorMessageLibraryExport", $True)
        throw $_.Exception.Message
    }

}
Function BackupPostgreSQLDatabase() {
	$databaseToBackup = 'netanserver_repdb'
	$serverInstance = 'localhost'
	$installationPath = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).InstallLocation
	$batchFile = $backupParams.migrationScriptDirectory + "pg_dump_restore.bat"
	
	stageEnter($MyInvocation.MyCommand)
	(Get-Content $batchFile).replace('<postgresql_install_dir>', $installationPath).replace('<postgresql_password>', $backupParams.platformPassword) | Set-Content $batchFile
	try {
		if(!(test-path $backupParams.backupDirRepdb)) {
			New-Item -ItemType Directory -Force -Path $backupParams.backupDirRepdb | Out-Null
		}
		$tableName = 'network_analytics_feature'
		cmd /c "$batchFile backup $databaseToBackup $tableName 2>&1" | Out-Null
		$logger.logInfo("$databaseToBackup backed up.", $True)
	}
	catch {
		$errorMessageLibraryExport = $_.Exception.Message
		$logger.logError($MyInvocation, "`n $errorMessageLibraryExport", $True)
	}
	finally {
		(Get-Content $batchFile).replace($installationPath,'<postgresql_install_dir>').replace($backupParams.platformPassword,'<postgresql_password>') | Set-Content $batchFile
	}
	stageExit($MyInvocation.MyCommand)
	$env:PSModulePath = $originalEnvPath
	[Environment]::SetEnvironmentVariable("PSModulePath", $originalEnvPath, "Machine")
}


Function Main {
    InitiateLogs $initalinstall
    BackupLibraryContents
    BackupPostgreSQLDatabase
   
}


try {
        Main
        $logger.logInfo("You have successfully completed the automated backup of Network Analytics Server.", $True)
        $logger.logInfo("The backups are located in $($backupParams.backupDir)", $true)
} catch {
		$errorMessageSQL = $_.Exception.Message
		$logger.logError($MyInvocation, "`n $errorMessageSQL", $True)
        throw $_.Exception.Message
}