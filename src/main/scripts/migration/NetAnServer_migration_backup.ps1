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
# Name    : NetanServer_migration_backup.ps1
# Date    : 27/08/2020
# Purpose : Module Used to backup 7.9/7.11 data for 10.10 upgrade
#

$drive = (Get-ChildItem Env:SystemDrive).value
$backupParams = @{}

$netanserver_media_dir = "C:\Ericsson\tmp"

# get platform version info
[xml]$xmlObj = Get-Content "$($netanserver_media_dir)\Resources\version\supported_NetAnPlatform_versions.xml"
$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")

foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'n')
    {
        $previousVersion = $platformVersionString.'version'
        if (Test-Path ("C:\Ericsson\NetAnServer\Server\" + $previousVersion))
        {
            $version = $previousVersion
            $oldServiceVersion = $platformVersionString.'service-version'

        }
    }
}


$backupParams.Add('repdbName', "netAnServer_repdb")
$backupParams.Add('maindir', $drive + "\Ericsson")
$backupParams.Add("backupDir", $maindir + "\Ericsson\Backup")
$backupParams.Add("backupDirRepdb", "$($backupParams.backupDir)\repdb_backup\")
$backupParams.Add("backupDirLibData", "$($backupParams.backupDir)\library_data_backup\")
$backupParams.Add("backupDirLibAnalysisData", $backupParams.backupDirLibData + "libraries\")
$backupParams.Add('setLogName', 'backup.log')
$backupParams.Add('netanserv_home', "$($drive)\Ericsson\NetAnServer")
$backupParams.Add('logDir', $backupParams.netanserv_home + "\Logs")
$backupParams.Add('tomcatbin', "$($backupParams.netanserv_home)\Server\$($version)\tomcat\bin\")
$backupParams.Add('tempConfigLogFile', $backupParams.logDir + "\command_output_temp.log")
$backupParams.Add('serviceNetAnServerOld', "Tss" + $oldServiceVersion)

$platformPassword = Get-EnvVariable "NetAnVar"
$backupParams.Add('platformPassword', $platformPassword)

Import-Module Logger
Import-Module NetAnServerUtility
$loc = Get-location

$global:logger = Get-Logger($LoggerNames.Install)
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
    $Script:stage=$Script:stage
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


### Function: Start-SpotfireService ###
#
#   Starts a Service
#
# Arguments: 
#    [string] $service

# Return Values: boolean
#
Function Start-SpotfireService {
    param (
        [String]$service
    )
    $logger.logInfo("Preparing to start $service`n", $True)
    $serviceExists = Test-ServiceExists $service
    $logger.logInfo("Service $service found: $serviceExists`n", $True)

    if ($serviceExists) {
        $isRunning = Test-ServiceRunning "$($service)"
        if ($isRunning) {
            $logger.logInfo("Service is already running....`n", $True)
            return $True
        } else {
            $logger.logInfo("Starting service....", $True)
        
            try {
                Start-Service -Name "$($service)" -ErrorAction stop  
                
                $isRunning = Test-ServiceRunning "$($service)"
                while(-not $isRunning){          
                    Start-Sleep -s 1
                    $isRunning = Test-ServiceRunning "$($service)"
                }
                
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, $errorMessage, $True)
                return $False
            }

            # double checking service has started properly, as the node manager sometimes starts and
            # stops again a few seconds later, causing the error to avoid being caught
            Start-Sleep -s 10
            $isRunning = Test-ServiceRunning "$($service)"
            if (-not $isRunning) {
                $logger.logError($MyInvocation,"Could not start $service service.", $True)
                return $False
            }

            
        }
    } else {
        $logger.logError($MyInvocation,"Service $service not found. Please check $service install was executed correctly.`n", $True)
        return $False
    }

    return $True
}

### Function: Stop-SpotfireService ###
#
#   Stops a Service
#
# Arguments: 
#    [string] $service

# Return Values: boolean
#
Function Stop-SpotfireService {
    param (
        [String]$service
    )
    $logger.logInfo("Preparing to stop $service", $True)

    $serviceExists = Test-ServiceExists "$service"
    
    if ($serviceExists) {
        $logger.logInfo("Service $service found: $serviceExists", $True)

        $isRunning = Test-ServiceRunning "$service"

        if ($isRunning) {
			$logger.logInfo("$service is running`n", $True)
			$logger.logInfo("Stopping $service...`n", $True)
            try {
                Stop-Service -Name "$service" -ErrorAction stop
                
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not stop service. `n $errorMessage", $True)
                return $False
            }
			
            $logger.logInfo("Service $service has stopped successfully`n")
            return $True
        } else {
			$logger.logInfo("Service has already stopped`n", $True)  
            return $True        
        }


    } else {
        $logger.logError($MyInvocation, "Service $service not found. Please check $service install was executed correctly.`n", $True)
        return $False

    }

    
}



#----------------------------------------------------------------------------------
#    Start the NetAnServer Server Service
#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------
#    Start the NetAnServer Server Service
#----------------------------------------------------------------------------------
Function StartNetAnServer() {
    stageEnter($MyInvocation.MyCommand)
    $service = $backupParams.serviceNetAnServerOld
    $logger.logInfo("Preparing to start NetAnServer Server", $True)
    $startSuccess = Start-SpotfireService($service)

    if ($startSuccess) {
        try {
            $a= Invoke-WebRequest -Uri https://localhost
        }
        catch {
            $logger.logInfo("$($service) has started successfully`n", $True)
        }
        stageExit($MyInvocation.MyCommand)

    } else {
        $logger.logError($MyInvocation, "Could not start service.", $True)
        MyExit($MyInvocation.MyCommand)
    }
}
#----------------------------------------------------------------------------------
#    Stop the NetAnServer Server Service
#----------------------------------------------------------------------------------
Function StopNetAnServer($service) {
    stageEnter($MyInvocation.MyCommand)
	
    $stopSuccess = Stop-SpotfireService($service)

    if ($stopSuccess) {       
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
    try {

        $commandMap = [ordered]@{
            "export config" = "export-config -t $($backupParams.platformPassword) --force";
            "set config prop" = "set-config-prop --name=information-services.clear-data-source-passwords-on-export --value=False";
            "import config" = "import-config -t $($backupParams.platformPassword) -c `"Changing config to retain passwords on export.`"";
            "export users" = "export-users $($backupParams.backupDirLibData)users.txt -i true -t $($backupParams.platformPassword) --force";
            "export groups" = "export-groups $($backupParams.backupDirLibData)groups.txt -t $($backupParams.platformPassword) -m true -u true --force";
            "export library" = "export-library-content --file-path=$($backupParams.backupDirLibAnalysisData)library_content_all --item-type=all_items --library-path=/ --user=$($backupParams.adminUser) -t $($backupParams.platformPassword) --force";
            "export rules" = "export-rules `"$($backupParams.backupDirLibData)rules.json`" -t $($backupParams.platformPassword) --force"
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

                $params = @{}
                $params.tomcatdir = $backupParams.tomcatbin   #Tomcat bin directory
                $logger.logInfo("Executing Stage $($stage.key)", $true)
                $command = $stage.value

                $successful = Use-ConfigTool $command $params $backupParams.tempConfigLogFile

                # if importing config, then need to restart server after config re-imported
                if ($stage.key -eq "import config"){
                    $logger.logInfo("Restarting server....", $True)
                    StopNetAnServer($backupParams.serviceNetAnServerOld)
                    StartNetAnServer
                }

                if ($successful) {
                    $logger.logInfo("Stage $($stage.key) executed successfully", $true)
                    continue
                } else {
                    $logger.logError($MyInvocation, "Error while executing Stage $($stage.key)", $True)
                    Exit
                }
            }
			}

    }
    catch {

        $errorMessageLibraryExport = $_.Exception.Message
        $logger.logError($MyInvocation, "`n $errorMessageLibraryExport", $True)
        Exit
    }

    stageExit($MyInvocation.MyCommand)
}
Function BackupSQLServerDatabase() {

    stageEnter($MyInvocation.MyCommand)
    try {

        $database = 'netanserver_repdb'
        $serverInstance = 'localhost'
        $username = 'netanserver'

        $envVariable = "NetAnVar"
        $password =  $(Get-EnvVariable $envVariable)

        $tableRepdb = 'network_analytics_feature'
        #check if database exists on sql server
        $checkDBExists = Invoke-Sqlcmd -Database $database -Username $username -Password $password -ServerInstance $serverInstance -Query "SELECT name FROM master.sys.databases WHERE name = N'$($backupParams.repdbName)'"
        
        if ($checkDBExists){
         
            If(!(test-path $backupParams.backupDirRepdb))
                {
                    New-Item -ItemType Directory -Force -Path $backupParams.backupDirRepdb | Out-Null
                }
                
            $filename = "$($backupParams.backupDirRepdb)\$tableRepdb"
            $result = Invoke-Sqlcmd -Database $database -Username $username -Password $password -ServerInstance $serverInstance -Query "SELECT * FROM $($backupParams.repdbName).dbo.$tableRepdb"

            # set datetime for system to iso format temporarily while writing to csv
            $culture = Get-Culture
            $oldDatetimeFormat = $culture.DateTimeFormat.ShortDatePattern
            $culture.DateTimeFormat.ShortDatePattern = 'yyyy-MM-dd'
            Set-Culture $culture

            #write to csv file
            $result | Export-Csv -Path "$filename.csv" -NoTypeInformation

            # reset datetime back to old format
            $culture.DateTimeFormat.ShortDatePattern = $oldDatetimeFormat
            Set-Culture $culture
                

            $logger.logInfo("$($backupParams.repdbName) backed up.", $True)
        }else {
            $logger.logInfo("$($backupParams.repdbName) does not exist. No backup required.", $True)
        }

    }
    catch {

        $errorMessageLibraryExport = $_.Exception.Message
        $logger.logError($MyInvocation, "`n $errorMessageLibraryExport", $True)
        Exit
    }

    stageExit($MyInvocation.MyCommand)
}


Function Main {
    InitiateLogs $initalinstall
    BackupLibraryContents
    BackupSQLServerDatabase
   
}


try {
        Main
        $logger.logInfo("You have successfully completed the automated backup of Network Analytics Server.", $True)
        $logger.logInfo("The backups are located in $($backupParams.backupDir).", $true)
} catch {
    $errorMessageSQL = $_.Exception.Message
    $logger.logError($MyInvocation, "`n $errorMessageSQL", $True)
}