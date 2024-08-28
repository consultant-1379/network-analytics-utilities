# ********************************************************************
# Ericsson Radio Systems AB                                     MODULE
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
# Name    : NetanServer_migration_restore.ps1
# Date    : 27/08/2020
# Purpose : Module Used to restore 7.9/7.11 data for 10.10 upgrade
#

$drive = (Get-ChildItem Env:SystemDrive).value
$restoreParams = @{}


$restoreResourcesPath = "C:\Ericsson\NetAnServer\RestoreDataResources\"


[xml]$xmlObj = Get-Content "$($restoreResourcesPath)\version\supported_NetAnPlatform_versions.xml"
$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")

foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'y') {
            $version = $platformVersionString.'version'
        }
}


$restoreParams.Add('resourcesDir',$restoreResourcesPath)
$restoreParams.Add('spotfirebin', $drive + "\Ericsson\NetAnServer\Server\$($version)\tomcat\spotfire-bin\")
$restoreParams.Add('pmdbName', "netAnServer_pmdb")
$restoreParams.Add('repdbName', "netAnServer_repdb")
$restoreParams.Add("backupDir", $drive + "\Ericsson\")
$restoreParams.Add("backupDirVersion", "$($restoreParams.backupDir)\Backup")
$restoreParams.Add("backupDirRepdb", "$($restoreParams.backupDirVersion)\repdb_backup\")
$restoreParams.Add("backupDirPmdb", "$($restoreParams.backupDirVersion)\pmdb_backup\")
$restoreParams.Add("backupDirLibData", "$($restoreParams.backupDirVersion)\library_data_backup\")
$restoreParams.Add("backupDirLibAnalysisData", $restoreParams.backupDirLibData + "libraries\")
$restoreParams.Add('setLogName', 'backup.log')
$restoreParams.Add('netanserv_home', "$($drive)\Ericsson\NetAnServer")
$restoreParams.Add('logDir', $restoreParams.netanserv_home + "\Logs")
$restoreParams.Add('tempConfigLogFile', "$($restoreParams.logDir)\command_output_temp.txt")

$platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable 'NetAnVar')).GetNetworkCredential().Password
$restoreParams.Add('platformPassword', $platformPassword)
$adminUser=Get-AdminUserName $restoreParams.platformPassword
$restoreParams.Add('adminUser', $adminUser)


Import-Module Logger
Import-Module NetAnServerUtility -DisableNameChecking
Import-Module NetAnServerConfig -DisableNameChecking

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
    $adminName=Get-Users -all | % { if($_.Group -eq "Administrator") {return $_} } |Select-Object -first 1
    return $adminName.USERNAME
}

#----------------------------------------------------------------------------------
#    Restore libraries for 7.9/7.11 to 1010 upgrade
#----------------------------------------------------------------------------------

Function RestoreBackupLibraryData(){
    stageEnter($MyInvocation.MyCommand)
    If(test-path $restoreParams.backupDirLibData){
        try {
			$libraryFileName = $restoreParams.backupDirLibAnalysisData + "library_content_all.part0.zip"
            # need to be ran in correct order
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
                    $params.spotfirebin = $restoreParams.spotfirebin
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

#----------------------------------------------------------------------------------
#    Restore databases for 7.9/7.11 to 1010 upgrade
#----------------------------------------------------------------------------------

Function RestoreBackupDatabaseTables(){
    stageEnter($MyInvocation.MyCommand)
    try {
        $paramList = @{}
        $paramList.Add('database', 'netanserver_db')
        $paramList.Add('serverInstance', 'localhost')
        $paramList.Add('username', 'netanserver')
        $envVariable = "NetAnVar"
        $password = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password


        # check if repdb files are available and need to be restored

        if (test-path $restoreParams.backupDirRepdb){

            $logger.logInfo("Restoring netanserver_repdb backup data...", $True)

            #import repdb tables (only the network analytics feature table required for 7.11 to 10.10 upgrade)
            $paramList.Add('repDatabase', 'netanserver_repdb')
            $importREPDBTablesQuery = "COPY netanserver_repdb.public.network_analytics_feature FROM '$($restoreParams.backupDirRepdb)network_analytics_feature.csv' DELIMITER ',' CSV HEADER;"
            $result = Invoke-UtilitiesSQL -Database "netanserver_repdb" -Username $paramList.username -Password $password -ServerInstance $paramList.serverInstance -Query $importREPDBTablesQuery -Action insert

            $logger.logInfo("netanserver_repdb data restored.", $True)

        }
        else {
            $logger.logInfo("netAnServer_repdb backup files not found. Nothing to restore.", $True)
        }

	}

    catch {

        $errorMessageDBImport = $_.Exception.Message
        $logger.logError($MyInvocation, "`n $errorMessageDBImport", $True)
        Exit
    }

    stageExit($MyInvocation.MyCommand)
}



Function Main {
    InitiateLogs $initalinstall
    RestoreBackupLibraryData
    RestoreBackupDatabaseTables

    $logger.logInfo("You have successfully completed the automated restore of Network Analytics Server.", $True)
}

try {
    If(Test-Path $restoreParams.backupDirVersion) {
        Main
    }
} catch {
    $errorMessageSQL = $_.Exception.Message
    $logger.logError($MyInvocation, "`n $errorMessageSQL", $True)
}