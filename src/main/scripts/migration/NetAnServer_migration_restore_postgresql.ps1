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
# Name    : NetanServer_migration_restore_postgresql.ps1
# Date    : 17/08/2021
# Purpose : Module used to restore NetAnServer data (from postgresql database backup)
#

$restoreParams = @{}
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


$restoreParams.Add('backupDir', "C:\Ericsson\Backup")
$restoreParams.Add('netanserv_home', "C:\Ericsson\NetAnServer")
$restoreParams.Add('tempDir', "C:\Ericsson\tmp")
$restoreParams.Add('backupDirDB', "$($restoreParams.backupDir)\postgresql_backup\")
$restoreParams.Add('backupDirLibData', "$($restoreParams.backupDir)\library_data_backup\")
$restoreParams.Add('backupDirLibAnalysisData', $restoreParams.backupDirLibData + "libraries\")
$restoreParams.Add('setLogName', 'NetAnDB_Restore.log')
$restoreParams.Add('logDir', $restoreParams.netanserv_home + "\Logs")
$restoreParams.Add('tomcatbin', "$($restoreParams.netanserv_home)\Server\$($version)\tomcat\spotfire-bin\")
$restoreParams.Add('tempConfigLogFile', $restoreParams.logDir + "\command_output_temp.log")
$restoreParams.Add('migrationScriptDirectory', $restoreParams.tempDir + "\Scripts\migration\")
$restoreParams.Add('serverInstance','localhost')

$password = Get-EnvVariable "NetAnVar"
$platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A',$password ).GetNetworkCredential().Password
$restoreParams.Add('platformPassword', $platformPassword)

Import-Module Logger
Import-Module NetAnServerUtility
Import-Module NetAnServerConfig
$loc = Get-location

$global:logger = Get-Logger($LoggerNames.Install)
$initalinstall = "Restore"


Function InitiateLogs($message) {
    $creationMessage = $null

    If (-not (Test-FileExists($restoreParams.logDir))) {
        New-Item $restoreParams.logDir -ItemType directory | Out-Null
        $creationMessage = "Creating new log directory $($restoreParams.logDir)"
    }

    $logger.setLogDirectory($restoreParams.logDir)
    $logger.setLogName($restoreParams.setLogName)

    $logger.logInfo("Starting the $message of Ericsson Network Analytics Server.", $True)

    If ($creationMessage) {
        $logger.logInfo($creationMessage, $true)
    }

    $logger.logInfo("$message log created $($restoreParams.logDir)\$($logger.timestamp)_$($restoreParams.setLogName)", $True)
    Set-Location $loc
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
}

Function Get-AdminUserName() {
    param(
        [Parameter(Mandatory=$true)]
        [string] $password
        )
    $adminName=Get-Users -all | % { if($_.Group -eq "Administrator") {return $_} } |Select-Object -first 1
    return $adminName.USERNAME
}


Function RestoreBackupLibraryData() {
    stageEnter($MyInvocation.MyCommand)
    $adminUser=Get-AdminUserName $restoreParams.platformPassword
    $restoreParams.Add('adminUser', $adminUser)
	If(test-path $restoreParams.backupDirLibData){
		try {
			$libraryFileName = $restoreParams.backupDirLibAnalysisData + "library_content_all.part0.zip"
			$commandMap = [ordered]@{
            "import users" = "import-users $($restoreParams.backupDirLibData)users.txt -i true -t $($restoreParams.platformPassword)";
            "import groups" = "import-groups $($restoreParams.backupDirLibData)groups.txt -t $($restoreParams.platformPassword) -m true -u true";
            "import library" = "import-library-content --file-path=$($libraryFileName) --conflict-resolution-mode=KEEP_OLD --user=$($restoreParams.adminUser) -t $($restoreParams.platformPassword)";
            "import rules" = "import-rules -p $($restoreParams.backupDirLibData)rules.json -t $($restoreParams.platformPassword)";
            "trust scripts" = "find-analysis-scripts -t  $($restoreParams.platformPassword) -d true -s true -q true --library-parent-path=`"/Ericsson Library/`" -n"
			}

			foreach ($stage in $commandMap.GetEnumerator()) {
				if ($stage) {

					$params = @{}
					$params.spotfirebin = $restoreParams.tomcatbin   
					$logger.logInfo("Executing Stage $($stage.key)", $true)
					$command = $stage.value
					$successful = Use-ConfigTool $command $params $restoreParams.tempConfigLogFile
					if ($successful) {
						$logger.logInfo("Stage $($stage.key) executed successfully", $true)
						continue
					} else {
						$logger.logError($MyInvocation, "Error while executing Stage $($stage.key)", $True)
						return $False
					}
				}
            }
        }
		catch {
			$errorMessageLibraryImport = $_.Exception.Message
			$logger.logError($MyInvocation, "`n $errorMessageLibraryImport", $True)
			Exit
		}
	}
	stageExit($MyInvocation.MyCommand)
}


Function RestorePostgreSQLDatabase() {
	$backedUpDatabase = 'netanserver_repdb'
	$installationPath = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).InstallLocation
	$batchFile = $restoreParams.migrationScriptDirectory + "pg_dump_restore.bat"
	
	stageEnter($MyInvocation.MyCommand)
	try {
		(Get-Content $batchFile).replace('<postgresql_install_dir>', $installationPath).replace('<postgresql_password>', $restoreParams.platformPassword) | Set-Content $batchFile
		$tableName = 'network_analytics_feature'
		cmd /c "$batchFile restore $backedUpDatabase $tableName 2>&1" | Out-Null
		$logger.logInfo("$backedUpDatabase is restored.", $True)
		} 
	catch {
		$errorMessageLibraryExport = $_.Exception.Message
		$logger.logError($MyInvocation, "`n $errorMessageLibraryExport", $True)
	}
	finally {
		(Get-Content $batchFile).replace($installationPath,'<postgresql_install_dir>').replace($restoreParams.platformPassword,'<postgresql_password>') | Set-Content $batchFile
	}
	stageExit($MyInvocation.MyCommand)
}


Function Main {
    InitiateLogs $initalinstall
    RestoreBackupLibraryData
    RestorePostgreSQLDatabase
   
}


try {
        Main
        $logger.logInfo("You have successfully completed the automated restore of Network Analytics Server.", $True)
	} catch {
		$errorMessageSQL = $_.Exception.Message
		$logger.logError($MyInvocation, "`n $errorMessageSQL", $True)
}