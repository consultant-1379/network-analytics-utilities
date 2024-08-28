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
# Name    : NetAnServerConfig.ps1
# Date    : 20/08/2020
# Purpose : #  Installation script for Ericsson Network Analytic Server
#               1. Create logs and directories
#               2. Request input parameters from user
#               3. Check that the perquisites are installed and configured
#               4. Create the PostgreSQL server database
#               5. Install the NetAnServer server software
#               6. Configure the NetAnServer server
#               7. Start NetAnServer
#
# Usage   : NetAnServer_install
#
#

#---------------------------------------------------------------------------------

#----------------------------------------------------------------------------------
#  Following parameters must not be modified
#----------------------------------------------------------------------------------
$ansibleParams = $args[0]
$loc = Get-Location
$drive = (Get-ChildItem Env:SystemDrive).value
$netanserver_media_dir = (get-item $PSScriptRoot).parent.parent.FullName

$Script:stage=0
$Script:instBuild
$Script:major=$FALSE
$install_date = get-date -format "yyyyMMdd_HHmmss"
$serverIP = "127.0.0.1"

# get platform current version num
if(Test-Path "$($netanserver_media_dir)\Resources\version\supported_NetAnPlatform_versions.xml") {
	[xml]$xmlObj = Get-Content "$($netanserver_media_dir)\Resources\version\supported_NetAnPlatform_versions.xml"
	$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")
}
else {
	[xml]$xmlObj = Get-Content "$($netanserver_media_dir)\Resources\version\version_strings.xml"
	$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")
}

foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'y') {
            $version = $platformVersionString.'version'
            $serviceVersion = $platformVersionString.'service-version'
            $versionType = $platformVersionString.'release-type'
        }
}

$installParams = @{}
$installParams.Add('sv', $serviceVersion)
$installParams.Add('currentPlatformVersion', $version)
$installParams.Add('netAnServerIP', $serverIP)
$installParams.Add('installDir', $drive + "\Ericsson\NetAnServer")
$installParams.Add('analystDir', $drive + "\Ericsson\Analyst")
$installParams.Add('languagepack', $drive + "\Ericsson")
$installParams.Add('migrationDir', $drive + "\Ericsson\Migration")
$installParams.Add('scriptsDir',$drive + "\Ericsson\NetAnServer\Scripts")
$installParams.Add('SSOScriptDir',$installParams.scriptsDir + "\sso")
$installParams.Add('deployDir', $drive + "\Ericsson\tmp")
$installParams.Add('deploySSODir',$installParams.deployDir + "\Scripts\sso")
$installParams.Add('installResourcesDir', $installParams.installDir+"\Resources")
$installParams.Add('automationServicesDir', $installParams.installDir+"\AutomationServices\"+$version)
$installParams.Add('installServerDir', $installParams.installDir + "\Server\"+$version)
$installParams.Add('mediaDir', $netanserver_media_dir +"\Software")
$installParams.Add('resourcesDir', $netanserver_media_dir +"\Resources")
$installParams.Add('featureInstallerDir', $installParams.resourcesDir +"\FeatureInstaller\*")
$installParams.Add('featureInstallationDir', $installParams.installDir +"\feature_installation")
$installParams.Add('logDir', $installParams.installDir + "\Logs")
$installParams.Add('tomcatDir', $installParams.installServerDir + "\tomcat\bin\")
$installParams.Add('customFilterDestination', $installParams.installServerDir + "\tomcat\webapps\spotfire\WEB-INF\lib")
$installParams.Add('jConnDir', $installParams.installServerDir + "\tomcat\lib\")
$installParams.Add('PSModuleDir', $installParams.installDir + "\Modules")
$installParams.Add('setLogName', 'NetAnServer.log')
$installParams.Add('createDBLog', $installParams.logDir + "\" + $install_date + "_postgres_db.log")
$installParams.Add('createActionLogDBLog', $installParams.logDir + "\" + $install_date + "_actionlog_postgres_db.log")
$installParams.Add('updatedbDBLog', $installParams.logDir + "\" + $install_date + "_postgres_db_update.log")
$installParams.Add('serverLog', $installParams.logDir + "\" + $install_date + "_Server_Component.log")
$installParams.Add('runtimeStage', $installParams.resourcesDir + "\runtimeStage\runtime_stages.xml")
$installParams.Add('initialInstallStage', $installParams.logDir + "\" + "initialInstallStage.log")
$installParams.Add('upgradeStage', $installParams.logDir + "\" + "upgradeStage.log")
$installParams.Add('deploymentLog', $installParams.logDir + "\" + $install_date + "_NetAnServer_deployment.log")
$installParams.Add('databaseLog', $installParams.resourcesDir + "\sql\log.txt")
$installParams.Add('spotfirebin', $installParams.installServerDir + "\tomcat\spotfire-bin\") ## added for spotfire-bin dir in tomcat
$installParams.Add('configTool', $installParams.spotfirebin + "config.bat")     ## Changed config path
$installParams.Add('createDBScript', $installParams.resourcesDir + "\sql\create_databases.bat")   # Changed path for PostgreSQL
$installParams.Add('createActionLogDBScript', $installParams.resourcesDir + "\sql\actionlog\create_actionlog_db.bat") 
$installParams.Add('updateDBScript', $installParams.resourcesDir +"\hotfix\update_database.bat")
$installParams.Add('generalHotfix', $installParams.resourcesDir +"\hotfix\Spotfire.Dxp.sdn")
$installParams.Add('hotfixDir', $installParams.resourcesDir +"\hotfix")
$installParams.Add('updateDBScriptTarget', $installParams.mediaDir + "\HotFix\Server\HF-015\database\mssql\update_database.bat")
$installParams.Add('moduleDir', $netanserver_media_dir + "\Scripts\Modules")
$installParams.Add('instrumentationDir', $netanserver_media_dir + "\Scripts\Instrumentation\*")
$installParams.Add('ssoDir', $netanserver_media_dir + "\Scripts\sso\*")
$installParams.Add('EncryptedPasswordDir', $netanserver_media_dir + "\Scripts\ConfigureEncryptedPassword\*")
$installParams.Add('PGDBUserPasswordDir', $netanserver_media_dir + "\Scripts\UpdatePGDBUserPassword\*")
$installParams.Add('decryptNetAn', $netanserver_media_dir + "\Scripts\DecryptNetAn\")
$installParams.Add('userMaintenanceDir', $netanserver_media_dir + "\Scripts\User_Maintenance\*")
$installParams.Add('backupRestoreScriptsDir', $installParams.installDir + "\Scripts\backup_restore")
$installParams.Add('nfsShareLogDir', $drive + "\Ericsson\Instrumentation\DDC")
$installParams.Add('instrumentationScriptsDir', $installParams.installDir + "\Scripts\Instrumentation")
$installParams.Add('ssoScriptsDir', $installParams.installDir + "\Scripts\sso")
$installParams.Add('ConfigureEncryptedPasswordDir', $installParams.installDir + "\Scripts\ConfigureEncryptedPassword")
$installParams.Add('UpdatePGDBUserPasswordDir', $installParams.installDir + "\Scripts\UpdatePGDBUserPassword")
$installParams.Add('userMaintenanceScriptsDir', $installParams.installDir + "\Scripts\User_Maintenance")
$installParams.Add('dataCollectorScriptPath', $installParams.instrumentationScriptsDir  + "\DataCollector\Create_Data_Collector.ps1")
$installParams.Add('parserScriptPath', $installParams.instrumentationScriptsDir  + "\Parser\Parser.ps1")
$installParams.Add('userAuditScriptPath', $installParams.instrumentationScriptsDir  + "\UserAudit\UserAudit.ps1")
$installParams.Add('customFolderCreationScriptPath', $installParams.userMaintenanceScriptsDir  + "\CustomFolderCreation\CustomFolderCreation.ps1")
$installParams.Add('serverSoftware', $installParams.mediaDir + "\Server\setup-win64.exe")
$installParams.Add('jConnSrcDir', $installParams.resourcesDir + "\jconn")
$installParams.Add('jConnSrc', $installParams.jConnSrcDir + "\jconn-4.jar")
$installParams.Add('netAnServerDataSource', $installParams.resourcesDir + "\config\datasource_template.xml")
$installParams.Add('netanserverDeploy', $installParams.mediaDir + "\deployment\Spotfire.Dxp.sdn")
$installParams.Add('nodeManagerDeploy', $installParams.mediaDir + "\deployment\Spotfire.Dxp.NodeManagerWindows.sdn")
$installParams.Add('pythonDeploy', $installParams.mediaDir + "\deployment\Spotfire.Dxp.PythonServiceWindows.sdn")  # Python Deploymnet
$installParams.Add('TERRDeploy', $installParams.mediaDir + "\deployment\Spotfire.Dxp.TerrServiceWindows.sdn")  # TERR Deploymnet
$installParams.Add('serverHF', $installParams.mediaDir + "\HotFix\Server\HF-015\Spotfire.Dxp.NodeManagerWindows.sdn")
$installParams.Add('applicationHF', $installParams.mediaDir + "\HotFix\Application\HF-016\Distribution\Spotfire.Dxp.sdn")
$installParams.Add('netanserverBranding', $installParams.resourcesDir + "\cobranding\NetAnServerBranding.spk")
$installParams.Add('legalwarningxml', $installParams.resourcesDir + "\cobranding\Important_Legal_Notice.xml")
$installParams.Add('indexHTML', $installParams.resourcesDir + "\cobranding\index.html")
$installParams.Add('colorPalette', $installParams.resourcesDir + "\colorPalette\Medium.Color.Palette.dxpcolor")
$installParams.Add('filterSrc', $installParams.resourcesDir + "\custom_filter\CustomAuthentication.jar")
$installParams.Add('jobSenderConfig', $installParams.resourcesDir + "\automationServices\Spotfire.Dxp.Automation.ClientJobSender.exe.config")
$installParams.Add('jobSenderTool', $installParams.resourcesDir + "\automationServices\Spotfire.Dxp.Automation.ClientJobSender.exe")
$installParams.Add('netanserverGroups', $installParams.resourcesDir + "\groups\groups.txt")
$installParams.Add('netanserverSSOGroups', $installParams.resourcesDir + "\groups\ssogroups.txt")
$installParams.Add('sqlAdminUser', 'postgres')  # changed adminuser to postgres
$installParams.Add('dbName', "netanserver_db")
$installParams.Add('actionLogdbName', "netanserveractionlog_db")
$installParams.Add('repDbDumpFile', $installParams.resourcesDir + "\sql\create_netanserver_repdb.sql")
$installParams.Add('platformVersionDir', $installParams.resourcesDir + "\version\")
$installParams.Add('repDbName', "netanserver_repdb")
$installParams.Add('dbUser', "netanserver")
$installParams.Add('connectIdentifer', "localhost")
$installParams.Add('serviceNetAnServer', "Tss" + $serviceVersion)
$installParams.Add('dbDriverClass', "org.postgresql.Driver ")  # changed the driver class
$installParams.Add('dbURL', "jdbc:postgresql://localhost:5432/"+$installParams.dbName)
$installParams.Add('actiondbURL', "jdbc:postgresql://localhost:5432/"+$installParams.actionLogdbName)
$installParams.Add('configName', "Network Analytics Server Default Configuration "+$version)
$installParams.Add('osVersion2012', 'Microsoft Windows Server 2012 R2 Standard')
$installParams.Add('osVersion2016', 'Microsoft Windows Server 2016 Standard')
$installParams.Add('osVersion2019', 'Microsoft Windows Server 2019 Standard')
$installParams.Add('osVersion2022', 'Microsoft Windows Server 2022 Standard')
$installParams.Add('serverPort', 443)
$installParams.Add('serverRegistrationPort', 9080)
$installParams.Add('serverCommunicationPort', 9443)
$installParams.Add('libraryLocation', $installParams.resourcesDir +  "\library\LibraryStructure.part0.zip")
$installParams.Add('installNodeManagerDir', $installParams.installDir + "\NodeManager\"+$version)
$installParams.Add('nodeManagerSoftware', $installParams.mediaDir + "\NodeManager\nm-setup.exe")
$installParams.Add('nodeRegistrationPort', 9081)
$installParams.Add('nodeCommunicationPort', 9444)
$installParams.Add('nodeManagerLog', $installParams.logDir + "\" + $install_date + "_Node_Manager_Install.log")
$installParams.Add('nodeServiceName',"WpNmRemote" + $serviceVersion)    # Changes Node Manager service name
$installParams.Add('nodeManagerConfigDir',$installParams.installNodeManagerDir + "\nm\config\")
$installParams.Add('nodeManagerConfigFile',$installParams.resourcesDir + "\NodeManager\default.conf")
$installParams.Add('nodeManagerConfigDirFile',$installParams.nodeManagerConfigDir + "default.*")
$installParams.Add('backupRestoreDir', $netanserver_media_dir + "\Scripts\backup_restore\")
$installParams.Add('serverCertInstall', $installParams.installServerDir + "\tomcat\certs\")
$installParams.Add('serverConfInstall', $installParams.installServerDir + "\tomcat\conf")
$installParams.Add('serverLegalWarningDir', $installParams.installServerDir + "\tomcat\webapps\spotfire\")
$installParams.Add('serverConfInstallXml', $installParams.serverConfInstall + "\server.xml")
$installParams.Add('serverConfig', $installParams.resourcesDir + "\serverConfig\server.xml")
$installParams.Add('webConfigLog4net', $installParams.resourcesDir + "\webConfig\log4net.config")
$installParams.Add('webConfigWeb', $installParams.resourcesDir + "\webConfig\Spotfire.Dxp.Worker.Web.config")
$installParams.Add('webConfigHost', $installParams.resourcesDir + "\webConfig\Spotfire.Dxp.Worker.Host.exe.config")
$installParams.Add('nodeManagerServices', $installParams.installNodeManagerDir + "\nm\services\")
$installParams.Add('webWorkerDir', $installParams.nodeManagerServices)
$installParams.Add('ericssonDir', $drive + "\temp\media\netanserver\")
$installParams.Add('scheduledUpdateUser', 'scheduledupdates@SPOTFIRESYSTEM')
$installParams.Add('automationServicesUser', 'automationservices@SPOTFIRESYSTEM')
$installParams.Add('analystLog', $installParams.logDir + "\" + $install_date + "_AnalystClient_Install.log")
$installParams.Add('confignode', $installParams.logDir + "\" + "confignode.txt")
$installParams.Add('analystSoftware', $installParams.mediaDir + "\Analyst\setup.exe")
$installParams.Add('languagepackmedia', $installParams.mediaDir + "\languagepack")
$installParams.Add('tomcatServerLogDir', $installParams.installServerDir + "\tomcat\logs")
$installParams.Add('netanserverServerLogDir', $drive + "\Ericsson\NetAnServer\Logs")
$installParams.Add('nodeManagerLogDir', $installParams.installNodeManagerDir + "\nm\logs")
$installParams.Add('instrumentationLogDir', $drive + "\Ericsson\Instrumentation")
$installParams.Add('javaPath', $installParams.installServerDir + "\jdk\bin")
$installParams.Add('keytabfile', $installParams.installServerDir + "\jdk\jre\lib\security\spotfire.keytab")
$installParams.Add('serverHFJar', $installParams.mediaDir + "\HotFix\Server\HF-015\hotfix.jar")
$installParams.Add('groupLibName', "Library Administrator")
$installParams.Add('groupSAName', "Script Author")
$installParams.Add('groupAutoServiceName', "Automation Services Users")
$installParams.Add('PSQL_PATH', "C:\Program Files\PostgreSQL\14\bin")
$installParams.Add('restoreDataPath', $installParams.installDir + "\RestoreDataResources")
$installParams.Add('housekeepingDir', $installParams.installDir + "\Housekeeping")
$installParams.Add('housekeepingScript', $netanserver_media_dir + "\Resources\Housekeeping\Housekeeping.ps1")
$installParams.Add('folderResourceDir', "$PSScriptRoot\resources\")
$installParams.Add('groupTemplate', $installParams.resourcesDir +"\adhoc_resources\adhocgroups.txt")
$installParams.Add('featureVersion', $installParams.installDir +"\Features\Ad-HocEnabler")
$installParams.Add('customLib', $installParams.resourcesDir +"\adhoc_resources\custom.part0.zip")
$installParams.Add('adhocLogDir', $installParams.installDir + "\Logs\AdhocEnabler")
$installParams.Add('adhoc_xml', $installParams.resourcesDir +"\adhoc_resources\meta-data.xml")
$installParams.Add('adhoc_user_lib',$installParams.installDir + "\Features\Ad-HocEnabler\resources\folder")
$installParams.Add('ConfigureEnryptedPasswordjarDir', $installParams.resourcesDir + "\certificatePasswordEncryptDecrypt\PasswordEncryptionDecryption.jar")
$installParams.Add('connectorProtocol', "com.password.creation.CustomHttp11NioProtocol")
$installParams.Add('LibPath', "C:\Ericsson\NetAnServer\Server\" + $version + "\tomcat\lib")
$installParams.Add('TomcatEnryptedPasswordjar', $installParams.LibPath + "\PasswordEncryptionDecryption.jar")
$installParams.Add('JDKPath', "C:\Ericsson\NetAnServer\Server\" + $version + "\jdk")

$TestHostAndDomainStatus=$false

if((Test-Path ("C:\Ericsson\NetAnServer\Modules\NetAnServerUtility\NetAnServerUtility.psm1")) -And (Test-Path 'env:NetAnVar')) {
	if (Get-Module -ListAvailable NetAnServerUtility) {
		Import-Module -DisableNameChecking NetAnServerUtility
		Remove-Module NetAnServerUtility
	}
$envVariable = "NetAnVar"
Import-Module "C:\Ericsson\NetAnServer\Modules\NetAnServerUtility\NetAnServerUtility.psm1"
$platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
$installParams.Add("platformPass", $platformPassword)	
}

foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'n')
    {
        $previousVersion = $platformVersionString.'version'
        if (Test-Path ("C:\Ericsson\NetAnServer\Server\" + $previousVersion))
        {
            $oldVersion = $previousVersion
            $oldServiceVersion = $platformVersionString.'service-version'
            $oldAnalystinstallerExt = $platformVersionString.'analystinstaller-ext'
            $oldStatisticalServicesExt = $platformVersionString.'statistical-services-ext'
			$installParams.Add('installServerDirOld', $installParams.installDir + "\Server\"+$oldVersion)
            $installParams.Add('previousPlatformVersion', $oldVersion)
			if($oldVersion -eq "7.11") {
				$installParams.Add('previousSpotfirebin',$installParams.installServerDirOld + "\tomcat\bin\")
				$installParams.Add('TSSPath',$installParams.installServerDirOld + "\tomcat\bin\")
				$installParams.Add('TSNMPath', $installParams.installDir+"\NodeManager\"+$oldVersion+"\nm\config\nodemanager.properties")
				$installParams.Add('TSNMKeyStorePath', $installParams.installDir+"\NodeManager\"+$oldVersion+"\nm\trust\keystore.p12")
				$installParams.Add('previoustomcat',$installParams.installServerDirOld + "\tomcat\")
			}
			else {
				$installParams.Add('previousSpotfirebin',$installParams.installServerDirOld + "\tomcat\spotfire-bin\")
				$installParams.Add('TSSPath',$installParams.installServerDirOld + "\tomcat\spotfire-bin\")
				$installParams.Add('TSNMPath', $installParams.installDir+"\NodeManager\"+$oldVersion+"\nm\config\nodemanager.properties")
				$installParams.Add('TSNMKeyStorePath', $installParams.installDir+"\NodeManager\"+$oldVersion+"\nm\trust\keystore.p12")
				$installParams.Add('previoustomcat',$installParams.installServerDirOld + "\tomcat\")
				$installParams.Add('previousjdkbin',$installParams.installServerDirOld + "\jdk\bin\")
				
			}
        }
    }
}
# if there is an old version to replace or back up directories, set variables
if ($oldVersion){
    $installParams.Add("backupDir", $drive + "\Ericsson\Backup\")
    $installParams.Add('OldNetAnServerDir',$drive + "\Ericsson\NetAnServer\Server\" + $oldVersion)
    $installParams.Add('serviceNetAnServerOld', "Tss" + $oldServiceVersion)
    $installParams.Add('nodeServiceNameOld',"WpNmRemote" + $oldServiceVersion)
    $installParams.Add('statsServiceNameOld',"TSSS" + $oldStatisticalServicesExt +"StatisticalServices" + $oldStatisticalServicesExt)
    $installParams.Add('automationServicesDirectoryOld',$installParams.installDir + '\AutomationServices\' + $oldVersion)
    $installParams.Add('statsServicesDirectoryOld',$installParams.installDir + '\StatisticalServices' + $oldStatisticalServicesExt)
    $installParams.Add('analystinstallerExeOld',$installParams.analystDir + '\setup' + $oldAnalystinstallerExt +'.exe')

    #params used for backup 7.9/7.11 to 10.10
    $installParams.Add('hotfixesDirectory',$installParams.installDir +'\Server\hotfixes')
    $installParams.Add('serverCertInstallOldXml', $installParams.OldNetAnServerDir + "\tomcat\conf\server.xml")
    $installParams.Add("backupDirRepdb", $installParams.backupDir + "repdb_backup\")
    $installParams.Add("backupDirPmdb", $installParams.backupDir + "pmdb_backup\")
    $installParams.Add("backupDirLibData", $installParams.backupDir + "library_data_backup\")
    $installParams.Add("backupDirLibAnalysisData", $installParams.backupDirLibData + "libraries\")
    $installParams.Add("tempConfigLogFile", $installParams.logDir + "\command_output_temp.temp.log")
}

#----------------------------------------------------------------------------------
#  Set PSModulePath and Copy modules
#----------------------------------------------------------------------------------

if(-not $env:PSModulePath.Contains($installParams.PSModuleDir)){
    $PSPath = $env:PSModulePath + ";"+$installParams.PSModuleDir
    [Environment]::SetEnvironmentVariable("PSModulePath", $PSPath, "Machine")
    $env:PSModulePath = $PSPath
}

# for Re-enabling SSO during Upgrade(if required)
if(Test-Path $($installParams.logDir+"\sso-config-enable.txt")){
	Set-ItemProperty $($installParams.logDir+"\sso-config-enable.txt") -name IsReadOnly -value $false
	Remove-Item $($installParams.logDir+"\sso-config-enable.txt")
}
if(Test-Path $($installParams.ssoScriptsDir+"\sso-config-enable.txt")){
	Copy-Item -Path $($installParams.ssoScriptsDir+"\sso-config-enable.txt") -Destination $installParams.logDir
}

try {
    if( -not (Test-Path($installParams.installDir))){
        New-Item $installParams.installDir -type directory | Out-Null
    }

    if( -not (Test-Path($installParams.featureInstallationDir))){
            New-Item $installParams.featureInstallationDir -type directory | Out-Null
    }

    if( -not (Test-Path($installParams.instrumentationScriptsDir))){
        New-Item $installParams.instrumentationScriptsDir -type directory | Out-Null
    }

    if( -not (Test-Path($installParams.userMaintenanceScriptsDir))){
            New-Item $installParams.userMaintenanceScriptsDir -type directory | Out-Null
    }

    if( -not (Test-Path($installParams.backupRestoreScriptsDir))){
        New-Item $installParams.backupRestoreScriptsDir -type directory | Out-Null
    }

    if( -not (Test-Path($installParams.installResourcesDir))){
        New-Item $installParams.installResourcesDir -type directory | Out-Null
    }

    if( -not (Test-Path($installParams.analystDir))){
        New-Item $installParams.analystDir -type directory | Out-Null
    }
    if( -not (Test-Path($installParams.languagepack))){
        New-Item $installParams.languagepack -type directory | Out-Null
    }
    if( -not (Test-Path($installParams.automationServicesDir))){
        New-Item $installParams.automationServicesDir -type directory | Out-Null
    }
	if( -not (Test-Path($installParams.ssoScriptsDir))){
        New-Item $installParams.ssoScriptsDir -type directory | Out-Null
    }

    if ( -not (Test-Path $installParams.adhocLogDir)) {
        New-Item $installParams.adhocLogDir -Type Directory | Out-Null
    }
    if ( -not (Test-Path $installParams.featureVersion)) {
        New-Item $installParams.featureVersion -Type Directory -ErrorAction SilentlyContinue| Out-Null
    }
	
	if ( -not (Test-Path $installParams.ConfigureEncryptedPasswordDir)) {
        New-Item $installParams.ConfigureEncryptedPasswordDir -Type Directory -ErrorAction SilentlyContinue| Out-Null
    }
	
	if ( -not (Test-Path $installParams.UpdatePGDBUserPasswordDir)) {
        New-Item $installParams.UpdatePGDBUserPasswordDir -Type Directory -ErrorAction SilentlyContinue| Out-Null
    }

    Copy-Item -Path $installParams.moduleDir -Destination $installParams.installDir -Recurse -Force
    Copy-Item -Path $installParams.featureInstallerDir -Destination $installParams.featureInstallationDir -Recurse -Force
    Copy-Item -Path $installParams.instrumentationDir -Destination $installParams.instrumentationScriptsDir -Recurse -Force
    Copy-Item -Path $installParams.userMaintenanceDir -Destination $installParams.userMaintenanceScriptsDir -Recurse -Force
    Copy-Item -Path $installParams.backupRestoreDir -Destination $installParams.backupRestoreScriptsDir -Recurse -Force
    Copy-Item -Path $installParams.colorPalette -Destination $installParams.installResourcesDir -Recurse -Force
    Copy-Item -Path $installParams.netanserverSSOGroups -Destination $installParams.installResourcesDir -Recurse -Force
    Copy-Item -Path $installParams.filterSrc -Destination $installParams.installResourcesDir -Recurse -Force
    Copy-Item -Path $installParams.jobSenderConfig -Destination $installParams.automationServicesDir -Recurse -Force
    Copy-Item -Path $installParams.jobSenderTool -Destination $installParams.automationServicesDir -Recurse -Force
	Copy-Item -Path $installParams.ssoDir -Destination $installParams.ssoScriptsDir -Recurse -Force
	Copy-Item -Path $installParams.EncryptedPasswordDir -Destination $installParams.ConfigureEncryptedPasswordDir -Recurse -Force
	Copy-Item -Path $installParams.PGDBUserPasswordDir -Destination $installParams.UpdatePGDBUserPasswordDir -Recurse -Force
	
	
	if(Test-Path $($installParams.logDir+"\sso-config-enable.txt")){
		if(Test-Path $($installParams.ssoScriptsDir+"\sso-config-enable.txt")){
			Set-ItemProperty $($installParams.ssoScriptsDir+"\sso-config-enable.txt") -name IsReadOnly -value $false
			Remove-Item $($installParams.ssoScriptsDir+"\sso-config-enable.txt")
		}
		Copy-Item -Path $($installParams.logDir+"\sso-config-enable.txt") -Destination $installParams.ssoScriptsDir
	}

} catch {
    $fileErrorMessage = "ERROR creating and transferring directories:" +
        "`n$($installParams.moduleDir) -> $($installParams.installDir)" +
        "`n$($installParams.featureInstallerDir) -> $($installParams.featureInstallationDir)" +
        "`n$($installParams.instrumentationDir) -> $($installParams.instrumentationScriptsDir)" +
        "`n$($installParams.userMaintenanceDir) -> $($installParams.userMaintenanceScriptsDir)" +
        "`n$($installParams.backupRestoreDir) -> $($installParams.backupRestoreScriptsDir)"
    Write-Host $fileErrorMessage -ForegroundColor Red
}



Import-Module Logger
Import-Module NetAnServerUtility
Import-Module NetAnServerConfig
Import-Module -DisableNameChecking NetAnServerDBBuilder
Import-Module NetAnServerServerInstaller
Import-Module NfsShareConfig
Import-Module InstallLibrary
Import-Module ManageUsersUtility -DisableNameChecking
Import-Module PlatformVersionController -DisableNameChecking
Import-Module NetAnServerNodeManagerInstaller -DisableNameChecking
Import-Module ConfigurationUpdater -DisableNameChecking
Import-Module AnalystInstaller
Import-Module ServerConfig
Import-Module AutomateIIUpgrade
Import-Module Upgrade

$global:logger = Get-Logger($LoggerNames.Install)
$initalinstall="Initial Install"
$Upgrade="Upgrade"

Function Main() {
	
	$stageFile = $installParams.initialInstallStage
    InitiateLogs $initalinstall
	if(-not(Test-Path $installParams.runtimeStage)) {
        $logger.logError($MyInvocation, "Runtime Stage File Not Found :: $($installParams.runtimeStage)", $True)
		Exit
	}
    SetAutomationFilePermission
    InputParameters
	$logger.logInfo("Checking if Initial Install Stage File is present", $True)
	if(Test-Path $installParams.initialInstallStage) {
		$logger.logInfo("Initial Install Stage File Found", $True)
		$logger.logInfo("Reading Last Executed Stage from Stage File", $True)
		$lastexecutedStage = Get-Content $installParams.initialInstallStage  -tail 1
		if($lastexecutedStage -eq ""){
			$logger.logInfo("Invalid entry found in Initial Install Stage File", $True)
			$logger.logInfo("Initial Install Stage File will be removed and Process will begin from Start", $True)
			Remove-Item $installParams.initialInstallStage| Out-Null
			Out-File -FilePath $installParams.initialInstallStage
			$logger.logInfo("New Initial Install Stage File Created :: $($installParams.initialInstallStage)", $True)
			$startFromBeginingFlag = $True
		}
		else {
			$logger.logInfo("Last Executed Stage found in Initial Install Stage File :: "+$lastexecutedStage, $True)
			$confirmation = ''
			while(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
				$confirmation = $(Write-Host "`n`nPlease Enter "-NoNewline; write-host -fore Yellow ("y")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Continue")-NoNewline;write-host(" from ")-NoNewline;write-host -fore Yellow ("$($lastexecutedStage) Stage")-NoNewline;write-host(" or Enter ")-NoNewline;write-host -fore Yellow ("n")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Start Over`n"); Read-Host)
				if(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
					customWrite-host "`nInvalid Confirmation Input Provided!! Please Re-Enter ..."
				}
			}
			if($confirmation -eq 'y') {
				$logger.logInfo("Confirmation provided to continue from "+$lastexecutedStage, $True)
				$logger.logInfo("Process will continue from "+$lastexecutedStage, $True)
				$startFromBeginingFlag = $False
			}
			else {
				$logger.logInfo("Initial Install Stage File will be removed and Process will begin from Start", $True)
				Remove-Item $installParams.initialInstallStage| Out-Null
				Out-File -FilePath $installParams.initialInstallStage
				$logger.logInfo("New Initial Install Stage File Created :: $($installParams.initialInstallStage)", $True)
				$startFromBeginingFlag = $True
			}
		}
		
	}
	else{
		$logger.logInfo("Initial Install Stage File Not Found", $True)
		$logger.logInfo("Process will begin from Start", $True)
		$logger.logInfo("Creating Initial Install Stage File", $True)
		Out-File -FilePath $installParams.initialInstallStage
		$logger.logInfo("Initial Install Stage File Created :: $($installParams.initialInstallStage)", $True)
		$startFromBeginingFlag = $True
	}
	[xml]$xmlObj = Get-Content $installParams.runtimeStage
	$install_stage = $xmlObj.SelectNodes("//initialInstall")
	foreach ($stage in $install_stage)
	{
		$stages = $stage.'stages'
	}
	$runtimeList = $stages.Split(",")
	$start = 0
	if($startFromBeginingFlag -eq $False) {
		for ($start = 0; $start -lt $runtimeList.Count; $start++)
		{
			if($runtimeList[$start].contains($lastexecutedStage)){
				Break
			}
		}
	}	
	for ($continue = $start; $continue -lt $runtimeList.Count; $continue++)
	{
		if($runtimeList[$continue].contains(" ")){
			$splitString = $runtimeList[$continue].split(" ")
			$var = Invoke-Expression($splitString[1])
			&$splitString[0] $var
			
		}
		else{
			&$runtimeList[$continue]
		}
	}
    $logger.logInfo("You have successfully completed the automated installation of Network Analytics Server.", $True)

}

Function MainUpgrade() {
	Set-EnvVariable $installParams.platformPass "NetAnVar"
	$envVariable = "NetAnVar"
	$platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
	if($platformPassword) {
		$logger.logInfo("Environment Variable NetAnVar Updated Successfully!!", $True)
	}
	else {
		$logger.logError($MyInvocation, "Failed to Update Environment Variable NetAnVar", $True)
		MyExit($MyInvocation.MyCommand)
	}
	
    InitiateLogs $upgrade
    SetAutomationFilePermission

    $platformReleaseXml = Get-Item "$($installParams.platformVersionDir)\platform-utilities-release.*xml"
	if(-not $platformReleaseXml) {
		$logger.logError($MyInvocation, "The platform-utilities-release.xml was not detected in media. Media is not complete", $True)
		MyExit($MyInvocation.MyCommand)
	}

#are there more than one platform-utilities-release files
	if($platformReleaseXml.Count -gt 1) {
		$logger.logError($MyInvocation, "There are duplicate plaform-release.xml files detected. Media is not correct", $True)
		MyExit($MyInvocation.MyCommand)
	}

#does it contain a build/rstate
	$newBuildNumber = ($platformReleaseXml.Name).Split('.')[-2]

	if(-not ($newBuildNumber -Match "^R")) {
		$logger.logError($MyInvocation, "The platform-utilities-release.xml file is not named correctly. It does not contain a valid Build number", $True)
		MyExit($MyInvocation.MyCommand)
	}
	$envVar = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable "NetAnVar")).GetNetworkCredential().Password
	$platformDetails = Get-PlatformVersionsFromDB $envVar
	if(-not $platformDetails[0]) {
		$logger.logError($MyInvocation, $platformDetails[1])
		$logger.logError($MyInvocation, "An error has occured in upgrade. Please refer to the upgrade log. Exiting upgrade", $True)
		MyExit($MyInvocation.MyCommand)
	}

	$installedPlatformRecord = Get-PlatformVersions | Where-Object -FilterScript { $_.'PRODUCT-ID'.trim() -eq 'CNA4032940' }
	$installedBuild = ($installedPlatformRecord).BUILD
	$Script:instBuild=$installedBuild
	
	if(($installedPlatformRecord | Measure-Object).Count -eq 0) {
		$logger.logWarning("Aborting upgrade. Please Perform Initial Install of NetAn", $True)
		Exit
	}

	if(($installedPlatformRecord | Measure-Object).Count -gt 1) {
		$logger.logWarning("Aborting upgrade. netAnserver_repdb is inconsistent. There are multiple versions of the platform installed", $True)
		Exit
	}
	$installedPlatformRecord = Get-PlatformVersions | Where-Object -FilterScript { $_.'PRODUCT-ID'.trim() -eq 'CNA4032940' }
	$installedBuild = $installedPlatformRecord.build
	$installedBuild = $installedBuild.trim()
	if(($installedBuild.Substring(1,2))[1] -match '\d') {
		[int]$installedBuildRelease = $installedBuild.Substring(1,2)
	}
	else {
		[int]$installedBuildRelease = (($installedBuild.Substring(1,2))[0].toString())
	}

	$newBuildNumber = ($platformReleaseXml.Name).Split('.')[-2]
	[int]$newBuildNumberRelease = $newBuildNumber.Substring(1,2)
	$logger.logInfo("Installed Build :: $($installedBuild)", $True)
	$logger.logInfo("New Build :: $($newBuildNumber)", $True)
	

	if($newBuildNumberRelease -gt $installedBuildRelease) {
		$checkAnalystInstance = $False
		$logger.logInfo("Checking if any Instance of Analyst Client is open...", $True)
		$checkAnalystProcess = Get-Process -Name Spotfire.Dxp -ErrorAction SilentlyContinue
		if($checkAnalystProcess) {
			$checkAnalystInstance = $True
		}
		if($checkAnalystInstance) {
			$logger.logWarning("Instance of Analyst Client is open", $True)
			$logger.logInfo("Please close the Analyst and Re-run the Upgrade. Exiting the script now...", $True)
			Exit
		}
		else {
			$logger.logInfo("No open Instance of Analyst found. Proceeding with Major Upgrade...", $True)
			if(($oldVersion -eq '7.11') -or ($oldVersion -eq '10.10.2')){
				$logger.logInfo("Current Installed Version is $($oldVersion)", $True)
				$logger.logWarning("The Current Upgrade Path is Not Supported", $True)
				$logger.logInfo("Please refer the Upgrade Instruction Documentation for more details", $True)
				Exit
			}
			else{
				PreviousPlatformUpgradeToNew
				$logger.logInfo("You have successfully completed the Automated Upgrade of Network Analytics Server.", $True)
				Exit
			}
		}
	}
	else {
		[int]$installedBuildRelease = $installedBuild.Substring(1,4)
		[int]$newBuildNumberRelease = $newBuildNumber.Substring(1,4)
		[int]$installedBuild = $installedBuild.Substring(6,2)
		[int]$newBuild = $newBuildNumber.Substring(6,2)
	
		if($newBuildNumberRelease -gt $installedBuildRelease) {
			$checkAnalystInstance = $False
			$logger.logInfo("Checking if any Instance of Analyst Client is open...", $True)
			$checkAnalystProcess = Get-Process -Name Spotfire.Dxp -ErrorAction SilentlyContinue
			if($checkAnalystProcess) {
				$checkAnalystInstance = $True
			}
			if($checkAnalystInstance) {
				$logger.logWarning("Instance of Analyst Client is open", $True)
				$logger.logInfo("Please close the Analyst and Re-run the Upgrade. Exiting the script now...", $True)
				Exit
			}
		else {
			$logger.logInfo("No open Instance of Analyst found. Proceeding with Minor Version Upgrade...", $True)
			MinorVersionUpgrade
			$logger.logInfo("You have successfully completed the Automated Minor Version Upgrade of Network Analytics Server.", $True)
			Exit
			}
		}
		elseif(($newBuildNumberRelease -eq $installedBuildRelease) -and ($installedBuild -lt $newBuild)) {
			$checkAnalystInstance = $False
			$logger.logInfo("Checking if any Instance of Analyst Client is open...", $True)
			$checkAnalystProcess = Get-Process -Name Spotfire.Dxp -ErrorAction SilentlyContinue
			if($checkAnalystProcess) {
				$checkAnalystInstance = $True
			}
			if($checkAnalystInstance) {
				$logger.logWarning("Instance of Analyst Client is open", $True)
				$logger.logInfo("Please close the Analyst and Re-run the Upgrade. Exiting the script now...", $True)
				Exit
			}
		else {
			$logger.logInfo("No open Instance of Analyst found. Proceeding with Platform Update...", $True)
			updatePlatformScripts
			$logger.logInfo("You have successfully completed the Platform Script Update of Network Analytics Server.", $True)
			Exit
			}
		}
		else {
			$logger.logWarning("NetAn is Already Upgraded to the latest available version", $True)
			Exit
		}
	}
	else {
		$logger.logError($MyInvocation, "Invalid Upgrade Triggered !!", $True)
		MyExit($MyInvocation.MyCommand)
	}
    

}

Function MainUpgradeAnsible() {
	Set-EnvVariable $installParams.platformPass "NetAnVar"
	$envVariable = "NetAnVar"
	$platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
	if($platformPassword) {
		$logger.logInfo("Environment Variable NetAnVar Updated Successfully!!", $True)
	}
	else {
		$logger.logError($MyInvocation, "Failed to Update Environment Variable NetAnVar", $True)
		MyExit($MyInvocation.MyCommand)
	}
	
    InitiateLogs $upgrade
    SetAutomationFilePermission

    $platformReleaseXml = Get-Item "$($installParams.platformVersionDir)\platform-utilities-release.*xml"
	if(-not $platformReleaseXml) {
		$logger.logError($MyInvocation, "The platform-utilities-release.xml was not detected in media. Media is not complete", $True)
		MyExit($MyInvocation.MyCommand)
	}

#are there more than one platform-utilities-release files
	if($platformReleaseXml.Count -gt 1) {
		$logger.logError($MyInvocation, "There are duplicate plaform-release.xml files detected. Media is not correct", $True)
		MyExit($MyInvocation.MyCommand)
	}

#does it contain a build/rstate
	$newBuildNumber = ($platformReleaseXml.Name).Split('.')[-2]

	if(-not ($newBuildNumber -Match "^R")) {
		$logger.logError($MyInvocation, "The platform-utilities-release.xml file is not named correctly. It does not contain a valid Build number", $True)
		MyExit($MyInvocation.MyCommand)
	}
	$envVar = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable "NetAnVar")).GetNetworkCredential().Password
	$platformDetails = Get-PlatformVersionsFromDB $envVar
	if(-not $platformDetails[0]) {
		$logger.logError($MyInvocation, $platformDetails[1])
		$logger.logError($MyInvocation, "An error has occured in upgrade. Please refer to the upgrade log. Exiting upgrade", $True)
		MyExit($MyInvocation.MyCommand)
	}

	$installedPlatformRecord = Get-PlatformVersions | Where-Object -FilterScript { $_.'PRODUCT-ID'.trim() -eq 'CNA4032940' }
	$installedBuild = ($installedPlatformRecord).BUILD
	$Script:instBuild=$installedBuild
	
	if(($installedPlatformRecord | Measure-Object).Count -eq 0) {
		$logger.logWarning("Aborting upgrade. Please Perform Initial Install of NetAn", $True)
		Exit
	}

	if(($installedPlatformRecord | Measure-Object).Count -gt 1) {
		$logger.logWarning("Aborting upgrade. netAnserver_repdb is inconsistent. There are multiple versions of the platform installed", $True)
		Exit
	}
	$installedPlatformRecord = Get-PlatformVersions | Where-Object -FilterScript { $_.'PRODUCT-ID'.trim() -eq 'CNA4032940' }
	$installedBuild = $installedPlatformRecord.build
	$installedBuild = $installedBuild.trim()
	if(($installedBuild.Substring(1,2))[1] -match '\d') {
		[int]$installedBuildRelease = $installedBuild.Substring(1,2)
	}
	else {
		[int]$installedBuildRelease = (($installedBuild.Substring(1,2))[0].toString())
	}

	$newBuildNumber = ($platformReleaseXml.Name).Split('.')[-2]
	[int]$newBuildNumberRelease = $newBuildNumber.Substring(1,2)
	$logger.logInfo("Installed Build :: $($installedBuild)", $True)
	$logger.logInfo("New Build :: $($newBuildNumber)", $True)
	

	if($newBuildNumberRelease -gt $installedBuildRelease) {
		$checkAnalystInstance = $False
		$logger.logInfo("Checking if any Instance of Analyst Client is open...", $True)
		$checkAnalystProcess = Get-Process -Name Spotfire.Dxp -ErrorAction SilentlyContinue
		if($checkAnalystProcess) {
			$checkAnalystInstance = $True
		}
		if($checkAnalystInstance) {
			$logger.logWarning("Instance of Analyst Client is open", $True)
			$logger.logInfo("Please close the Analyst and Re-run the Upgrade. Exiting the script now...", $True)
			Exit
		}
		else {
			$logger.logInfo("No open Instance of Analyst found. Proceeding with Major Upgrade...", $True)
			if(($oldVersion -eq '7.11') -or ($oldVersion -eq '10.10.2')){
				$logger.logInfo("Current Installed Version is $($oldVersion)", $True)
				$logger.logWarning("The Current Upgrade Path is Not Supported", $True)
				$logger.logInfo("Please refer the Upgrade Instruction Documentation for more details", $True)
				Exit
			}
			else{
				PreviousPlatformUpgradeToNew_Ansible
				$logger.logInfo("You have successfully completed the Automated Upgrade of Network Analytics Server through Deployment Tool.", $True)
				Exit
			}
		}
	}
	else {
		[int]$installedBuildRelease = $installedBuild.Substring(1,4)
		[int]$newBuildNumberRelease = $newBuildNumber.Substring(1,4)
		[int]$installedBuild = $installedBuild.Substring(6,2)
		[int]$newBuild = $newBuildNumber.Substring(6,2)
	
		if($newBuildNumberRelease -gt $installedBuildRelease) {
			$checkAnalystInstance = $False
			$logger.logInfo("Checking if any Instance of Analyst Client is open...", $True)
			$checkAnalystProcess = Get-Process -Name Spotfire.Dxp -ErrorAction SilentlyContinue
			if($checkAnalystProcess) {
				$checkAnalystInstance = $True
			}
			if($checkAnalystInstance) {
				$logger.logWarning("Instance of Analyst Client is open", $True)
				$logger.logInfo("Please close the Analyst and Re-run the Upgrade. Exiting the script now...", $True)
				Exit
			}
		else {
			$logger.logInfo("No open Instance of Analyst found. Proceeding with Minor Version Upgrade...", $True)
			MinorVersionUpgrade_Ansible
			$logger.logInfo("You have successfully completed the Automated Minor Version Upgrade of Network Analytics Server through Deployment Tool.", $True)
			Exit
			}
		}
		elseif(($newBuildNumberRelease -eq $installedBuildRelease) -and ($installedBuild -lt $newBuild)) {
			$checkAnalystInstance = $False
			$logger.logInfo("Checking if any Instance of Analyst Client is open...", $True)
			$checkAnalystProcess = Get-Process -Name Spotfire.Dxp -ErrorAction SilentlyContinue
			if($checkAnalystProcess) {
				$checkAnalystInstance = $True
			}
			if($checkAnalystInstance) {
				$logger.logWarning("Instance of Analyst Client is open", $True)
				$logger.logInfo("Please close the Analyst and Re-run the Upgrade. Exiting the script now...", $True)
				Exit
			}
		else {
			$logger.logInfo("No open Instance of Analyst found. Proceeding with Platform Update...", $True)
			updatePlatformScripts_Ansible
			$logger.logInfo("You have successfully completed the Platform Script Update of Network Analytics Server through Deployment Tool.", $True)
			Exit
			}
		}
		else {
			$logger.logWarning("NetAn is Already Upgraded to the latest available version.", $True)
			Exit
		}
	}
	else {
		$logger.logError($MyInvocation, "Invalid Upgrade Triggered !!", $True)
		MyExit($MyInvocation.MyCommand)
	}
    

}

Function PreviousPlatformUpgradeToNew_711(){
    $Script:major=$TRUE
    InputParametersUpgrade
    $stageFile = $installParams.upgradeStage
	if(-not(Test-Path $installParams.runtimeStage)) {
        $logger.logError($MyInvocation, "Runtime Stage File Not Found :: $($installParams.runtimeStage)", $True)
		Exit
	}
	$logger.logInfo("Checking if Upgrade Stage File is present", $True)
	if(Test-Path $installParams.upgradeStage) {
		$logger.logInfo("Upgrade Stage File Found", $True)
		$logger.logInfo("Reading Last Executed Stage from Stage File", $True)
		$lastexecutedStage = Get-Content $installParams.upgradeStage  -tail 1
		if($lastexecutedStage -eq ""){
			$logger.logInfo("Invalid entry found in Upgrade Stage File", $True)
			$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
			Remove-Item $installParams.upgradeStage| Out-Null
			Out-File -FilePath $installParams.upgradeStage
			$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
			$startFromBeginingFlag = $True
		}
		else {
			$logger.logInfo("Last Executed Stage found in Upgrade Stage File :: "+$lastexecutedStage, $True)
			$confirmation = ''
			while(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
				$confirmation = $(Write-Host "`n`nPlease Enter "-NoNewline; write-host -fore Yellow ("y")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Continue")-NoNewline;write-host(" from ")-NoNewline;write-host -fore Yellow ("$($lastexecutedStage) Stage")-NoNewline;write-host(" or Enter ")-NoNewline;write-host -fore Yellow ("n")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Start Over`n"); Read-Host)
				if(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
					customWrite-host "`nInvalid Confirmation Input Provided!! Please Re-Enter ..."
				}
			}
			if($confirmation -eq 'y') {
				$logger.logInfo("Confirmation provided to continue from "+$lastexecutedStage, $True)
				$logger.logInfo("Process will continue from "+$lastexecutedStage, $True)
				$startFromBeginingFlag = $False
			}
			else {
				$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
				Remove-Item $installParams.upgradeStage| Out-Null
				Out-File -FilePath $installParams.upgradeStage
				$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
				$startFromBeginingFlag = $True
			}
		}
		
	}
	else{
		$logger.logInfo("Upgrade Stage File Not Found", $True)
		$logger.logInfo("Process will begin from Start", $True)
		$logger.logInfo("Creating Upgrade Stage File", $True)
		Out-File -FilePath $installParams.upgradeStage
		$logger.logInfo("Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
		$startFromBeginingFlag = $True
	}
	[xml]$xmlObj = Get-Content $installParams.runtimeStage
	$install_stage = $xmlObj.SelectNodes("//PreviousPlatformUpgradeToNew_711")
	foreach ($stage in $install_stage)
	{
		$stages = $stage.'stages'
	}
	$runtimeList = $stages.Split(",")
	$start = 0
	if($startFromBeginingFlag -eq $False) {
		for ($start = 0; $start -lt $runtimeList.Count; $start++)
		{
			if($runtimeList[$start].contains($lastexecutedStage)){
				Break
			}
		}
	}	
	for ($continue = $start; $continue -lt $runtimeList.Count; $continue++)
	{
		if($runtimeList[$continue].contains(" ")){
			$splitString = $runtimeList[$continue].split(" ")
			$var = Invoke-Expression($splitString[1])
			&$splitString[0] $var
			
		}
		else{
			&$runtimeList[$continue]
		}
	}

}

Function PreviousPlatformUpgradeToNew(){
    InputParametersUpgrade
	DisableSSO
    $stageFile = $installParams.upgradeStage
	if(-not(Test-Path $installParams.runtimeStage)) {
        $logger.logError($MyInvocation, "Runtime Stage File Not Found :: $($installParams.runtimeStage)", $True)
		Exit
	}
	$logger.logInfo("Checking if Upgrade Stage File is present", $True)
	if(Test-Path $installParams.upgradeStage) {
		$logger.logInfo("Upgrade Stage File Found", $True)
		$logger.logInfo("Reading Last Executed Stage from Stage File", $True)
		$lastexecutedStage = Get-Content $installParams.upgradeStage  -tail 1
		if($lastexecutedStage -eq ""){
			$logger.logInfo("Invalid entry found in Upgrade Stage File", $True)
			$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
			Remove-Item $installParams.upgradeStage| Out-Null
			Out-File -FilePath $installParams.upgradeStage
			$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
			$startFromBeginingFlag = $True
		}
		else {
			$logger.logInfo("Last Executed Stage found in Upgrade Stage File :: "+$lastexecutedStage, $True)
			$confirmation = ''
			while(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
				$confirmation = $(Write-Host "`n`nPlease Enter "-NoNewline; write-host -fore Yellow ("y")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Continue")-NoNewline;write-host(" from ")-NoNewline;write-host -fore Yellow ("$($lastexecutedStage) Stage")-NoNewline;write-host(" or Enter ")-NoNewline;write-host -fore Yellow ("n")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Start Over`n"); Read-Host)
				if(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
					customWrite-host "`nInvalid Confirmation Input Provided!! Please Re-Enter ..."
				}
			}
			if($confirmation -eq 'y') {
				$logger.logInfo("Confirmation provided to continue from "+$lastexecutedStage, $True)
				$logger.logInfo("Process will continue from "+$lastexecutedStage, $True)
				$startFromBeginingFlag = $False
			}
			else {
				$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
				Remove-Item $installParams.upgradeStage| Out-Null
				Out-File -FilePath $installParams.upgradeStage
				$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
				$startFromBeginingFlag = $True
			}
		}
		
	}
	else{
		$logger.logInfo("Upgrade Stage File Not Found", $True)
		$logger.logInfo("Process will begin from Start", $True)
		$logger.logInfo("Creating Upgrade Stage File", $True)
		Out-File -FilePath $installParams.upgradeStage
		$logger.logInfo("Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
		$startFromBeginingFlag = $True
	}
	[xml]$xmlObj = Get-Content $installParams.runtimeStage
	$install_stage = $xmlObj.SelectNodes("//PreviousPlatformUpgradeToNew")
	foreach ($stage in $install_stage)
	{
		$stages = $stage.'stages'
	}
	$runtimeList = $stages.Split(",")
	$start = 0
	if($startFromBeginingFlag -eq $False) {
		for ($start = 0; $start -lt $runtimeList.Count; $start++)
		{
			if($runtimeList[$start].contains($lastexecutedStage)){
				Break
			}
		}
	}	
	for ($continue = $start; $continue -lt $runtimeList.Count; $continue++)
	{
		if($runtimeList[$continue].contains(" ")){
			$splitString = $runtimeList[$continue].split(" ")
			$var = Invoke-Expression($splitString[1])
			&$splitString[0] $var
			
		}
		else{
			&$runtimeList[$continue]
		}
	}
}

Function PreviousPlatformUpgradeToNew_Ansible(){
    InputParametersUpgrade_Ansible
	DisableSSO
    $stageFile = $installParams.upgradeStage
	if(-not(Test-Path $installParams.runtimeStage)) {
        $logger.logError($MyInvocation, "Runtime Stage File Not Found :: $($installParams.runtimeStage)", $True)
		Exit
	}
	$logger.logInfo("Checking if Upgrade Stage File is present", $True)
	if(Test-Path $installParams.upgradeStage) {
		$logger.logInfo("Upgrade Stage File Found", $True)
		$logger.logInfo("Reading Last Executed Stage from Stage File", $True)
		$lastexecutedStage = Get-Content $installParams.upgradeStage  -tail 1
		if($lastexecutedStage -eq ""){
			$logger.logInfo("Invalid entry found in Upgrade Stage File", $True)
			$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
			Remove-Item $installParams.upgradeStage| Out-Null
			Out-File -FilePath $installParams.upgradeStage
			$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
			$startFromBeginingFlag = $True
		}
		else {
			$logger.logInfo("Last Executed Stage found in Upgrade Stage File :: "+$lastexecutedStage, $True)
			$confirmation = $installParams.resumeConfirmation

			if($confirmation -eq 'y') {
				$logger.logInfo("Confirmation provided to continue from "+$lastexecutedStage, $True)
				$logger.logInfo("Process will continue from "+$lastexecutedStage, $True)
				$startFromBeginingFlag = $False
			}
			else {
				$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
				Remove-Item $installParams.upgradeStage| Out-Null
				Out-File -FilePath $installParams.upgradeStage
				$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
				$startFromBeginingFlag = $True
			}
		}
		
	}
	else{
		$logger.logInfo("Upgrade Stage File Not Found", $True)
		$logger.logInfo("Process will begin from Start", $True)
		$logger.logInfo("Creating Upgrade Stage File", $True)
		Out-File -FilePath $installParams.upgradeStage
		$logger.logInfo("Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
		$startFromBeginingFlag = $True
	}
	[xml]$xmlObj = Get-Content $installParams.runtimeStage
	$install_stage = $xmlObj.SelectNodes("//PreviousPlatformUpgradeToNewAnsible")
	foreach ($stage in $install_stage)
	{
		$stages = $stage.'stages'
	}
	$runtimeList = $stages.Split(",")
	$start = 0
	if($startFromBeginingFlag -eq $False) {
		for ($start = 0; $start -lt $runtimeList.Count; $start++)
		{
			if($runtimeList[$start].contains($lastexecutedStage)){
				Break
			}
		}
	}	
	for ($continue = $start; $continue -lt $runtimeList.Count; $continue++)
	{
		if($runtimeList[$continue].contains(" ")){
			$splitString = $runtimeList[$continue].split(" ")
			$var = Invoke-Expression($splitString[1])
			&$splitString[0] $var
			
		}
		else{
			&$runtimeList[$continue]
		}
	}
}

Function MinorVersionUpgrade(){
    getInputParamsForMinorVersionUpgrade
	DisableSSO
	#DecryptNetAnServerMediaAnsible
    $stageFile = $installParams.upgradeStage
	if(-not(Test-Path $installParams.runtimeStage)) {
        $logger.logError($MyInvocation, "Runtime Stage File Not Found :: $($installParams.runtimeStage)", $True)
		Exit
	}
	$logger.logInfo("Checking if Upgrade Stage File is present", $True)
	if(Test-Path $installParams.upgradeStage) {
		$logger.logInfo("Upgrade Stage File Found", $True)
		$logger.logInfo("Reading Last Executed Stage from Stage File", $True)
		$lastexecutedStage = Get-Content $installParams.upgradeStage  -tail 1
		if($lastexecutedStage -eq ""){
			$logger.logInfo("Invalid entry found in Upgrade Stage File", $True)
			$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
			Remove-Item $installParams.upgradeStage| Out-Null
			Out-File -FilePath $installParams.upgradeStage
			$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
			$startFromBeginingFlag = $True
		}
		else {
			$logger.logInfo("Last Executed Stage found in Upgrade Stage File :: "+$lastexecutedStage, $True)
			$confirmation = ''
			while(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
				$confirmation = $(Write-Host "`n`nPlease Enter "-NoNewline; write-host -fore Yellow ("y")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Continue")-NoNewline;write-host(" from ")-NoNewline;write-host -fore Yellow ("$($lastexecutedStage) Stage")-NoNewline;write-host(" or Enter ")-NoNewline;write-host -fore Yellow ("n")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Start Over`n"); Read-Host)
				if(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
					customWrite-host "`nInvalid Confirmation Input Provided!! Please Re-Enter ..."
				}
			}
			if($confirmation -eq 'y') {
				$logger.logInfo("Confirmation provided to continue from "+$lastexecutedStage, $True)
				$logger.logInfo("Process will continue from "+$lastexecutedStage, $True)
				$startFromBeginingFlag = $False
			}
			else {
				$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
				Remove-Item $installParams.upgradeStage| Out-Null
				Out-File -FilePath $installParams.upgradeStage
				$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
				$startFromBeginingFlag = $True
			}
		}
		
	}
	else{
		$logger.logInfo("Upgrade Stage File Not Found", $True)
		$logger.logInfo("Process will begin from Start", $True)
		$logger.logInfo("Creating Upgrade Stage File", $True)
		Out-File -FilePath $installParams.upgradeStage
		$logger.logInfo("Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
		$startFromBeginingFlag = $True
	}
	[xml]$xmlObj = Get-Content $installParams.runtimeStage
	$install_stage = $xmlObj.SelectNodes("//MinorVersionUpgrade")
	foreach ($stage in $install_stage)
	{
		$stages = $stage.'stages'
	}
	$runtimeList = $stages.Split(",")
	$start = 0
	if($startFromBeginingFlag -eq $False) {
		for ($start = 0; $start -lt $runtimeList.Count; $start++)
		{
			if($runtimeList[$start].contains($lastexecutedStage)){
				Break
			}
		}
	}	
	for ($continue = $start; $continue -lt $runtimeList.Count; $continue++)
	{
		if($runtimeList[$continue].contains(" ")){
			$splitString = $runtimeList[$continue].split(" ")
			$var = Invoke-Expression($splitString[1])
			&$splitString[0] $var
			
		}
		else{
			&$runtimeList[$continue]
		}
	}

}

Function MinorVersionUpgrade_Ansible(){
    getInputParamsForMinorVersionUpgrade_Ansible
	DisableSSO
    $stageFile = $installParams.upgradeStage
	if(-not(Test-Path $installParams.runtimeStage)) {
        $logger.logError($MyInvocation, "Runtime Stage File Not Found :: $($installParams.runtimeStage)", $True)
		Exit
	}
	$logger.logInfo("Checking if Upgrade Stage File is present", $True)
	if(Test-Path $installParams.upgradeStage) {
		$logger.logInfo("Upgrade Stage File Found", $True)
		$logger.logInfo("Reading Last Executed Stage from Stage File", $True)
		$lastexecutedStage = Get-Content $installParams.upgradeStage  -tail 1
		if($lastexecutedStage -eq ""){
			$logger.logInfo("Invalid entry found in Upgrade Stage File", $True)
			$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
			Remove-Item $installParams.upgradeStage| Out-Null
			Out-File -FilePath $installParams.upgradeStage
			$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
			$startFromBeginingFlag = $True
		}
		else {
			$logger.logInfo("Last Executed Stage found in Upgrade Stage File :: "+$lastexecutedStage, $True)
			$confirmation = $installParams.resumeConfirmation
			if($confirmation -eq 'y') {
				$logger.logInfo("Confirmation provided to continue from "+$lastexecutedStage, $True)
				$logger.logInfo("Process will continue from "+$lastexecutedStage, $True)
				$startFromBeginingFlag = $False
			}
			else {
				$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
				Remove-Item $installParams.upgradeStage| Out-Null
				Out-File -FilePath $installParams.upgradeStage
				$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
				$startFromBeginingFlag = $True
			}
		}
		
	}
	else{
		$logger.logInfo("Upgrade Stage File Not Found", $True)
		$logger.logInfo("Process will begin from Start", $True)
		$logger.logInfo("Creating Upgrade Stage File", $True)
		Out-File -FilePath $installParams.upgradeStage
		$logger.logInfo("Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
		$startFromBeginingFlag = $True
	}
	[xml]$xmlObj = Get-Content $installParams.runtimeStage
	$install_stage = $xmlObj.SelectNodes("//MinorVersionUpgradeAnsible")
	foreach ($stage in $install_stage)
	{
		$stages = $stage.'stages'
	}
	$runtimeList = $stages.Split(",")
	$start = 0
	if($startFromBeginingFlag -eq $False) {
		for ($start = 0; $start -lt $runtimeList.Count; $start++)
		{
			if($runtimeList[$start].contains($lastexecutedStage)){
				Break
			}
		}
	}	
	for ($continue = $start; $continue -lt $runtimeList.Count; $continue++)
	{
		if($runtimeList[$continue].contains(" ")){
			$splitString = $runtimeList[$continue].split(" ")
			$var = Invoke-Expression($splitString[1])
			&$splitString[0] $var
			
		}
		else{
			&$runtimeList[$continue]
		}
	}

}

Function updatePlatformScripts(){
    getInputParamsForPlatformScriptsUpdate
    $stageFile = $installParams.upgradeStage
	if(-not(Test-Path $installParams.runtimeStage)) {
        $logger.logError($MyInvocation, "Runtime Stage File Not Found :: $($installParams.runtimeStage)", $True)
		Exit
	}
	$logger.logInfo("Checking if Upgrade Stage File is present", $True)
	if(Test-Path $installParams.upgradeStage) {
		$logger.logInfo("Upgrade Stage File Found", $True)
		$logger.logInfo("Reading Last Executed Stage from Stage File", $True)
		$lastexecutedStage = Get-Content $installParams.upgradeStage  -tail 1
		if($lastexecutedStage -eq ""){
			$logger.logInfo("Invalid entry found in Upgrade Stage File", $True)
			$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
			Remove-Item $installParams.upgradeStage| Out-Null
			Out-File -FilePath $installParams.upgradeStage
			$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
			$startFromBeginingFlag = $True
		}
		else {
			$logger.logInfo("Last Executed Stage found in Upgrade Stage File :: "+$lastexecutedStage, $True)
			$confirmation = ''
			while(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
				$confirmation = $(Write-Host "`n`nPlease Enter "-NoNewline; write-host -fore Yellow ("y")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Continue")-NoNewline;write-host(" from ")-NoNewline;write-host -fore Yellow ("$($lastexecutedStage) Stage")-NoNewline;write-host(" or Enter ")-NoNewline;write-host -fore Yellow ("n")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Start Over`n"); Read-Host)
				if(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
					customWrite-host "`nInvalid Confirmation Input Provided!! Please Re-Enter ..."
				}
			}
			if($confirmation -eq 'y') {
				$logger.logInfo("Confirmation provided to continue from "+$lastexecutedStage, $True)
				$logger.logInfo("Process will continue from "+$lastexecutedStage, $True)
				$startFromBeginingFlag = $False
			}
			else {
				$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
				Remove-Item $installParams.upgradeStage| Out-Null
				Out-File -FilePath $installParams.upgradeStage
				$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
				$startFromBeginingFlag = $True
			}
		}
		
	}
	else{
		$logger.logInfo("Upgrade Stage File Not Found", $True)
		$logger.logInfo("Process will begin from Start", $True)
		$logger.logInfo("Creating Upgrade Stage File", $True)
		Out-File -FilePath $installParams.upgradeStage
		$logger.logInfo("Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
		$startFromBeginingFlag = $True
	}
	[xml]$xmlObj = Get-Content $installParams.runtimeStage
	$install_stage = $xmlObj.SelectNodes("//PlatformScriptUpdate")
	foreach ($stage in $install_stage)
	{
		$stages = $stage.'stages'
	}
	$runtimeList = $stages.Split(",")
	$start = 0
	if($startFromBeginingFlag -eq $False) {
		for ($start = 0; $start -lt $runtimeList.Count; $start++)
		{
			if($runtimeList[$start].contains($lastexecutedStage)){
				Break
			}
		}
	}	
	for ($continue = $start; $continue -lt $runtimeList.Count; $continue++)
	{
		if($runtimeList[$continue].contains(" ")){
			$splitString = $runtimeList[$continue].split(" ")
			$var = Invoke-Expression($splitString[1])
			&$splitString[0] $var
			
		}
		else{
			&$runtimeList[$continue]
		}
	}
}

Function updatePlatformScripts_Ansible(){
    getInputParamsForPlatformScriptsUpdate_Ansible
    $stageFile = $installParams.upgradeStage
	if(-not(Test-Path $installParams.runtimeStage)) {
        $logger.logError($MyInvocation, "Runtime Stage File Not Found :: $($installParams.runtimeStage)", $True)
		Exit
	}
	$logger.logInfo("Checking if Upgrade Stage File is present", $True)
	if(Test-Path $installParams.upgradeStage) {
		$logger.logInfo("Upgrade Stage File Found", $True)
		$logger.logInfo("Reading Last Executed Stage from Stage File", $True)
		$lastexecutedStage = Get-Content $installParams.upgradeStage  -tail 1
		if($lastexecutedStage -eq ""){
			$logger.logInfo("Invalid entry found in Upgrade Stage File", $True)
			$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
			Remove-Item $installParams.upgradeStage| Out-Null
			Out-File -FilePath $installParams.upgradeStage
			$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
			$startFromBeginingFlag = $True
		}
		else {
			$logger.logInfo("Last Executed Stage found in Upgrade Stage File :: "+$lastexecutedStage, $True)
			$confirmation = $installParams.resumeConfirmation
			if($confirmation -eq 'y') {
				$logger.logInfo("Confirmation provided to continue from "+$lastexecutedStage, $True)
				$logger.logInfo("Process will continue from "+$lastexecutedStage, $True)
				$startFromBeginingFlag = $False
			}
			else {
				$logger.logInfo("Upgrade Stage File will be removed and Process will begin from Start", $True)
				Remove-Item $installParams.upgradeStage| Out-Null
				Out-File -FilePath $installParams.upgradeStage
				$logger.logInfo("New Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
				$startFromBeginingFlag = $True
			}
		}
		
	}
	else{
		$logger.logInfo("Upgrade Stage File Not Found", $True)
		$logger.logInfo("Process will begin from Start", $True)
		$logger.logInfo("Creating Upgrade Stage File", $True)
		Out-File -FilePath $installParams.upgradeStage
		$logger.logInfo("Upgrade Stage File Created :: $($installParams.upgradeStage)", $True)
		$startFromBeginingFlag = $True
	}
	[xml]$xmlObj = Get-Content $installParams.runtimeStage
	$install_stage = $xmlObj.SelectNodes("//PlatformScriptUpdateAnsible")
	foreach ($stage in $install_stage)
	{
		$stages = $stage.'stages'
	}
	$runtimeList = $stages.Split(",")
	$start = 0
	if($startFromBeginingFlag -eq $False) {
		for ($start = 0; $start -lt $runtimeList.Count; $start++)
		{
			if($runtimeList[$start].contains($lastexecutedStage)){
				Break
			}
		}
	}	
	for ($continue = $start; $continue -lt $runtimeList.Count; $continue++)
	{
		if($runtimeList[$continue].contains(" ")){
			$splitString = $runtimeList[$continue].split(" ")
			$var = Invoke-Expression($splitString[1])
			&$splitString[0] $var
			
		}
		else{
			&$runtimeList[$continue]
		}
	}
}

#----------------------------------------------------------------------------------
#  Create Log file directory structure
#----------------------------------------------------------------------------------
Function InitiateLogs($message) {

    $creationMessage = $null
	$installParams.Add('installReason', $message)

    if ( -not (Test-FileExists($installParams.logDir))) {
        New-Item $installParams.logDir -ItemType directory | Out-Null
        $creationMessage = "Creating new log directory $($installParams.logDir)"
    }

    $logger.setLogDirectory($installParams.logDir)
	if($installParams.installReason -eq 'Upgrade') {
		$logger.setLogName('NetAnServer_Upgrade.log')
	}
	else {
		$logger.setLogName('NetAnServer_Install.log')
	}

    $logger.logInfo("Starting the $message of Ericsson Network Analytics Server.", $True)

    if ($creationMessage) {
        $logger.logInfo($creationMessage, $true)
    }
	
	if($installParams.installReason -eq 'Upgrade') {
		$logger.logInfo("$message log created $($installParams.logDir)\$($logger.timestamp)_NetAnServer_Upgrade.log", $True)
	}
	else {
		$logger.logInfo("$message log created $($installParams.logDir)\$($logger.timestamp)_NetAnServer_Install.log", $True)
	}

    Set-Location $loc
}


#----------------------------------------------------------------------------------
#  Change Automation services configuration file permission
#----------------------------------------------------------------------------------
Function SetAutomationFilePermission() {

    $file = $installParams.automationServicesDir + "\*.config"
   Get-ChildItem -Path $file  | Where-Object {$_.IsReadOnly} |
   ForEach-Object{
      try {
          $_.IsReadOnly = $false
          }
      catch {
            $errorMessage = $_.Exception.Message
            $logger.logError($MyInvocation, "Could not Set Permission for $installParams.automationServicesDir . `n $errorMessage", $True)
            }
    }
}

Function DecryptNetAnServerMedia(){
	stageEnter($MyInvocation.MyCommand)
	$NetAnServerISO = $installParams.NetAnServerISO
	$isoFilePath = "C:/temp/media/netanserver/$NetAnServerISO.iso"
	$mounted = Get-DiskImage -ImagePath $isoFilePath | ForEach-Object { $_.Attached }
	if ($mounted) {
		# If it's already mounted, unmount it
		Dismount-DiskImage -ImagePath $isoFilePath
	}
	$directoryPath = "C:\Ericsson\tmp\CompressedFiles"
	# Check if the directory exists
	if (Test-Path $directoryPath -PathType Container) {
		# Get all files in the directory
		$files = Get-ChildItem $directoryPath -File -Recurse
    
		foreach ($file in $files) {
			try {
				# Attempt to delete the file, ignoring any errors if it's in use
				Remove-Item $file.FullName -Force -ErrorAction Stop
			} catch {
				$logger.logError($MyInvocation, "Error deleting file '$($file.FullName)': $_", $True)
				MyExit($MyInvocation.MyCommand)
			}
		}
		# Delete the empty directory itself
		Remove-Item $directoryPath -Force -Recurse
	}
	$directoryPath = "C:\Ericsson\tmp\Modules"
	# Check if the directory exists
	if (Test-Path $directoryPath -PathType Container) {
		# Get all files in the directory
		$files = Get-ChildItem $directoryPath -File -Recurse
    
		foreach ($file in $files) {
			try {
				# Attempt to delete the file, ignoring any errors if it's in use
				Remove-Item $file.FullName -Force -ErrorAction Stop
			} catch {
				$logger.logError($MyInvocation, "Error deleting file '$($file.FullName)': $_", $True)
				MyExit($MyInvocation.MyCommand)
			}
		}
		# Delete the empty directory itself
		Remove-Item $directoryPath -Force -Recurse
	}
	$logger.logInfo("Started Automated Server Media Decryption",$True)
	$logger.logInfo("Preparing to Mount and Decrypt NetAn Server ISO :: $($installParams.NetAnServerISO)",$True)
	$NetAnServerISO = $installParams.NetAnServerISO
	$mountResult = Mount-DiskImage C:/temp/media/netanserver/$NetAnServerISO.iso -PassThru
	$driveLetter = ($mountResult | Get-Volume).DriveLetter
	$driveLetter = $driveLetter + ':'
	if(!($driveLetter)) {
		$logger.logError($MyInvocation, "Unable to Mount $($installParams.NetAnServerISO)", $True)
		MyExit($MyInvocation.MyCommand)
	}
	$logger.logInfo("NetAn Server ISO Media Mounted Successfully on $($driveLetter) Drive", $True)
	
	$logger.logInfo("Decryption Process Started", $True)
	$currLocation = Get-Location
	
	$loc = $installParams.decryptNetAn
	Set-Location $loc
	. $loc\NetAnServer.ps1 $driveLetter
	
	if(test-path($installParams.mediaDir)){
		$directoryInfo = Get-ChildItem $installParams.mediaDir | Measure-Object
		if($directoryInfo.count -lt 5) {
			$logger.logError($MyInvocation, "Unable to Decrypt NetAn Server Media", $True)
			DisMount-DiskImage C:/temp/media/netanserver/$NetAnServerISO.iso
			Set-Location $currLocation
			MyExit($MyInvocation.MyCommand)
		}
	}
	else{
		$logger.logError($MyInvocation, "Media Decryption Unsuccessful. $($installParams.mediaDir) not found", $True)
		DisMount-DiskImage C:/temp/media/netanserver/$NetAnServerISO.iso
		Set-Location $currLocation
		MyExit($MyInvocation.MyCommand)
	}
	
	$logger.logInfo("Successfully Decrypted NetAn Server Media", $True)
	DisMount-DiskImage C:/temp/media/netanserver/$NetAnServerISO.iso
	$logger.logInfo("Successfully Unmounted the NetAn Server Media ISO File", $True)
	Set-Location $currLocation
	
	stageExit($MyInvocation.MyCommand)
}

Function FQDNSwitch() {
	stageEnter($MyInvocation.MyCommand)
	$envVariable = "NetAnVar"
	$password = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
	$installParams.Add('configPassword', $password)
	$currLocation = Get-Location
	$currentFQDN = CurrentFQDNCheck
	if(!($currentFQDN)) {
		$logger.logWarning("Could not determine Current FQDN Configured on Server", $True)
		$logger.logWarning("Could not Switch FQDN !!", $True)
	}
	else {
		$logger.logInfo("Server is currently configured on $($currentFQDN)", $True)
		if($currentFQDN -eq $installParams.hostAndDomain)
		{
			$logger.logInfo("Server is Already Configured to the Same Primary FQDN $($installParams.hostAndDomain)", $True)
			$logger.logInfo("Further Steps of FQDN Switch will be Skipped !!", $True)
		}
		else {
			$logger.logInfo("Proceeding to Switch FQDN", $True)
			StopNetAn $installParams.nodeServiceNameOld
			StopNetAn $installParams.serviceNetAnServerOld
			 
			ChangeServerConfig
			StartServer_Old
			StartNodeManager_Old
			$logger.logInfo("This procedure will take upto 3 minutes to complete. Please wait...", $True)
			Start-Sleep -s 180
			$logger.logInfo("FQDN Switched From $($currentFQDN) to $($installParams.hostAndDomain)", $True)
		}
	}
	Set-Location $currLocation
	stageExit($MyInvocation.MyCommand)
}

Function FQDNCheckandSwitch() {
	stageEnter($MyInvocation.MyCommand)
	$envVariable = "NetAnVar"
	$password = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
	$installParams.Add('configPassword', $password)
	$currLocation = Get-Location
	$currentFQDN = FQDNCheck
	if(!($currentFQDN)) {
		$logger.logWarning("Could not determine Current FQDN Configured on Server", $True)
		$logger.logWarning("Could not Switch FQDN !!", $True)
	}
	else {
		$logger.logInfo("Server is currently configured on $($currentFQDN)", $True)
		if($currentFQDN -eq $installParams.hostAndDomain)
		{
			Write-Host("`n")
			$logger.logInfo("Server is Already Configured to the Same Primary FQDN $($installParams.hostAndDomain)", $True)
			$logger.logInfo("Further Steps of FQDN Switch will be Skipped", $True)
		}
		else {
			$logger.logInfo("Proceeding to Switch FQDN", $True)
			$TSSVersion = $installParams.serviceNetAnServer
			StopNetAn $TSSVersion
			ServerConfigChange
			StartServerII
			$logger.logInfo("This procedure will take upto 3 minutes to complete. Please wait...", $True)
			Start-Sleep -s 180
			$logger.logInfo("FQDN Switched From $($currentFQDN) to $($installParams.hostAndDomain)", $True)
		}
	}
	Set-Location $currLocation
	stageExit($MyInvocation.MyCommand)
}

Function CurrentFQDNCheck() {
	$TSSPath = $installParams.TSSPath
	$TSNMKeyStorePath = $installParams.TSNMKeyStorePath
	$TSNMPath = $installParams.TSNMPath
	set-Location -Path $TSSPath
	$temp = .\config list-addresses -t $installParams.configPassword
	Add-Content -Path Temp.txt -Value $temp
	(Get-Content -Path Temp.txt).Trim() -ne '' | Set-Content Temp.txt
	$lengthOfFile = (Get-Content -Path Temp.txt) | Measure-Object
	if($lengthOfFile.Count -gt 1)
	{
		$temp = Get-Content -Path Temp.txt | Select -Index 3
		Remove-Item 'Temp.txt'
		$installParams.Add('ServerBackupFQDN', $temp)
		Return $temp
	}
	else
	{
		Remove-Item 'Temp.txt'
		$logger.logError($MyInvocation, "Invalid Configuration Password", $True)
		Exit
		
	}
}

Function FQDNCheck() {
	$TSSPath = $installParams.spotfirebin
	set-Location -Path $TSSPath
	$temp = .\config list-addresses -t $installParams.configPassword
	Add-Content -Path Temp.txt -Value $temp
	(Get-Content -Path Temp.txt).Trim() -ne '' | Set-Content Temp.txt
	$lengthOfFile = (Get-Content -Path Temp.txt) | Measure-Object
	if($lengthOfFile.Count -gt 1)
	{
		$temp = Get-Content -Path Temp.txt | Select -Index 3
		Remove-Item 'Temp.txt'
		$installParams.Add('ServerBackupFQDN', $temp)
		Return $temp
	}
	else
	{
		Remove-Item 'Temp.txt'
		$logger.logError($MyInvocation, "Invalid Configuration Password", $True)
		Exit
		
	}
}

Function ChangeServerConfig() {
	$TSSPath = $installParams.TSSPath
	$logger.logInfo("Preparing to Change Server Configuration", $True)
	set-Location -Path $TSSPath
	$temp = .\config list-addresses -t $installParams.configPassword
	Add-Content -Path Temp.txt -Value $temp
	(Get-Content -Path Temp.txt | Select-Object -Skip 3) | Set-Content -Path Temp.txt
	$temp = $installParams.hostAndDomain
	Set-Content -Path Temp.txt -Value (get-content -Path Temp.txt | Select-String -Pattern $temp -NotMatch)
	@($temp) + (Get-Content Temp.txt) | Set-Content Temp.txt
	(Get-Content -Path Temp.txt).Trim() -ne '' | Set-Content Temp.txt
	$lengthOfFile = (Get-Content -Path Temp.txt) | Measure-Object
	if($lengthOfFile.Count -gt 1)
	{
		$File = Get-Content -Path Temp.txt
		$append = ""
		for($i = 0; $i -lt $File.Count; $i++)
		{
			$append = $append + "-A"+"`""+$File[$i]+"`""+" "
		}
		Remove-Item 'Temp.txt'
		$append2 = '.\config set-addresses -t '
		Invoke-Expression ($append2 + $installParams.configPassword + " "+$append)
		$logger.logInfo("Server Configurations Updated !!", $True)
	}
	else
	{
		Remove-Item 'Temp.txt'
		$logger.logError($MyInvocation, "Invalid Configuration Password or Unable to retrieve Host Details", $True)
		Exit
	}
}

Function ServerConfigChange() {
	$TSSPath = $installParams.spotfirebin
	$logger.logInfo("Preparing to Change Server Configuration", $True)
	set-Location -Path $TSSPath
	$temp = .\config list-addresses -t $installParams.configPassword
	Add-Content -Path Temp.txt -Value $temp
	(Get-Content -Path Temp.txt | Select-Object -Skip 3) | Set-Content -Path Temp.txt
	$temp = $installParams.hostAndDomain
	Set-Content -Path Temp.txt -Value (get-content -Path Temp.txt | Select-String -Pattern $temp -NotMatch)
	@($temp) + (Get-Content Temp.txt) | Set-Content Temp.txt
	(Get-Content -Path Temp.txt).Trim() -ne '' | Set-Content Temp.txt
	$lengthOfFile = (Get-Content -Path Temp.txt) | Measure-Object
	if($lengthOfFile.Count -gt 1)
	{
		$File = Get-Content -Path Temp.txt
		$append = ""
		for($i = 0; $i -lt $File.Count; $i++)
		{
			$append = $append + "-A"+"`""+$File[$i]+"`""+" "
		}
		Remove-Item 'Temp.txt'
		$append2 = '.\config set-addresses -t '
		Invoke-Expression ($append2 + $installParams.configPassword + " "+$append)
		$logger.logInfo("Server Configurations Updated !!", $True)
	}
	else
	{
		Remove-Item 'Temp.txt'
		$logger.logError($MyInvocation, "Invalid Configuration Password or Unable to retrieve Host Details", $True)
		Exit
	}
}

Function ChangeNodeConfig() {
	$logger.logInfo("Preparing to Change Node Configuration", $True)
	$TSNMPath = $installParams.TSNMPath
	$check = Testpath $TSNMPath
	if($check -ne $false) {
		$content = Get-Content -Path $TSNMPath
		$newContent = $content -replace $installParams.ServerBackupFQDN, $installParams.hostAndDomain
		$newContent | Set-Content -Path $TSNMPath
		$logger.logInfo("Node Configurations Updated !!", $True)
	}
	else
	{
		$logger.logError($MyInvocation, "Node Manager Properties File Not Found or Path does not exist:: "+$TSNMPath, $True)
		$logger.logError("Script will terminate without any further actions.....")
		stageExit($MyInvocation.MyCommand)
		Exit
	}
}

Function Testpath($path) {
	try
	{
		Test-Path -Path $path -PathType Leaf
		return Test-Path -Path $path -PathType Leaf
	}
	catch{
		$logger.logError($MyInvocation, "File Not Found or Path does not exist::"+$path, $True)
		Exit
	}
}

Function UntrustDeleteNode() {
	$TSSPath = $installParams.TSSPath
	$TSNMKeyStorePath = $installParams.TSNMKeyStorePath
	set-Location -Path $TSSPath
	$logger.logInfo("Preparing to UnTrust and Delete Node", $True)
	$logger.logInfo("Node UnTrusted and Deleted", $True)
	$check = Testpath $TSNMKeyStorePath
	if($check -ne $false) {
		Remove-item $TSNMKeyStorePath
		$logger.logInfo("KeyStore File Removed", $True)
	}
	else
	{
		$logger.logInfo($MyInvocation, "KeyStore File Not Found or Path does not exist:: "+$TSNMKeyStorePath, $True)
	}
}

Function InstallPostgres() {
	stageEnter($MyInvocation.MyCommand)
	
	$currLocation = Get-Location
	Set-Location C:\Ericsson\tmp\Scripts\postgresql
	& .\PostgresInstaller.ps1 $installParams
	Set-Location $currLocation
	
	$PostgreseDetails = Get-Service -Name "*postgresql-x64*" -ErrorAction SilentlyContinue
	if(-not($PostgreseDetails.Length -gt 0)) {
		$logger.logError($MyInvocation, "PostgreSQL is not Installed", $True)
		MyExit($MyInvocation.MyCommand)
	}
	$postgres_service = "postgresql-x64-" +(((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).MajorVersion) | measure -Maximum).Maximum
    # Check that the postgres server is installed and running
    if (Test-ServiceRunning "$($postgres_service)") {
        $logger.logInfo("PostgreSQL installed and running.", $True)
    }
    else {
        $logger.logError($MyInvocation, "PostgreSQL is not running.", $True)
        $logger.logWarning("Please start PostgreSQL and restart the installation.", $True)
        MyExit($MyInvocation.MyCommand)
    }
	stageExit($MyInvocation.MyCommand)
}

Function PMDataBackup() {
	stageEnter($MyInvocation.MyCommand)
	
	$logger.logInfo("Checking if Backup has to be taken for PM Data", $True)
	
	If($installParams.PMDataBackup) {
		$logger.logInfo("PM Data Feature Is Installed", $True)
		$logger.logInfo("Proceeding to take Backup of PM Data", $True)
		$status = BackupPMData($installParams)
	
		if(-not $status) {
			$logger.logError($MyInvocation, "Could Not Take Backup of PM Data", $True)
			MyExit($MyInvocation.MyCommand)
		}
	}
	else{
		$logger.logInfo("PM Data Feature Is Not Installed", $True)
		$logger.logInfo("Backup Procedure for PM Data will be Skipped !!", $True)
	}
	
	stageExit($MyInvocation.MyCommand)
}

Function PMDataRestore() {
	stageEnter($MyInvocation.MyCommand)
	$logger.logInfo("Checking if PM Data has to be restored", $True)
	
	If($installParams.PMDataBackup) {
		$logger.logInfo("Proceeding to restore PM Data", $True)
		$status = RestorePMData($installParams)
		
		if(-not $status) {
			$logger.logError($MyInvocation, "Could Not Restore PM Data", $True)
			MyExit($MyInvocation.MyCommand)
		}
		else {
			$logger.logInfo("PM Data Restored Successfully", $True)
		}
	}
	else {
		$logger.logInfo("PM Data Feature was Not Installed", $True)
		$logger.logInfo("Restoration Procedure for PM Data will be Skipped", $True)
	}
	
	stageExit($MyInvocation.MyCommand)
}

Function addDomainToTrustedSite() {
	stageEnter($MyInvocation.MyCommand)
	
	$status = addDomainToTrustedSites($installParams)
	if(-not $status) {
			$logger.logError($MyInvocation, "Could Not Add Domain to Trusted Sites", $True)
			MyExit($MyInvocation.MyCommand)
	}
	else {
		$logger.logInfo("Domain Successfully Added to Trusted Sites", $True)
	}
	
	stageExit($MyInvocation.MyCommand)
}

Function DeploymentPackageCheck() {
	stageEnter($MyInvocation.MyCommand)
	$logger.logInfo("Checking if any hotfix packages are present to apply", $True)
	$logger.logInfo("`n", $True)
	
	$directoryInfo = Get-ChildItem $installParams.hotfixDir | Measure-Object
	
	if($directoryInfo.count -eq 0) {
		$logger.logInfo("No Hotfix Files / Custom Packages are present", $True)
		$logger.logInfo("Cannot Apply Hotfix !!", $True)
		stageExit($MyInvocation.MyCommand)
		Exit
	}
	else {
		$spkFileInfo = Get-ChildItem $installParams.hotfixDir -Filter *.spk
		$global:hotfixfiles = New-Object System.Collections.Generic.List[string]
		if($spkFileInfo.count -gt 0)
		{
			foreach($file in Get-ChildItem $installParams.hotfixDir -Filter *.spk){
				$hotfixfiles.add($installParams.hotfixDir+"\"+$file.name)
			}
		}
		$sdnFileInfo = Get-ChildItem $installParams.hotfixDir -Filter *.sdn
		if($sdnFileInfo.count -gt 0)
		{
			foreach($file in Get-ChildItem $installParams.hotfixDir -Filter *.sdn){
				$hotfixfiles.add($installParams.hotfixDir+"\"+$file.name)
			}
		}
		if($hotfixfiles.count -eq 0) {
			$logger.logInfo("No Hotfix Files / Custom Packages are present", $True)
			$logger.logInfo("Cannot Apply Hotfix !!", $True)
			stageExit($MyInvocation.MyCommand)
		}
		else{
			$logger.logInfo("$($hotfixfiles.count) Deployment Files Found !!", $True)
			stageExit($MyInvocation.MyCommand)
			StopNetAnServer $installParams.nodeServiceName
			StopNetAnServer $installParams.serviceNetAnServer
			ApplyDeployment
			StartServer
			updateNetAnServiceConfigurations
			StartNodeManager
			
		}
	}
}

Function StartServer() {
    stageEnter($MyInvocation.MyCommand)

    $logger.logInfo("Preparing to Start NetAn Server", $True)
    $serviceExists = Test-ServiceExists "$($installParams.serviceNetAnServer)"
    $logger.logInfo("Service $($installParams.serviceNetAnServer) found: $serviceExists", $True)

    if ($serviceExists) {
		
		Set-Service "$($installParams.serviceNetAnServer)" -StartupType Automatic
        $isRunning = Test-ServiceRunning "$($installParams.serviceNetAnServer)"

        if ($isRunning) {
            $logger.logInfo("NetAn Server is already running....", $True)
        } else {

            try {
                $logger.logInfo("Starting service....", $True)
                Start-Service -Name "$($installParams.serviceNetAnServer)" -ErrorAction stop -WarningAction SilentlyContinue
				while(!$isRunning){
				Start-Sleep -s 25
				$isRunning = Test-ServiceRunning "$($installParams.serviceNetAnServer)"
				$logger.logInfo("Service $($installParams.serviceNetAnServer) is Running: $isRunning", $True)

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

Function StartServerII() {

    $logger.logInfo("Preparing to Start NetAn Server", $True)
    $serviceExists = Test-ServiceExists "$($installParams.serviceNetAnServer)"
    $logger.logInfo("Service $($installParams.serviceNetAnServer) found: $serviceExists", $True)

    if ($serviceExists) {
		
		Set-Service "$($installParams.serviceNetAnServer)" -StartupType Automatic
        $isRunning = Test-ServiceRunning "$($installParams.serviceNetAnServer)"

        if ($isRunning) {
            $logger.logInfo("NetAn Server is already running....", $True)
        } else {

            try {
                $logger.logInfo("Starting service....", $True)
                Start-Service -Name "$($installParams.serviceNetAnServer)" -ErrorAction stop -WarningAction SilentlyContinue
				while(!$isRunning){
				Start-Sleep -s 25
				$isRunning = Test-ServiceRunning "$($installParams.serviceNetAnServer)"
				$logger.logInfo("Service $($installParams.serviceNetAnServer) is Running: $isRunning", $True)

				}
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not start service. `n $errorMessage", $True)
            }
        }


    } else {
        $logger.logError($MyInvocation, "Service $($installParams.serviceNetAnServer) not found.
            Please check server install was executed correctly")
		Exit
    }
}

Function StartServer_Old() {

    $logger.logInfo("Preparing to Start NetAn Server", $True)
    $serviceExists = Test-ServiceExists "$($installParams.serviceNetAnServerOld)"
    $logger.logInfo("Service $($installParams.serviceNetAnServerOld) found: $serviceExists", $True)

    if ($serviceExists) {
		
		Set-Service "$($installParams.serviceNetAnServerOld)" -StartupType Automatic
        $isRunning = Test-ServiceRunning "$($installParams.serviceNetAnServerOld)"

        if ($isRunning) {
            $logger.logInfo("NetAn Server is already running....", $True)
        } else {

            try {
                $logger.logInfo("Starting service....", $True)
                Start-Service -Name "$($installParams.serviceNetAnServerOld)" -ErrorAction stop -WarningAction SilentlyContinue
				while(!$isRunning){
				Start-Sleep -s 25
				$isRunning = Test-ServiceRunning "$($installParams.serviceNetAnServerOld)"
				$logger.logInfo("Service $($installParams.serviceNetAnServerOld) is Running: $isRunning", $True)

				}
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not start service. `n $errorMessage", $True)
            }
        }


    } else {
        $logger.logError($MyInvocation, "Service $($installParams.serviceNetAnServerOld) not found.
            Please check server install was executed correctly")
		Exit
    }
}

Function ApplyDeployment()
{
	stageEnter($MyInvocation.MyCommand)
	[string] $logFile = $null
	
	$allpackages = ($hotfixfiles -join ",")
	$logger.logInfo("Using Arguments: update-deployment -t ******** -a Production $allpackages", $True)
	$loc = Get-Location
	Set-Location $($installParams.spotfirebin)
	$configTool = $installParams.spotfirebin + "config.bat"
    $logger.logInfo("Starting $configTool process")
	$envVariable = "NetAnVar"
    $password = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
	$command = "update-deployment -t $password -a Production $allpackages"
	try {
        if ($logFile) {
            $cfgProcess = Start-Process $configTool -ArgumentList $command -Wait -PassThru -NoNewWindow -RedirectStandardOutput $logFile
            cat $logFile >> $script:PERM_CONFIG_LOGFILE -ea SilentlyContinue
            rm $logFile -ea SilentlyContinue
        } else {
            $cfgProcess = Start-Process $configTool -ArgumentList $command -Wait -PassThru -NoNewWindow
        }
    } catch {
        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Exception while starting $configTool process `n $errorMessage", $True)
    } finally {
        Set-Location $loc
    }
	#cannot log arguments - contains passwords
    if ( -not ($cfgProcess.ExitCode -eq 0)) {
        $logger.logError($MyInvocation, "Configuration Command Failed: Exited with code " + $cfgProcess.ExitCode, $True)
		Exit
    } else {
        $logger.logInfo("Configuration Command Successful: Exit Code " + $cfgProcess.ExitCode)
    }
	
	stageExit($MyInvocation.MyCommand)
}

#----------------------------------------------------------------------------------
#  Minor Upgrade
#----------------------------------------------------------------------------------
Function updateScript() {
	
	stageEnter($MyInvocation.MyCommand)

	$netanserver_upgrade_backup_dir = "C:\Ericsson\NetAnServer\Backup"

################################################
#                                              #
#               Perform Backups                #
#                                              #
################################################
	try {
		$moduleBackups = "$netanserver_upgrade_backup_dir\modules-$($Script:instBuild.trim())"
		$backupRestoreScript = "$netanserver_upgrade_backup_dir\backup_restore-$($Script:instBuild.trim())"
		$logger.logInfo("Backing up Network Analytics Server Modules and Backup Restore script", $True)
		Copy-Item -Path $installParams.PSModuleDir -Destination $moduleBackups/ -Recurse -Force  -ea Stop
		if(Test-Path $installParams.backupRestoreScriptsDir) {
            Copy-Item -Path $installParams.backupRestoreScriptsDir -Destination $backupRestoreScript/ -Recurse -Force  -ea Stop
            if(Add-NetAnServerConfigMinorUpgrade($installParams)) {
                $logger.logInfo("Network Analytics Server upgrade successfully configured.", $True)
            }
            else {
                $logger.logError($MyInvocation, "Configuration of the Network Analytics Server failed.", $True)
                MyExit($MyInvocation.MyCommand)
            }
		}
		$logger.logInfo("Backup complete", $True)
	} catch {
		$logger.logWarning("Backup of modules and backup restore script failed, exiting upgrade", $True)
		$logger.logError($MyInvocation, $_.Exception.Message, $True)
		MyExit($MyInvocation.MyCommand)
	}
################################################
#                                              #
#                Start Upgrade                 #
#                                              #
################################################
	try {

    $logger.logInfo("Starting Platform Script Update of Network Analytics Server", $True)
    $logger.logInfo("Transferring NetAnServer modules and backup restore script", $True)

    Robocopy $installParams.moduleDir $installParams.PSModuleDir /E | Out-Null
    Robocopy $installParams.backupRestoreDir $installParams.backupRestoreScriptsDir /E | Out-Null
    $logger.logInfo("Transfer Complete", $True)

    ##########################################################################################
    # NOTE: If Modules have external dependencies e.g. resources dir, ensure transferred now #
    ##########################################################################################

    } catch {
        $logger.logWarning("A problem was detected during upgrade", $True)
        $logger.logError($MyInvocation, $_.Exception.Message)
        $logger.logWarning("Restoring modules and backup restore script from backup", $True)
        Remove-Item $installParams.PSModuleDir -Force -Recurse -Confirm:$False
        Robocopy $moduleBackups $installParams.PSModuleDir /E | Out-Null
        if(Test-Path $installParams.backupRestoreScriptsDir) {
            Remove-Item $installParams.backupRestoreScriptsDir -Force -Recurse -Confirm:$False
            Robocopy $backupRestoreScript $installParams.backupRestoreScriptsDir /E | Out-Null
        }
        $logger.logWarning("Module and Backup restore script restoration completed", $True)
        $logger.logError($MyInvocation, "The upgrade of the Network Anaytics Server was unsuccessful", $True)
	} finally {
		$logger.logInfo("Removing backups of platform modules and backup restore script", $True)

			if(Test-Path $moduleBackups) {
				Remove-Item $moduleBackups -Force -Recurse -Confirm:$False
			}
			if(Test-Path $backupRestoreScript) {
				Remove-Item $backupRestoreScript -Force -Recurse -Confirm:$False
			}
			if(Test-Path $netanserver_upgrade_backup_dir) {
				Remove-Item $netanserver_upgrade_backup_dir -Force -Recurse -Confirm:$False
			}

		$logger.logInfo("Removal complete", $True)
		}
		
	stageExit($MyInvocation.MyCommand)


}

#----------------------------------------------------------------------------------
#    Remove config node file for node manager config for 79 or 711 to 1010 upgrade
#----------------------------------------------------------------------------------


Function RemoveConfigNodeLogFile(){
    stageEnter($MyInvocation.MyCommand)
    try {
        $configNodeFile = $installParams.netanserverServerLogDir + "\confignode.txt"
        if((Test-Path($configNodeFile))){
            Remove-Item   $configNodeFile -Recurse -Force -ErrorAction SilentlyContinue
            $logger.logInfo("Previous node config file cleanup completed.", $True)
        }
        else{
            $logger.logInfo("No cleanup required.", $True)
        }
    }
    catch {

        $errorMessageConfigFileRemove = $_.Exception.Message
        $logger.logError($MyInvocation, "`n $errorMessageConfigFileRemove", $True)
        Exit
    }

    stageExit($MyInvocation.MyCommand)

}

#----------------------------------------------------------------------------------
#    Restore libraries for 7.9/7.11 to 1010 upgrade
#----------------------------------------------------------------------------------

Function RestoreBackupLibraryData(){
    stageEnter($MyInvocation.MyCommand)
    If(test-path $installParams.backupDirLibData){
        try {
            $libraryFileName = $installParams.backupDirLibAnalysisData + "library_content_all.part0.zip"
            # need to be ran in correct order
            $commandMap = [ordered]@{
                "import users" = "import-users $($installParams.backupDirLibData)users.txt -i true -t $($installParams.configToolPassword)";
                "import groups" = "import-groups $($installParams.backupDirLibData)groups.txt -t $($installParams.configToolPassword) -m true -u true";
                "import library" = "import-library-content --file-path=$($libraryFileName) --conflict-resolution-mode=KEEP_OLD --user=$($installParams.administrator) -t $($installParams.configToolPassword)";
                "import rules" = "import-rules -p $($installParams.backupDirLibData)rules.json -t $($installParams.configToolPassword)";
                "trust scripts" = "find-analysis-scripts -t  $($installParams.configToolPassword) -d true --library-parent-path=`"/Ericsson Library/`" -n"
            }

            foreach ($stage in $commandMap.GetEnumerator()) {
                if ($stage) {

                    $params = @{}
                    $params.spotfirebin = $installParams.spotfirebin
                    $logger.logInfo("Executing Stage $($stage.key)", $true)
                    $command = $stage.value
                    
                    $successful = Use-ConfigTool $command $params $installParams.tempConfigLogFile

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

        if (test-path $installParams.backupDirRepdb){

            $logger.logInfo("Restoring netanserver_repdb backup data...", $True)

            #import repdb tables (only the network analytics feature table required for 7.11 to 10.10 upgrade)
            $paramList.Add('repDatabase', 'netanserver_repdb')
            $importREPDBTablesQuery = "COPY netanserver_repdb.public.network_analytics_feature FROM '$($installParams.backupDirRepdb)network_analytics_feature.csv' DELIMITER ',' CSV HEADER;"
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


#----------------------------------------------------------------------------------
#  This Function prompts the user for the necessary input parameters required to
#  install Network Analytics Server:
#----------------------------------------------------------------------------------
Function InputParameters() {
    $confirmation = 'n'
    customWrite-host "You have initiated the installation of Network Analytics Server, NetAnServer."
    customWrite-host "Please refer to the Network Analytics Server Installation Instructions for an explanation of each parameter required.`n`n"

    while ($confirmation -ne 'y') {
		
		$TestNetAnISO = $false
		$attemptcount=1
		while(($TestNetAnISO -ne $true)-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
			$TestNetAnServerISO = customRead-host("Network Analytics Server ISO File Name:`n")
			if(($TestNetAnServerISO.Substring($TestNetAnServerISO.Length - 4)) -eq ".iso") {
				$TestNetAnServerISO = $TestNetAnServerISO -replace ".{4}$"
			}
			$TestNetAnISO = (Test-FileExists("C:/temp/media/netanserver/$($TestNetAnServerISO).iso"))
			if($TestNetAnISO -eq $false) {
				write-host("C:/temp/media/netanserver/$($TestNetAnServerISO).iso File Not Found. Please Try Again.`n")
			}
			else {
				$NetAnServerISO = $TestNetAnServerISO
			}
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server ISO File Name and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
		}$TestNetAnISO = $false
		
		$attemptcount=1
		while(($TestHostAndDomainStatus -ne $true)-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
			$hostAndDomain = customRead-host("Network Analytics Server Host-And-Domain:`n")
			$TestHostAndDomainStatus = Test-hostAndDomainURL $hostAndDomain
			
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server Host-And-Domain and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
		}$TestHostAndDomainStatus = $false
		$hostAndDomainURL= "https://"+($hostAndDomain)
		
		$attemptcount=1
        while(($PassMatchedmssql -ne 'y')-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
            $sqlAdminPassword = hide-password("PostgreSQL Administrator Password:`n")
            $resqlAdminPassword = hide-password("Confirm PostgreSQL Administrator Password:`n")
            $PassMatchedmssql = confirm-password $sqlAdminPassword $resqlAdminPassword
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify PostgreSQL Administrator Password and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
        }$PassMatchedmssql = 'n'

		$attemptcount=1
        while(($PassMatchedplat -ne 'y')-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
            $platformPassword = Fetch-Password("Network Analytics Server Platform Password:`n")
            $replatformPassword = hide-Password("Confirm Network Analytics Server Platform Password:`n")
            $PassMatchedplat = confirm-password $platformPassword $replatformPassword
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server Platform Password and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
        }$PassMatchedplat = 'n'

        $adminUser = customRead-host("Network Analytics Server Administrator User Name:`n")
		
		$attemptcount=1
        while(($PassMatchedserver -ne 'y')-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
            $adminPassword = Fetch-Password("Network Analytics Server Administrator user("+$adminUser+") Password:`n")
            $readminPassword = hide-Password("Confirm Network Analytics Server Administrator user("+$adminUser+") Password:`n")
            $PassMatchedserver = confirm-password $adminPassword $readminPassword
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server Administrator user("+$adminUser+") Password and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
        }$PassMatchedserver = 'n'
		
		$attemptcount=1
        while(($PassMatchedCert -ne 'y')-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
            $certPassword = hide-password("Network Analytics Server Certificate Password:`n")
            $recertPassword = hide-password("Confirm Network Analytics Server Certificate Password:`n")
            $PassMatchedCert = confirm-password $certPassword $recertPassword
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server Certificate Password and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
        }$PassMatchedCert = 'n'

        $eniqCoordinator = check-IP

		Write-Host("`n********************Below are the inputs provided********************")
		Write-host "Network Analytics Server ISO File Name: "-NoNewLine; write-host -fore Yellow $($NetAnServerISO)
		Write-host "Network Analytics Server Host-And-Domain: "-NoNewLine; write-host -fore Yellow $($hostAndDomain)
		Write-host "PostgreSQL Administrator Password: "-NoNewLine; write-host -fore Yellow "**********"
		Write-host "Network Analytics Server Platform Password: "-NoNewLine; write-host -fore Yellow "**********"
		Write-host "Network Analytics Server Administrator User Name: "-NoNewLine; write-host -fore Yellow $($adminUser)
		Write-host "Network Analytics Server Administrator user ("-NoNewLine; Write-host "$adminUser) Password: "-NoNewLine; write-host -fore Yellow "**********"
		Write-host "Network Analytics Server Certificate Password: "-NoNewLine; write-host -fore Yellow "**********"
		
        $confirmation = ''
		while(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
			$confirmation = customRead-host "`n`nPlease confirm that all of the above parameters are correct. (y/n)`n"
			if(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
				customWrite-host "`nInvalid Confirmation Input Provided!! Please Re-Enter ..."
			}
		}

        if ($confirmation -ne 'y') {
            customWrite-host "`n`nPlease re-enter the parameters.`n"
        }
    }

    $installParams.Add('sqlAdminPassword', $sqlAdminPassword)
    $installParams.Add('dbPassword', $platformPassword)
    $installParams.Add('configToolPassword', $platformPassword)
    $installParams.Add('administrator', $adminUser)
    $installParams.Add('adminPassword', $adminPassword)
    $installParams.Add('certPassword', $certPassword)
	$installParams.Add('hostAndDomain', $hostAndDomain)
    $installParams.Add('hostAndDomainURL', $hostAndDomainURL)
    $installParams.Add('eniqCoordinator', $eniqCoordinator)
	$installParams.Add('NetAnServerISO', $NetAnServerISO)
	
    Set-EnvVariable $platformPassword "NetAnVar"
    $logger.logInfo("Parameters confirmed, proceeding with the installation.", $True)
}

#----------------------------------------------------------------------------------
#  This Function prompts the user for the necessary input parameters required to
#  install Network Analytics Server:
#----------------------------------------------------------------------------------
Function InputParametersUpgrade() {
    $eniqCoordinator = check-IP
    $envVariable = "NetAnVar"
    $platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password

    $confirmation = 'n'
    customWrite-host "You have initiated the upgrade of Network Analytics Server."
    customWrite-host "Please refer to the Network Analytics Server Upgrade Instructions for an explanation of each parameter required.`n`n"

    while ($confirmation -ne 'y') {
	
		if($installParams.ssoServiceAccountPassword) {
			$installParams.Remove('ssoServiceAccountPassword')
		}
		if($installParams.PMDataBackup) {
			$installParams.Remove('PMDataBackup')
		}
		if($installParams.PMDataPackage) {
			$installParams.Remove('PMDataPackage')
		}
		if($installParams.certPassword) {
			$installParams.Remove('certPassword')
		}
		if($installParams.deployPMDataDir) {
			$installParams.Remove('deployPMDataDir')
		}
		if($installParams.PMDataResourcesDir) {
			$installParams.Remove('PMDataResourcesDir')
		}
		
		$attemptcount=1
		while(($TestNetAnISO -ne $true)-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
			$TestNetAnServerISO = customRead-host("Network Analytics Server ISO File Name:`n")
			if(($TestNetAnServerISO.Substring($TestNetAnServerISO.Length - 4)) -eq ".iso") {
				$TestNetAnServerISO = $TestNetAnServerISO -replace ".{4}$"
			}
			$TestNetAnISO = (Test-FileExists("C:/temp/media/netanserver/$($TestNetAnServerISO).iso"))
			if($TestNetAnISO -eq $false) {
				write-host("C:/temp/media/netanserver/$($TestNetAnServerISO).iso File Not Found. Please Try Again.`n")
			}
			else {
				$NetAnServerISO = $TestNetAnServerISO
			}
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server ISO File Name and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
		}$TestNetAnISO = $false

		$attemptcount=1
		while(($TestHostAndDomainStatus -ne $true)-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
			$hostAndDomain = customRead-host("Network Analytics Server Host-And-Domain:`n")
			$TestHostAndDomainStatus = Test-hostAndDomainURL $hostAndDomain
			
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server Host-And-Domain and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
		}$TestHostAndDomainStatus = $false
		$hostAndDomainURL= "https://"+($hostAndDomain)

        $username = customRead-host("Network Analytics Server Administrator User Name:`n")

		$attemptcount=1
        while (($PassMatchedAdmin -ne 'y')-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
            $adminPassword = Fetch-Password("Network Analytics Server Administrator user("+$username+") Password: `n")
            $readminPassword = hide-Password("Confirm Network Analytics Server Administrator user("+$username+") Password: `n")
            $PassMatchedAdmin = confirm-password $adminPassword $readminPassword
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server Administrator user("+$username+") Password and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
        }$PassMatchedAdmin = 'n'

        $attemptcount=1
        while(($PassMatchedmssql -ne 'y')-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
            $sqlAdminPassword = hide-password("PostgreSQL Administrator Password:`n")
            $resqlAdminPassword = hide-password("Confirm PostgreSQL Administrator Password:`n")
            $PassMatchedmssql = confirm-password $sqlAdminPassword $resqlAdminPassword
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify PostgreSQL Administrator Password and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
        }$PassMatchedmssql = 'n'
		
		$PostgreseDetails = Get-Service -Name "*postgresql-x64*" -ErrorAction SilentlyContinue
		if ($PostgreseDetails.Length -gt 0) {
			$PostgresBkpConfirmation = customRead-host("Do you want to take a backup before PostgreSQL upgrade? Backup may take some time depending on the database size. (y/n)`n")
		}

        $attemptcount=1
        while(($PassMatchedCert -ne 'y')-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
            $certPassword = hide-password("Network Analytics Server Certificate Password:`n")
            $recertPassword = hide-password("Confirm Network Analytics Server Certificate Password:`n")
            $PassMatchedCert = confirm-password $certPassword $recertPassword
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server Certificate Password and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
        }$PassMatchedCert = 'n'
		
		$attemptcount=1
		$PMDataStatus = Get-Features | Where-Object -FilterScript { $_.'Feature-Name'.trim() -eq 'PM-Data' }
		if(($PMDataStatus | Measure-Object).Count -gt 0) {
			$installParams.Add('PMDataBackup',$true)
			$installParams.Add('deployPMDataDir',$installParams.deployDir + "\pmdata")
			$installParams.Add('PMDataResourcesDir',$installParams.deployPMDataDir + "\resources")
			while(($TestPMDataPackage -ne $true)-and ($attemptcount -lt 4)) {
				$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
				$PMDataPackage = customRead-host("PM-Data feature Package Name:`n")
				if(($PMDataPackage.Substring($PMDataPackage.Length - 4)) -eq ".zip") {
					$PMDataPackage = $PMDataPackage -replace ".{4}$"
				}
				$TestPMPackage = (Test-Path -Path $deployDir\$PMDataPackage.zip)
				if($TestPMPackage -eq $false) {
					write-host("C:/Ericsson/tmp/$($PMDataPackage).zip File Not Found. Please Try Again.`n")
				}
				else {
					$TestPMDataPackage = $TestPMPackage
				}
				$attemptcount=$attemptcount+1
				if($attemptcount -gt 3) {
					$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
					$logger.logInfo("Please verify PM-Data feature Package Name and Re-run the script.", $True)
					Write-Host("`n")
					Exit
				}
			}$TestPMDataPackage = $false
			$installParams.Add('PMDataPackage',$PMDataPackage)
		}
		else {
			$installParams.Add('PMDataBackup',$false)
		}
		
		
		Write-Host("`n********************Below are the inputs provided********************")
		Write-host "Network Analytics Server ISO File Name: "-NoNewLine; write-host -fore Yellow $($NetAnServerISO)
		Write-host "Network Analytics Server Host-And-Domain: "-NoNewLine; write-host -fore Yellow $($hostAndDomain)
		Write-host "Network Analytics Server Administrator User Name: "-NoNewLine; write-host -fore Yellow $($username)
		Write-host "Network Analytics Server Administrator user ("-NoNewLine; Write-host "$username) Password: "-NoNewLine; write-host -fore Yellow "**********"
		Write-host "PostgreSQL Administrator Password: "-NoNewLine; write-host -fore Yellow "**********"
		if ($PostgreseDetails.Length -gt 0) {
			Write-host "Network Analytics Server Database Backup Confirmation: "-NoNewLine; write-host -fore Yellow $($PostgresBkpConfirmation)
		}
		Write-host "Network Analytics Server Certificate Password: "-NoNewLine; write-host -fore Yellow "**********"
		if($installParams.PMDataBackup) {
			Write-host "PM-Data feature Package Name: "-NoNewLine; write-host -fore Yellow $($PMDataPackage)
		}

        $confirmation = ''
		while(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
			$confirmation = customRead-host "`n`nPlease confirm that all of the above parameters are correct. (y/n)`n"
			if(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
				customWrite-host "`nInvalid Confirmation Input Provided!! Please Re-Enter ..."
			}
		}

        if ($confirmation -ne 'y') {
            customWrite-host "`n`nPlease re-enter the parameters.`n"
        }
    }
    $installParams.Add('sqlAdminPassword', $sqlAdminPassword)
    $installParams.Add('administrator', $username)
    $installParams.Add('dbPassword', $platformPassword)
    $installParams.Add('configToolPassword', $platformPassword)
    $installParams.Add('adminPassword', $adminPassword)
    $installParams.Add('certPassword', $certPassword)
    $installParams.Add('spn', "HTTP/"+$hostAndDomain)
	$installParams.Add('hostAndDomain', $hostAndDomain)
    $installParams.Add('hostAndDomainURL', $hostAndDomainURL)
    $installParams.Add('eniqCoordinator', $eniqCoordinator)
	$installParams.Add('NetAnServerISO', $NetAnServerISO)
	$installParams.Add('PostgresBkpConfirmation', $PostgresBkpConfirmation)
    Set-EnvVariable $platformPassword "NetAnVar"
    $logger.logInfo("Parameters confirmed, proceeding with the installation.", $True)

}

Function InputParametersUpgrade_Ansible() {
    $envVariable = "NetAnVar"
    $platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
	
	$logger.logInfo("Upgrade of Network Analytics Server from Deployment Tool is Initiated", $True)
	$logger.logInfo("Input Values are Auto Passed from Deployment Tool", $True)
	
	$hostAndDomain = $ansibleParams.hostAndDomain
	$hostAndDomainURL= "https://"+($hostAndDomain)
	$username = $ansibleParams.username
	$adminPassword = $ansibleParams.adminPassword
	$sqlAdminPassword = $ansibleParams.sqlAdminPassword
	$PostgresBkpConfirmation = $ansibleParams.PostgresBkpConfirmation
	$certPassword = $ansibleParams.certPassword
	$PMDataPackage = $ansibleParams.PMDataPackage
	if($PMDataPackage -eq 'False') {
		$installParams.Add('PMDataBackup',$false)
	}
	else {
		$installParams.Add('PMDataBackup',$true)
	}
	$resumeConfirmation = $ansibleParams.resumeConfirmation

    $installParams.Add('sqlAdminPassword', $sqlAdminPassword)
    $installParams.Add('administrator', $username)
    $installParams.Add('dbPassword', $platformPassword)
    $installParams.Add('configToolPassword', $platformPassword)
    $installParams.Add('adminPassword', $adminPassword)
    $installParams.Add('certPassword', $certPassword)
    $installParams.Add('spn', "HTTP/"+$hostAndDomain)
	$installParams.Add('hostAndDomain', $hostAndDomain)
    $installParams.Add('hostAndDomainURL', $hostAndDomainURL)
    $installParams.Add('eniqCoordinator', $eniqCoordinator)
	$installParams.Add('PostgresBkpConfirmation', $PostgresBkpConfirmation)
	$installParams.Add('PMDataPackage', $PMDataPackage)
	$installParams.Add('deployPMDataDir',$installParams.deployDir + "\pmdata")
	$installParams.Add('PMDataResourcesDir',$installParams.deployPMDataDir + "\resources")
	$installParams.Add('resumeConfirmation', $resumeConfirmation)
    Set-EnvVariable $platformPassword "NetAnVar"
    $logger.logInfo("Parameters confirmed from Deployment Tool, proceeding with the Upgrade.", $True)
}


Function getInputParamsForPlatformScriptsUpdate() {
    $eniqCoordinator = check-IP
    $envVariable = "NetAnVar"
    $platformPassword=(New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password

    $username = (Get-Users -all |% { if($_.Group -eq "Administrator" -and $_.USERNAME -ne "scheduledupdates") {return $_} } |Select-Object -first 1).USERNAME
    $confirmation = 'n'
    customWrite-host "You have initiated the upgrade of Network Analytics Server."
    customWrite-host "Please refer to the Network Analytics Server Upgrade Instructions for an explanation of each parameter required.`n`n"

    while ($confirmation -ne 'y') {
	
		$attemptcount=1
		 while(($TestHostAndDomainStatus -ne $true)-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
    	    $hostAndDomain = customRead-host("Network Analytics Server Host-And-Domain: `n")
			$TestHostAndDomainStatus = Test-hostAndDomainURL $hostAndDomain
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server Host-And-Domain and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
		}$TestHostAndDomainStatus = $false
		$hostAndDomainURL= "https://"+($hostAndDomain)

		 $attemptcount=1
         while (($PassMatchedAdmin -ne 'y')-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
            $adminPassword = Fetch-Password("Network Analytics Server Administrator user("+$username+") Password: `n")
            $readminPassword = hide-Password("Confirm Network Analytics Server Administrator user("+$username+") Password: `n")
            $PassMatchedAdmin = confirm-password $adminPassword $readminPassword
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server Administrator user("+$username+") Password and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
        }$PassMatchedAdmin = 'n'
		
		Write-Host("`n********************Below are the inputs provided********************")
		Write-host "Network Analytics Server Host-And-Domain: "-NoNewLine; write-host -fore Yellow $($hostAndDomain)
		Write-host "Network Analytics Server Administrator user ("-NoNewLine; Write-host "$username) Password: "-NoNewLine; write-host -fore Yellow "**********"

		$confirmation = ''
		while(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
			$confirmation = customRead-host "`n`nPlease confirm that all of the above parameters are correct. (y/n)`n"
			if(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
				customWrite-host "`nInvalid Confirmation Input Provided!! Please Re-Enter ..."
			}
		}
        if ($confirmation -ne 'y') {
            customWrite-host "`n`nPlease re-enter the parameters.`n"
        }
    }
    $installParams.Add('administrator', $username)
    $installParams.Add('dbPassword', $platformPassword)
    $installParams.Add('configToolPassword', $platformPassword)
    $installParams.Add('adminPassword', $adminPassword)
    $installParams.Add('spn', "HTTP/"+$hostAndDomain)
	$installParams.Add('hostAndDomain', $hostAndDomain)
    $installParams.Add('hostAndDomainURL', $hostAndDomainURL)
    $installParams.Add('eniqCoordinator', $eniqCoordinator)
    $logger.logInfo("Parameters confirmed, proceeding with the update.", $True)


}

Function getInputParamsForPlatformScriptsUpdate_Ansible() {
    <# $eniqCoordinator = check-IP #>
    $envVariable = "NetAnVar"
    $platformPassword=(New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password

    $username = (Get-Users -all |% { if($_.Group -eq "Administrator" -and $_.USERNAME -ne "scheduledupdates") {return $_} } |Select-Object -first 1).USERNAME

	$logger.logInfo("Upgrade of Network Analytics Server from Deployment Tool is Initiated", $True)
	$logger.logInfo("Input Values are Auto Passed from Deployment Tool", $True)
	
	$adminPassword = $ansibleParams.adminPassword
	$hostAndDomain = $ansibleParams.hostAndDomain
	$hostAndDomainURL= "https://"+($hostAndDomain)
	$resumeConfirmation = $ansibleParams.resumeConfirmation

    $installParams.Add('administrator', $username)
    $installParams.Add('dbPassword', $platformPassword)
    $installParams.Add('configToolPassword', $platformPassword)
    $installParams.Add('adminPassword', $adminPassword)
    $installParams.Add('spn', "HTTP/"+$hostAndDomain)
	$installParams.Add('hostAndDomain', $hostAndDomain)
    $installParams.Add('hostAndDomainURL', $hostAndDomainURL)
    $installParams.Add('eniqCoordinator', $eniqCoordinator)
	$installParams.Add('resumeConfirmation', $resumeConfirmation)
    $logger.logInfo("Parameters confirmed from Deployment Tool, proceeding with the update.", $True)


}

Function getInputParamsForMinorVersionUpgrade_Ansible() {
    <# $eniqCoordinator = check-IP #>
    $envVariable = "NetAnVar"
    $platformPassword=(New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password

    $confirmation = 'n'
    $logger.logInfo("Upgrade of Network Analytics Server from Deployment Tool is Initiated", $True)
	$logger.logInfo("Input Values are Auto Passed from Deployment Tool", $True)
	
	$hostAndDomain = $ansibleParams.hostAndDomain
	$hostAndDomainURL= "https://"+($hostAndDomain)
	$username = $ansibleParams.username
	$adminPassword = $ansibleParams.adminPassword
	$sqlAdminPassword = $ansibleParams.sqlAdminPassword
	$PostgresBkpConfirmation = $ansibleParams.PostgresBkpConfirmation
	$certPassword = $ansibleParams.certPassword
	$PMDataPackage = $ansibleParams.PMDataPackage
	if($PMDataPackage -eq 'False') {
		$installParams.Add('PMDataBackup',$false)
	}
	else {
		$installParams.Add('PMDataBackup',$true)
	}
	$resumeConfirmation = $ansibleParams.resumeConfirmation
	
	$installParams.Add('sqlAdminPassword', $sqlAdminPassword)
    $installParams.Add('administrator', $username)
    $installParams.Add('dbPassword', $platformPassword)
    $installParams.Add('configToolPassword', $platformPassword)
    $installParams.Add('adminPassword', $adminPassword)
	$installParams.Add('certPassword', $certPassword)
    $installParams.Add('spn', "HTTP/"+$hostAndDomain)
	$installParams.Add('hostAndDomain', $hostAndDomain)
    $installParams.Add('hostAndDomainURL', $hostAndDomainURL)
    $installParams.Add('eniqCoordinator', $eniqCoordinator)
	$installParams.Add('PostgresBkpConfirmation', $PostgresBkpConfirmation)
	$installParams.Add('PMDataPackage', $PMDataPackage)
	$installParams.Add('deployPMDataDir',$installParams.deployDir + "\pmdata")
	$installParams.Add('PMDataResourcesDir',$installParams.deployPMDataDir + "\resources")
	$installParams.Add('resumeConfirmation', $resumeConfirmation)
	Set-EnvVariable $platformPassword "NetAnVar"
    $logger.logInfo("Parameters confirmed from Deployment Tool, proceeding with the Upgrade.", $True)
}

Function getInputParamsForMinorVersionUpgrade() {
    $eniqCoordinator = check-IP
    $envVariable = "NetAnVar"
    $platformPassword=(New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password

    $confirmation = 'n'
    customWrite-host "You have initiated the upgrade of Network Analytics Server."
    customWrite-host "Please refer to the Network Analytics Server Upgrade Instructions for an explanation of each parameter required.`n`n"

    while ($confirmation -ne 'y') {
	
		if($installParams.ssoServiceAccountPassword) {
			$installParams.Remove('ssoServiceAccountPassword')
		}
		if($installParams.PMDataBackup) {
			$installParams.Remove('PMDataBackup')
		}
		if($installParams.PMDataPackage) {
			$installParams.Remove('PMDataPackage')
		}
		if($installParams.certPassword) {
			$installParams.Remove('certPassword')
		}
		if($installParams.deployPMDataDir) {
			$installParams.Remove('deployPMDataDir')
		}
		if($installParams.PMDataResourcesDir) {
			$installParams.Remove('PMDataResourcesDir')
		}
		
		
		$attemptcount=1
		while(($TestNetAnISO -ne $true)-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
			$TestNetAnServerISO = customRead-host("Network Analytics Server ISO File Name:`n")
			if(($TestNetAnServerISO.Substring($TestNetAnServerISO.Length - 4)) -eq ".iso") {
				$TestNetAnServerISO = $TestNetAnServerISO -replace ".{4}$"
			}
			$TestNetAnISO = (Test-FileExists("C:/temp/media/netanserver/$($TestNetAnServerISO).iso"))
			if($TestNetAnISO -eq $false) {
				write-host("C:/temp/media/netanserver/$($TestNetAnServerISO).iso File Not Found. Please Try Again.`n")
			}
			else {
				$NetAnServerISO = $TestNetAnServerISO
			}
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server ISO File Name and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
		}$TestNetAnISO = $false

		$attemptcount=1
		while(($TestHostAndDomainStatus -ne $true)-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
			$hostAndDomain = customRead-host("Network Analytics Server Host-And-Domain:`n")
			$TestHostAndDomainStatus = Test-hostAndDomainURL $hostAndDomain
			
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server Host-And-Domain and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
		}$TestHostAndDomainStatus = $false
		$hostAndDomainURL= "https://"+($hostAndDomain)
		
		$username = customRead-host("Network Analytics Server Administrator User Name:`n")

		 $attemptcount=1
         while(($PassMatchedAdmin -ne 'y')-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
            $adminPassword = Fetch-Password("Network Analytics Server Administrator user("+$username+") Password: `n")
            $readminPassword = hide-Password("Confirm Network Analytics Server Administrator user("+$username+") Password: `n")
            $PassMatchedAdmin = confirm-password $adminPassword $readminPassword
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify Network Analytics Server Administrator user("+$username+") Password and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
        }$PassMatchedAdmin = 'n'
		
		$attemptcount=1
		while(($PassMatchedmssql -ne 'y')-and ($attemptcount -lt 4)) {
			$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
			$sqlAdminPassword = hide-password("PostgreSQL Administrator Password:`n")
			$resqlAdminPassword = hide-password("Confirm PostgreSQL Administrator Password:`n")
			$PassMatchedmssql = confirm-password $sqlAdminPassword $resqlAdminPassword
			$attemptcount=$attemptcount+1
			if($attemptcount -gt 3) {
				$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
				$logger.logInfo("Please verify PostgreSQL Administrator Password and Re-run the script.", $True)
				Write-Host("`n")
				Exit
			}
		}$PassMatchedmssql = 'n'
		
		$PostgresBkpConfirmation = 'n'
		$PostgreseDetails = Get-Service -Name "*postgresql-x64*" -ErrorAction SilentlyContinue
		if ($PostgreseDetails.Length -gt 0) {
			$PostgresBkpConfirmation = customRead-host("Do you want to take a backup before PostgreSQL upgrade? Backup may take some time depending on the database size. (y/n)`n")
		}
		
			$attemptcount=1
            while(($PassMatchedCert -ne 'y')-and ($attemptcount -lt 4)) {
				$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
                $certPassword = hide-password("Network Analytics Server Certificate Password:`n")
                $recertPassword = hide-password("Confirm Network Analytics Server Certificate Password:`n")
                $PassMatchedCert = confirm-password $certPassword $recertPassword
				$attemptcount=$attemptcount+1
				if($attemptcount -gt 3) {
					$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
					$logger.logInfo("Please verify Network Analytics Server Certificate Password and Re-run the script.", $True)
					Write-Host("`n")
					Exit
				}
            }$PassMatchedCert = 'n'

            $installParams.Add('certPassword', $certPassword)
			
			$attemptcount=1
			$PMDataStatus = Get-Features | Where-Object -FilterScript { $_.'Feature-Name'.trim() -eq 'PM-Data' }
		if(($PMDataStatus | Measure-Object).Count -gt 0) {
			$installParams.Add('PMDataBackup',$true)
			$installParams.Add('deployPMDataDir',$installParams.deployDir + "\pmdata")
			$installParams.Add('PMDataResourcesDir',$installParams.deployPMDataDir + "\resources")
			while(($TestPMDataPackage -ne $true)-and ($attemptcount -lt 4)) {
				$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
				$PMDataPackage = customRead-host("PM-Data feature Package Name:`n")
				if(($PMDataPackage.Substring($PMDataPackage.Length - 4)) -eq ".zip") {
				$PMDataPackage = $PMDataPackage -replace ".{4}$"
				}
				$TestPMPackage = (Test-Path -Path $deployDir\$PMDataPackage.zip)
				if($TestPMPackage -eq $false) {
					write-host("C:/Ericsson/tmp/$($PMDataPackage).zip File Not Found. Please Try Again.`n")
				}
				else {
					$TestPMDataPackage = $TestPMPackage
				}
				$attemptcount=$attemptcount+1
				if($attemptcount -gt 3) {
					$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
					$logger.logInfo("Please verify PM-Data feature Package Name and Re-run the script.", $True)
					Write-Host("`n")
					Exit
				}
			}$TestPMDataPackage = $false
			$installParams.Add('PMDataPackage',$PMDataPackage)
		}
		else {
			$installParams.Add('PMDataBackup',$false)
		}
		
		Write-Host("`n********************Below are the inputs provided********************")
		Write-host "Network Analytics Server ISO File Name: "-NoNewLine; write-host -fore Yellow $($NetAnServerISO)
		Write-host "Network Analytics Server Host-And-Domain: "-NoNewLine; write-host -fore Yellow $($hostAndDomain)
		Write-host "Network Analytics Server Administrator User Name: "-NoNewLine; write-host -fore Yellow $($username)
		Write-host "Network Analytics Server Administrator user ("-NoNewLine; Write-host "$username) Password: "-NoNewLine; write-host -fore Yellow "**********"
		Write-host "PostgreSQL Administrator Password: "-NoNewLine; write-host -fore Yellow "**********"
		if ($PostgreseDetails.Length -gt 0) {
			Write-host "Network Analytics Server Database Backup Confirmation: "-NoNewLine; write-host -fore Yellow $($PostgresBkpConfirmation)
		}
		Write-host "Network Analytics Server Certificate Password: "-NoNewLine; write-host -fore Yellow "**********"
		if($installParams.PMDataBackup) {
			Write-host "PM-Data feature Package Name: "-NoNewLine; write-host -fore Yellow $($PMDataPackage)
		}

        $confirmation = ''
		while(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
			$confirmation = customRead-host "`n`nPlease confirm that all of the above parameters are correct. (y/n)`n"
			if(($confirmation -ne 'y') -and ($confirmation -ne 'n')) {
				customWrite-host "`nInvalid Confirmation Input Provided!! Please Re-Enter ..."
			}
		}

        if ($confirmation -ne 'y') {
            customWrite-host "`n`nPlease re-enter the parameters.`n"
        }
    }
    $installParams.Add('administrator', $username)
    $installParams.Add('dbPassword', $platformPassword)
    $installParams.Add('configToolPassword', $platformPassword)
    $installParams.Add('adminPassword', $adminPassword)
    $installParams.Add('spn', "HTTP/"+$hostAndDomain)
	$installParams.Add('hostAndDomain', $hostAndDomain)
    $installParams.Add('hostAndDomainURL', $hostAndDomainURL)
    $installParams.Add('eniqCoordinator', $eniqCoordinator)
	$installParams.Add('NetAnServerISO', $NetAnServerISO)
	$installParams.Add('sqlAdminPassword', $sqlAdminPassword)
	$installParams.Add('PostgresBkpConfirmation', $PostgresBkpConfirmation)
	Set-EnvVariable $platformPassword "NetAnVar"
    $logger.logInfo("Parameters confirmed, proceeding with the installation.", $True)
}

#----------------------------------------------------------------------------------
#  Validate ENIQ coordinator blade IP
#----------------------------------------------------------------------------------
Function check-IP (){
    $ip = [Environment]::GetEnvironmentVariable("LSFORCEHOST","User")

    if([string]::IsNullOrEmpty($ip)) {

         $logger.logError($MyInvocation, "LSFORCEHOST environment variable is not set as IP address of the ENIQ coordinator blade", $True)
         MyExit($MyInvocation.MyCommand)
    }

    if(Test-Connection -ComputerName $ip -Quiet) {
          $logger.logInfo("Ping to ENIQ coordinator blade successful.", $False)
          return $ip
      }else {
          $logger.logError($MyInvocation, "Ping to ENIQ coordinator blade failed", $True)
          MyExit($MyInvocation.MyCommand)
    }
}

#----------------------------------------------------------------------------------
#     Check that the Prerequisites are installed and configured
#      - postgresql Server, .NET, JCONN
#----------------------------------------------------------------------------------
Function CheckPrerequisites() {

    stageEnter($MyInvocation.MyCommand)
    # Check that installation is on the correct OS version
    if (Test-OS($installParams)) {
        $logger.logInfo("Operating System prerequisite passed.", $True)
    }
    else {
        $logger.logError($MyInvocation, "This Operating System is not supported.", $True)
        MyExit($MyInvocation.MyCommand)
    }
	# Check that installation is on the correct Framework version
    if (Test-FrameWork) {
        $logger.logInfo(".Net Framework prerequisite passed.", $True)
    }
    else {
        $logger.logError($MyInvocation, "Installed .Net Framework is not supported.", $True)
        MyExit($MyInvocation.MyCommand)
    }
    $postgres_service = "postgresql-x64-" +(((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).MajorVersion) | measure -Maximum).Maximum
    # Check that the postgres server is installed and running
    if (Test-ServiceRunning "$($postgres_service)") {
        $logger.logInfo("PostgreSQL installed and running.", $True)
    }
    else {
        $logger.logError($MyInvocation, "PostgreSQL is not running.", $True)
        $logger.logWarning("Please start PostgreSQL and restart the installation.", $True)
        MyExit($MyInvocation.MyCommand)
    }

    stageExit($MyInvocation.MyCommand)
}

Function DisableSSO() {
	
	$logger.logInfo("Checking if SSO is enabled on Server", $True)
	$envVariable = "NetAnVar"
    $password = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
	$currLocation = Get-Location
	
	if(Test-Path $($installParams.previousSpotfirebin+"configuration.xml")){
		Remove-Item $($installParams.previousSpotfirebin+"configuration.xml")
	}
	set-Location -Path $installParams.previousSpotfirebin
	.\config export-config -t $password --force | out-null
	
	if(Test-Path $($installParams.previousSpotfirebin+"configuration.xml")){
		[xml]$xmlObj = Get-Content $($installParams.previousSpotfirebin+"configuration.xml")
		$security = $xmlObj.SelectNodes("//security")
		$ldap = $xmlObj.SelectNodes("//user-directory")
		if($security."auth-method" -eq "KERBEROS") {
			$logger.logInfo("SSO Found to be enabled on server", $True)
			if(Test-Path $($installParams.logDir+"\sso-config-enable.txt")){
				$logger.logInfo("File Found :: $($installParams.logDir+"\sso-config-enable.txt")", $True)
			
			}
			else {
				$logger.logError($MyInvocation, "Could Not Find File :: $($installParams.logDir+"\sso-config-enable.txt")", $True)
				$logger.logError($MyInvocation, "Disabling SSO Failed", $True)
				Set-Location $currLocation
				MyExit($MyInvocation.MyCommand)
			}
			$logger.logInfo("Proceeding to disable SSO", $True)
			$status = DisableSSOServer $installParams
			if($status -ne $True) {
				$logger.logError($MyInvocation, "Disabling SSO Failed", $True)
				Set-Location $currLocation
				MyExit($MyInvocation.MyCommand)
			}
			else {
				if(Test-Path $($installParams.logDir+"\sso-disabled.touch")){
					Remove-Item $($installParams.logDir+"\sso-disabled.touch")
				}
				Out-File -FilePath $($installParams.logDir+"\sso-disabled.touch") | Out-Null
			}
		}
		elseif($ldap.ldap."ldap-configs"."ldap-config" -eq "LDAP Configuration") {
			$logger.logInfo("SSO was previously enabled on server but is currently disabled.", $True)
			$logger.logInfo("Disable SSO will be Skipped !!", $True)
			if(Test-Path $($installParams.logDir+"\sso-disabled.touch")){
				Remove-Item $($installParams.logDir+"\sso-disabled.touch")
			}
			Out-File -FilePath $($installParams.logDir+"\sso-disabled.touch") | Out-Null
		}
		else{
			$logger.logInfo("SSO Not enabled on Server", $True)
			$logger.logInfo("Disable SSO will be Skipped !!", $True)
		}
	}
	else{
		$logger.logError($MyInvocation, "Failed to export configuration.xml", $True)
		set-Location $currLocation
		MyExit($MyInvocation.MyCommand)
	}
	
	Set-Location $currLocation
}

Function DeleteExternalGroupsAndUsers() {
	stageEnter($MyInvocation.MyCommand)
	$platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable "NetAnVar")).GetNetworkCredential().Password
	if(Test-Path $($installParams.logDir+"\sso-disabled.touch")){
		$logger.logInfo("SSO was Enabled on Server Previously", $True)
		$sqlCount = "select count(g.GROUP_NAME) as `"Count`" from groups g where EXTERNAL_ID is not null and connected = true"
		$resultCount = Invoke-UtilitiesSQL -Database "netanserver_db" -Username "netanserver" -Password $platformPassword -ServerInstance "localhost" -Query $sqlCount -Action fetch
		$rowCount = $resultCount[1].Count
		if($rowCount -gt 0) {
			$logger.logInfo("$($rowCount) External Groups found that can be Deleted...", $True)
			$resultGroup = Invoke-UtilitiesSQL -Database "netanserver_db" -Username "netanserver" -Password $platformPassword -ServerInstance "localhost" -Query "select g.GROUP_NAME as `"GroupList`" from groups g where EXTERNAL_ID is not null and connected = true" -Action fetch
			$GroupList = $resultGroup[1].GroupList
			$logger.logInfo("Proceeding to Disable and Delete External Groups", $True)
			$sqlQuery = "update groups set connected = false where EXTERNAL_ID is not null"
			$result = Invoke-UtilitiesSQL -Database "netanserver_db" -Username "netanserver" -Password $platformPassword -ServerInstance "localhost" -Query $sqlQuery -Action fetch
			if($result) {
				$logger.logInfo("All External Groups Disabled Successfully !!", $True)
				$sqlQuery = "DELETE from GROUPS where EXTERNAL_ID is not null and CONNECTED = false"
				$result = Invoke-UtilitiesSQL -Database "netanserver_db" -Username "netanserver" -Password $platformPassword -ServerInstance "localhost" -Query $sqlQuery -Action fetch
				if($result) {
					$GroupList = $GroupList -join ', '
					$logger.logInfo("External Groups which are Deleted Successfully: $($GroupList)", $false)
					$logger.logInfo("All External Groups Deleted Successfully !!", $True)
				}
				else {
					$logger.logError($MyInvocation, "Failed to Delete External Groups", $True)
					$logger.logInfo("Please Delete External Groups Manually", $True)
				}
			}
			else {
				$logger.logError($MyInvocation, "Failed to Disable External Groups", $True)
				$logger.logInfo("Please Disable and Delete External Groups Manually", $True)
			}
		}
		else {
			$logger.logInfo("No External Groups found that can be Deleted...", $True)
			$logger.logInfo("Disable and Delete External Groups will be Skipped", $True)
		}
		
		$sqlCount = "select count(u.USER_NAME) as `"Count`" from Users u where EXTERNAL_ID is not null and enabled = true"
		$resultCount = Invoke-UtilitiesSQL -Database "netanserver_db" -Username "netanserver" -Password $platformPassword -ServerInstance "localhost" -Query $sqlCount -Action fetch
		$rowCount = $resultCount[1].Count
		if($rowCount -gt 0) {
			$logger.logInfo("$($rowCount) External Users found that can be Deleted...", $True)
			$resultUser = Invoke-UtilitiesSQL -Database "netanserver_db" -Username "netanserver" -Password $platformPassword -ServerInstance "localhost" -Query "select u.USER_NAME as `"UserList`" from Users u where EXTERNAL_ID is not null and enabled = true" -Action fetch
			$UserList = $resultUser[1].UserList
			if($UserList -gt 0) {
				$logger.logInfo("Proceeding to Delete External User Library Folders from Custom Library", $True)
				$count=0
				$custom_lib_deleted = New-Object System.Collections.Generic.List[System.Object]
				$params = @{}
				$params.spotfirebin = $installParams.spotfirebin
				$TEMP_CONFIG_LOG_FILE = "$($installParams.netanserverServerLogDir)\command_output_temp.log"
				for ($i = 0; $i -lt $UserList.length; $i++) {
					$folderName = $UserList[$i]
					$FolderCheckQuery = "select item_id from lib_current_items where title ='$folderName' and parent_id =(select item_id from lib_current_items where title ='Custom Library' and parent_id = (select item_id from lib_current_items where parent_id is null))"
					$FolderCheckResult = Invoke-UtilitiesSQL -Database "netanserver_db" -Username "netanserver" -Password $platformPassword -ServerInstance "localhost" -Query $FolderCheckQuery -Action fetch
					$folderID = $FolderCheckResult[1].item_id
					if(-not[string]::IsNullOrEmpty($folderID))
					{
						$folderPath = "`"/Custom Library/$folderName`""
						$command = "delete-library-items -t "+$platformPassword+" -L"+$($folderPath)+" --recursive=true -T`"spotfire.folder`" "+"--username="+$installParams.Administrator
						$folderUpdate = Use-ConfigTool $command $params $TEMP_CONFIG_LOG_FILE
						$count=$count+1
						$custom_lib_deleted.Add($folderName)
					}
				}
				$custom_lib_deleted = $custom_lib_deleted -join ', '
				$logger.logInfo("External User Library Folders from Custom Library which are Deleted Successfully: $($custom_lib_deleted)", $false)
				if($count -eq $rowCount) {
					$logger.logInfo("All External User Library Folders from Custom Library Deleted Successfully", $True)
				}
				else{
					$logger.logInfo("Few External User Library Folders from Custom Library Not Deleted", $True)
					$logger.logInfo("Please Delete the remaining External User Library Folders manually", $True)
				}
			}
			$logger.logInfo("Proceeding to Disable and Delete External Users", $True)
			$sqlQuery = "update users set enabled = false where EXTERNAL_ID is not null"
			$result = Invoke-UtilitiesSQL -Database "netanserver_db" -Username "netanserver" -Password $platformPassword -ServerInstance "localhost" -Query $sqlQuery -Action fetch
			if($result) {
				$logger.logInfo("All External Users Disabled Successfully !!", $True)
				$sqlQuery = "DELETE from users where EXTERNAL_ID is not null and enabled = false"
				$result = Invoke-UtilitiesSQL -Database "netanserver_db" -Username "netanserver" -Password $platformPassword -ServerInstance "localhost" -Query $sqlQuery -Action fetch
				if($result) {
					$UserList = $UserList -join ', '
					$logger.logInfo("External Users which are Deleted Successfully: $($UserList)", $false)
					$logger.logInfo("All External Users Deleted Successfully !!", $True)
				}
				else {
					$logger.logError($MyInvocation, "Failed to Delete External Users", $True)
					$logger.logInfo("Please Delete External Users Manually", $True)
				}
			}
			else {
				$logger.logError($MyInvocation, "Failed to Disable External Users", $True)
				$logger.logInfo("Please Disable and Delete External Users Manually", $True)
			}			
		}
		else {
			$logger.logInfo("No External Users found that can be Deleted...", $True)
			$logger.logInfo("Disable and Delete External Users will be Skipped", $True)
		}
		
	}
	else {
		$logger.logInfo("SSO was Not Enabled on Server ...", $True)
		$logger.logInfo("Skipping Deletion of External Users and Groups", $True)
	}
	
	if(Test-Path $($installParams.logDir+"\sso-disabled.touch")){
		Remove-Item $($installParams.logDir+"\sso-disabled.touch")
	}
	stageExit($MyInvocation.MyCommand)
}

#----------------------------------------------------------------------------------
#    Creating postgresql Server NetAnServer database
#----------------------------------------------------------------------------------
Function CreateDB() {
    stageEnter($MyInvocation.MyCommand)

    $status = Create-Databases $installParams
    if($status -ne $True) {
        $logger.logError($MyInvocation, "Creating the PostgreSQL databases failed", $True) # changed name to PostgreSQL
        MyExit($MyInvocation.MyCommand)
    }

    stageExit($MyInvocation.MyCommand)
}


#----------------------------------------------------------------------------------
#    Install the NetAnServer Server software
#----------------------------------------------------------------------------------
Function InstallServerSoftware() {
    stageEnter($MyInvocation.MyCommand)

    if(Install-NetAnServerServer($installParams)) {
        stageExit($MyInvocation.MyCommand)
    }
    else {
        $logger.logError($MyInvocation, "Installing the NetAnServer server component failed.", $True)
        MyExit($MyInvocation.MyCommand)
    }


}
#----------------------------------------------------------------------------------
#    Upgrade the NetAnServer Server software
#----------------------------------------------------------------------------------
Function UpgradeServer() {
    stageEnter($MyInvocation.MyCommand)

    if(Update-Server($installParams)) {
        stageExit($MyInvocation.MyCommand)
    }
    else {
        $logger.logError($MyInvocation, "Installing the NetAnServer server component failed.", $True)
        MyExit($MyInvocation.MyCommand)
    }


}

#----------------------------------------------------------------------------------
#    Copy the Server Certificate
#----------------------------------------------------------------------------------
Function AddCertificate($certdir) {
    stageEnter($MyInvocation.MyCommand)

    $logger.logInfo("Fetching the server certificate.", $True)
    Set-Location $certdir
    $certName=Get-ChildItem . | Where-Object { $_.Name -match '.p12' }
    Set-Location $loc
	
	$attemptcount=1
    while(!($certName -match ".p12") -and ($attemptcount -lt 4)) {
		$logger.logInfo("********************Attempt $($attemptcount) of 3********************", $True)
        $certificateConfirmation=''
		while(($certificateConfirmation -ne 'y') -and ($certificateConfirmation -ne 'n')) {
            $certificateConfirmation = customRead-host "`n`nPlease confirm that the server certificate has been placed in $($installParams.ericssonDir) (y/n)`n"
			if(($certificateConfirmation -ne 'y') -and ($certificateConfirmation -ne 'n')) {
				customWrite-host "`nInvalid Certificate Confirmation Input Provided!! Please Re-Enter ..."
			}
        }
		if($certificateConfirmation -eq 'n') {
			$logger.logInfo("Please verify Server Certificate has been placed in $($installParams.ericssonDir) 
			and Re-run the script.", $True)
			Write-Host("`n")
			Exit
		}
        Set-Location $certdir
        $certName=Get-ChildItem . | Where-Object { $_.Name -match '.p12' }
        Set-Location $loc
		if(!($certName -match ".p12")) {
			write-host("Server Certificate is not found in $($installParams.ericssonDir). Please Try Again.`n")
			$attemptcount=$attemptcount+1
		}
		if($attemptcount -gt 3) {
			$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
			$logger.logInfo("Please verify Server Certificate has been placed in $($installParams.ericssonDir) 
			and Re-run the script.", $True)
			Write-Host("`n")
			Exit
		}
    }

    $serverCert=$certdir+$certName

    $logger.logInfo("Moving the server certificate.", $True)
    $installParams.Add('serverCert',$serverCert)
    Copy-Item -Path $installParams.serverCert -Destination $installParams.serverCertInstall -Force

    $certTest=$installParams.serverCertInstall+$certName

    If (Test-Path $certTest) {
        stageExit($MyInvocation.MyCommand)
    } Else {
        $logger.logError($MyInvocation, "Moving the server certificate failed.", $True)
        MyExit($MyInvocation.MyCommand)
    }
}


#----------------------------------------------------------------------------------
#    Configure the NetAnServer Server
#----------------------------------------------------------------------------------
Function ConfigureServer() {
    stageEnter($MyInvocation.MyCommand)
	
	try {
         Copy-Item $installParams.legalwarningxml -Destination $installParams.serverLegalWarningDir  -errorAction stop
    }
    catch {
        $logger.logError($MyInvocation,"Error while coping file to location $($installParams.serverLegalWarningDir)", $True)
        Exit
    }
	
	try {
         Copy-Item $installParams.indexHTML -Destination $($installParams.serverLegalWarningDir + "ui\")  -errorAction stop
    }
    catch {
        $logger.logError($MyInvocation,"Error while coping file to location $($installParams.serverLegalWarningDir + "ui\")", $True)
        Exit
    }

    $result = Add-NetAnServerConfig($installParams)

	if($result -eq $True) {
		$logger.logInfo("Network Analytics Server successfully configured.", $True)
	}
	else {
		$logger.logError($MyInvocation, "Configuration of the Network Analytics Server failed.", $True)
		MyExit($MyInvocation.MyCommand)
	}

    stageExit($MyInvocation.MyCommand)
}




#----------------------------------------------------------------------------------
#    Configure the NetAnServer Server
#----------------------------------------------------------------------------------
Function ConfigureServerUpgrade() {
    stageEnter($MyInvocation.MyCommand)
	
	try {
         Copy-Item $installParams.legalwarningxml -Destination $installParams.serverLegalWarningDir  -errorAction stop
    }
    catch {
        $logger.logError($MyInvocation,"Error while coping file to location $($installParams.serverLegalWarningDir)", $True)
        Exit
    }
	
	try {
         Copy-Item $installParams.indexHTML -Destination $($installParams.serverLegalWarningDir + "ui\")  -errorAction stop
    }
    catch {
        $logger.logError($MyInvocation,"Error while coping file to location $($installParams.serverLegalWarningDir + "ui\")", $True)
        Exit
    }

    $result = Add-NetAnServerConfigUpgrade($installParams)

	if($result -eq $True) {
		$logger.logInfo("Network Analytics Server successfully configured.", $True)
	}
	else {
		$logger.logError($MyInvocation, "Configuration of the Network Analytics Server failed.", $True)
		MyExit($MyInvocation.MyCommand)
	}

    stageExit($MyInvocation.MyCommand)
}


#----------------------------------------------------------------------------------
#    Start the NetAnServer Server Service
#----------------------------------------------------------------------------------
Function ConfigureHTTPS() {
    stageEnter($MyInvocation.MyCommand)
	
	try {
         Copy-Item $installParams.ConfigureEnryptedPasswordjarDir -Destination $installParams.LibPath  -errorAction stop
    }
    catch {
        $logger.logError($MyInvocation,"Error while coping jar to location $($installParams.LibPath)", $True)
        Exit
    }
	
    If (Update-ServerConfigurations($installParams)) {
        stageExit($MyInvocation.MyCommand)
    } Else {
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

Function StopNetAn($service) {
	
    $serviceExists = Test-ServiceExists "$($service)"
    $logger.logInfo("Service $($service) found: $serviceExists", $True)
	
	if ($serviceExists) {
        $isRunning = Test-ServiceRunning "$($service)"

        if (!$isRunning) {
            $logger.logInfo("$($service) is already stopped....", $True)
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
		Exit
    }
}

Function HotFixes() {
    stageEnter($MyInvocation.MyCommand)

    $ScriptBlockHF = {
            StopNetAnServer($installParams.serviceNetAnServer)
            $installArgs = "" + $installParams.connectIdentifer + " " +
            $installParams.dbName +" "+ $installParams.dbUser + " " + $installParams.dbPassword
            $workingDir = Split-Path $installParams.updateDBScriptTarget
            try {
                $process = Start-Process -FilePath $installParams.updateDBScriptTarget -ArgumentList $installArgs -WorkingDirectory $workingDir -Wait -PassThru -RedirectStandardOutput $installParams.updatedbDBLog -ErrorAction Stop
            } catch {
                $logger.logInfo($MyInvocation, "Error Updating Database $netAnServerDB", $False)
                return $False
            }
            if ($process.ExitCode -eq 0) {
                $logger.logInfo("MS SQL Server database $netAnServerDB updated successfully.", $False)
                } else {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Creating the MS SQL Server database $netAnServerDB failed. $errorMessage", $True)
                return $False
            }
            Set-Location $installParams.javaPath
            Start-Process .\java.exe  -ArgumentList "-jar $($installParams.serverHFJar) /console $($installParams.installServerDir) -NoExit -wait"  -Wait
            $serverStarted = Start-SpotfireService($installParams.serviceNetAnServer)

            if($serverStarted) {
                try {
                    $a= Invoke-WebRequest -Uri https://localhost
                }
                catch {
                    $logger.logInfo("$($installParams.serviceNetAnServer) has started successfully`n", $True)
                }
            } else {
                $logger.logError($MyInvocation, "Error starting server", $True)
                return $False
            }
            

            Set-Location $loc
        }
    try {
            if((Test-Path($installParams.updatedbDBLog))){

                $logger.logInfo("HotFixes already installed", $True)

            } else{
            $logger.logInfo("Installing HotFixes", $True)
            Invoke-Command -ScriptBlock $ScriptBlockHF -ErrorAction Stop
            $logger.logInfo("HotFixes installed", $True)
            }
        }catch {
            $errorMessage = $_.Exception.Message
            $logger.logError($MyInvocation," HotFixes installation failed :  $errorMessage ", $True)
        }
    stageExit($MyInvocation.MyCommand)
}

#------------------------------------------------------------------------------------------------------
#    Install Node Manager
#------------------------------------------------------------------------------------------------------

Function InstallNodeManagerSoftware() {
    stageEnter($MyInvocation.MyCommand)

    if(Install-NetAnServerNodeManager($installParams)) {
		if($installParams.installReason -eq 'Upgrade') {
			try {
				$configNodeFile = $installParams.netanserverServerLogDir + "\confignode.txt"
				if((Test-Path($configNodeFile))){
					Remove-Item   $configNodeFile -Recurse -Force -ErrorAction SilentlyContinue
					$logger.logInfo("$($configNodeFile) file Cleanup Completed.", $True)
				}
				else{
					$logger.logInfo("File $($configNodeFile) Not Found", $True)
					$logger.logInfo("No cleanup required.", $True)
				}
			}
			catch {
				$errorMessageConfigFileRemove = $_.Exception.Message
				$logger.logError($MyInvocation, "`n $errorMessageConfigFileRemove", $True)
			}
		}
		if ( -not (Test-FileExists($installParams.confignode))) {
			if((Test-Path($installParams.nodeManagerConfigDirFile))){
				$logger.logInfo("File $($installParams.nodeManagerConfigDirFile) Already Present", $True)
				$logger.logInfo("Proceeding to Cleanup File $($installParams.nodeManagerConfigDirFile)", $True)
				Remove-Item   $installParams.nodeManagerConfigDirFile -Recurse -Force -ErrorAction SilentlyContinue
				$logger.logInfo("File $($installParams.nodeManagerConfigDirFile) Cleanup Completed.", $True)
			
			}
			else {
				$logger.logInfo("File $($installParams.nodeManagerConfigDirFile) Not Found", $True)
				$logger.logInfo("No Cleanup Required.", $True)
			}
			Create-Services $installParams
		}
		else{
            $logger.logInfo("Node manager config file already exists. Skipping procedure to Create Services ", $True)
        }
        stageExit($MyInvocation.MyCommand)
    }
    else {
        MyExit($MyInvocation.MyCommand)
    }
}
#------------------------------------------------------------------------------------------------------
#    Update Node Manager
#------------------------------------------------------------------------------------------------------

Function UpdateNodemanager() {
    stageEnter($MyInvocation.MyCommand)

    if(Delete-Node($installParams)) {
        stageExit($MyInvocation.MyCommand)
    }
    else {
        MyExit($MyInvocation.MyCommand)
    }
}

#----------------------------------------------------------------------------------
#    Start the NetAnServer Node Manager Service
#----------------------------------------------------------------------------------

Function StartNodeManager() {
    stageEnter($MyInvocation.MyCommand)

    $logger.logInfo("Preparing to start Node Manager", $True)
    $startSuccess = Start-SpotfireService($installParams.nodeServiceName)

    if ($startSuccess) {
        $isRunning = Test-ServiceRunning "$($installParams.nodeServiceName)"

        if ($isRunning) {
            $logger.logInfo("Node Manager is already running....", $True)
        } else {

            try {
                $logger.logInfo("Starting service....", $True)
                Start-Service -Name "$($installParams.nodeServiceName)" -ErrorAction stop -WarningAction SilentlyContinue
				while(!$isRunning){
				Start-Sleep -s 10
				$isRunning = Test-ServiceRunning "$($installParams.nodeServiceName)"

				}
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not start service. `n $errorMessage", $True)
            }
        }

        stageExit($MyInvocation.MyCommand)

    }  else {
        $logger.logError($MyInvocation, "Could not start $($installParams.nodeServiceName) service.", $True)
        MyExit($MyInvocation.MyCommand)
    }
}

Function StartNodeManager_Old() {

    $logger.logInfo("Preparing to start Node Manager", $True)
    $startSuccess = Start-SpotfireService($installParams.nodeServiceNameOld)

    if ($startSuccess) {
        $isRunning = Test-ServiceRunning "$($installParams.nodeServiceNameOld)"

        if ($isRunning) {
            $logger.logInfo("Node Manager is already running....", $True)
        } else {

            try {
                $logger.logInfo("Starting service....", $True)
                Start-Service -Name "$($installParams.nodeServiceNameOld)" -ErrorAction stop -WarningAction SilentlyContinue
				while(!$isRunning){
				Start-Sleep -s 10
				$isRunning = Test-ServiceRunning "$($installParams.nodeServiceNameOld)"

				}
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not start service. `n $errorMessage", $True)
            }
        }

    }  else {
        $logger.logError($MyInvocation, "Could not start $($installParams.nodeServiceNameOld) service.", $True)
        MyExit($MyInvocation.MyCommand)
    }
}


#----------------------------------------------------------------------------------
#    Configure the NetAnServer Node Manager
#----------------------------------------------------------------------------------
Function ConfigureNodeManager() {

        stageEnter($MyInvocation.MyCommand)

        if ( -not (Test-FileExists($installParams.confignode))) {

            $logger.logInfo("Start procedure to trust node", $True)
            $logger.logInfo("This procedure can take up to 15 mins. Please wait...", $True)

			if(Get-NodeStatus $installParams){
                $logger.logInfo("Successfully Trusted New Node", $True)
                Touch-File $installParams.confignode
                stageExit($MyInvocation.MyCommand)
            }
            else {
                $logger.logError($MyInvocation, "Configuring the Node Manager failed", $True)
				MyExit($MyInvocation.MyCommand)
            }
        }else{
            $logger.logInfo("Node manager config file already exists. Skipping Configuring Node Manager", $True)
            stageExit($MyInvocation.MyCommand)
        }

}


#------------------------------------------------------------------------------------------------------
#    Install Library Sructure
#------------------------------------------------------------------------------------------------------

Function InstallLibrary(){
    stageEnter($MyInvocation.MyCommand)

    $install = Install-LibraryStructure $installParams

    if($install -ne $True) {
        $logger.logError($MyInvocation, "The library structure was not installed", $True)
        MyExit($MyInvocation.MyCommand)
   }

    stageExit($MyInvocation.MyCommand)

}


#------------------------------------------------------------------------------------------------------
#    Configure the Platform Version in REPDB
#------------------------------------------------------------------------------------------------------
Function updatePlatformVersion() {
    if($Script:stage -gt 0){
    stageEnter($MyInvocation.MyCommand)
	}
    $logger.logInfo("Updating platform version information", $True)
    $versionXmlFile = Get-PlatformVersionFile "$($installParams.platformVersionDir)"


    if($versionXmlFile[0]) {
        $platformInfo = Get-PlatformDataFromFile $versionXmlFile[1]
    } else {
        $logger.logWarning($versionXmlFile[1], $true)
        return
    }

    if($platformInfo[0]) {
        $isInstalled = Test-IsPlatformInstalled $platformInfo[1]['product_id'] "$($installParams.'dbPassword')"
        if($isInstalled[0]){
            $update = Update-PlatformStatus $isInstalled[1] "$($installParams.'dbPassword')"
        }
        $isUpdated = Invoke-InsertPlatformVersionInformation $platformInfo[1] "$($installParams.'dbPassword')"
    } else {
        $logger.logWarning($platformInfo[1], $true)
        return
    }

    if($isUpdated[0]) {
        $logger.logInfo("Platform version information updated", $true)
    } else {
        $logger.logWarning("Platform version information not updated correctly", $true)
        $logger.logWarning($isUpdated[1], $False)
        return
    }

    if($Script:stage -gt 0){
    stageExit($MyInvocation.MyCommand)
    }
}


#----------------------------------------------------------------------------------
#    Install NetanServer Analyst
#----------------------------------------------------------------------------------
Function InstallAnalyst() {
		if($Script:major -eq $TRUE){
		$app = Get-WmiObject -Class Win32_Product -Filter "Name = 'Tibco Spotfire Analyst'"
		if($app){
		$result=$app.uninstall()
		$logger.logInfo("Tibco Spotfire Analyst Uninstall completed.", $False)
		}else{
			$logger.logInfo("Unable to find Tibco Spotfire Analyst to Uninstall", $False)
		}
		}
    stageEnter($MyInvocation.MyCommand)
    $logger.logInfo("Installing Network Analytics Server Analyst component", $True)
    $installAnalyst = Install-NetAnServerAnalyst $installParams

    If($installAnalyst){
         stageExit($MyInvocation.MyCommand)
     }else{
        $logger.logWarning("Network Analytics Server Analyst component did not install successfully", $true)
        MyExit($MyInvocation.MyCommand)
     }
}


#------------------------------------------------------------------------------------------------------
#    Configure the NFS Share NetAnServer Server Instrumentation log directory to ENIQ coordinator blade
#------------------------------------------------------------------------------------------------------
Function ConfigNfsShare() {
   stageEnter($MyInvocation.MyCommand)

   $status = Install-NFS $installParams

   if($status -ne $True) {
        $logger.logError($MyInvocation, "NFS Share configuration of Network Analytics Server Instrumentation Log Directory to" + $installParams.eniqCoordinator +" failed", $True)
        MyExit($MyInvocation.MyCommand)
   }

   stageExit($MyInvocation.MyCommand)
}


#----------------------------------------------------------------------------------
#    Update the Server and Web Player Service configuration files
#----------------------------------------------------------------------------------

Function updateNetAnServiceConfigurations() {
    stageEnter($MyInvocation.MyCommand)

    If (Update-Configurations($installParams)) {
        stageExit($MyInvocation.MyCommand)
    } Else {
        MyExit($MyInvocation.MyCommand)
    }
}

#------------------------------------------------------------------------------------------------------
#    Set Log permission for netanserver logs
#------------------------------------------------------------------------------------------------------
Function SetLogPermission() {

   stageEnter($MyInvocation.MyCommand)
   $flag = $true


   $folderList = @($installParams.tomcatServerLogDir,
                   $installParams.netanserverServerLogDir,
                   $installParams.nodeManagerLogDir,
                   $installParams.instrumentationLogDir
                   )

   $logger.logInfo("Setting access to NetAnServer Log files for Windows administrators only.", $true)

        foreach ($folderName in $folderList) {

            try {
                $acl = Get-Acl $folderName
                $acl.SetAccessRuleProtection($True, $False)
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
                $acl.AddAccessRule($rule)
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
                $acl.AddAccessRule($rule)
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("CREATOR OWNER","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
                $acl.AddAccessRule($rule)
                Set-Acl $folderName $acl
            } catch {
                $flag = $false
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not Set Permission for $folderName . `n $errorMessage", $True)
            }
        }

    if ($flag) {
        $logger.logInfo("NetAnServer Log Files permission access for Windows Server administrators done.", $true)
    } else {
        $logger.logInfo("NetAnServer Log Files permission access for Windows Server administrators Failed.", $True)
    }


   stageExit($MyInvocation.MyCommand)
}


Function SetupAdhoc(){

    stageEnter($MyInvocation.MyCommand)
    $childcreated=Invoke-ImportLibraryElement -element $installParams.customLib -username $installParams.administrator -password $installParams.configToolPassword -conflict "KEEP_NEW" -destination "/"


    $logger.logInfo("Creating Business Author and Business Analyst groups", $True)
    $isCreated = Add-Groups $installParams.groupTemplate  $installParams.configToolPassword
    if ($isCreated[0]) {
        $logger.logInfo("Setting up licences for Business Author and Business Analyst groups", $True)
        $isSet=Set-Licence $installParams.configToolPassword

        if ($isSet[0]) {
        $logger.logInfo("Business Author and Business Analyst licences set successfully", $True)
        } else {
            MyExit($isSet[1])
        }
        $logger.logInfo("Business Author and Business Analyst Groups created successfully", $True)

    }else{
        $logger.logError($MyInvocation, "Failed to create Business Author and Business Analyst Groups due to $errorString", $True)
        MyExit($MyInvocation.MyCommand)
    }

    stageExit($MyInvocation.MyCommand)
}

#------------------------------------------------------------------------------------------------------
#    Updating Adminsitrator User Password 
#------------------------------------------------------------------------------------------------------

Function UpdateUserPassword() {
stageEnter($MyInvocation.MyCommand)
     
     $userPassword = $installParams.adminPassword
     $username = $installParams.administrator
     $userPassword = $userPassword.Replace('"','""')
     $platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable "NetAnVar")).GetNetworkCredential().Password


     $passwordmap = $global:map.Clone()
     $passwordmap.Add('username', $username)
     $passwordmap.Add('platformPassword', $platformPassword)
     $passwordmap.Add('userPassword', $userPassword)
     $passwordmap.Add('configToolPassword', $platformPassword)

     $passwordArguments =  Get-Arguments set-user-password $passwordmap

     If($passwordArguments) {
         $UpdateUserPassword = Use-ConfigTool $passwordArguments $passwordmap
         If(!($UpdateUserPassword)) {

             $logger.logError($MyInvocation, "Error updating the password for User $($passwordmap.username)", $True)
         }
     } Else {
         $logger.logError($MyInvocation, "Command arguments not returned to update password for User $($passwordmap.username)", $True)
     }
    stageExit($MyInvocation.MyCommand)
 }


#----------------------------------------------------------------------------------
#    Cleanup - deletion of the install software, scripts and modules
#----------------------------------------------------------------------------------
Function FinalCleanupPlatform() {
	stageEnter($MyInvocation.MyCommand)
	try {
		# Remove Stage File
		if((Test-Path($stageFile))){
			Remove-Item $stageFile
			$logger.logInfo("$($stageFile) cleanup completed.", $True)	
		}
		$logger.logInfo("Performing cleanup completed.", $True)
	}
    catch {
        $logger.logError($MyInvocation, "Performing cleanup failed", $True)
    }
    stageExit($MyInvocation.MyCommand)
	
}

Function FinalCleanup() {
    stageEnter($MyInvocation.MyCommand)
    try{
		
		if(Test-Path($installParams.analystSoftware)) {
			Copy-Item -Path $installParams.analystSoftware -Destination $installParams.analystDir  -Force
		}
		if(Test-Path($installParams.languagepackmedia)) {
			Copy-Item -Path $installParams.languagepackmedia -Destination $installParams.languagepack -Recurse -Force
		}

	    Set-Location $installParams.installDir
		
		if((Test-Path($installParams.restoreDataPath))){
                Get-ChildItem $installParams.restoreDataPath -Recurse | Remove-Item -Force -Recurse
                Remove-Item $installParams.restoreDataPath -Recurse
            }

        # copy required files for restore and version number
        if( -not (Test-Path($installParams.restoreDataPath))){
            New-Item $installParams.restoreDataPath -type directory | Out-Null
        }

        if( -not (Test-Path($installParams.housekeepingDir))){
            New-Item $installParams.housekeepingDir -type directory | Out-Null
        }

        if( -not (Test-Path($installParams.adhoc_user_lib))){
            New-Item $installParams.adhoc_user_lib -type directory | Out-Null
        }


        Copy-Item -Path $installParams.platformVersionDir -Destination $installParams.restoreDataPath -Recurse -Force
        Copy-Item -Path $installParams.housekeepingScript -Destination $installParams.housekeepingDir -Recurse -Force
        Copy-Item -Path $installParams.adhoc_xml -Destination $installParams.adhoc_user_lib -Recurse -Force


        Get-ChildItem $netanserver_media_dir -Recurse | Remove-Item -Force -Recurse

        #remove old software
        if ($oldVersion){

            $Software_List = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "Tibco Spotfire Node Manager $oldVersion*"}
			$Uninstall_String = $Software_List.QuietUninstallString
            if($Uninstall_String){
                $result=Invoke-Command -ScriptBlock { & cmd /c $Uninstall_String /norestart }
                $logger.logInfo("Tibco Spotfire Node Manager $oldVersion Uninstall completed.", $True)
            }else{
                $logger.logInfo("Unable to find Tibco Spotfire Node Manager $oldVersion  to Uninstall", $True)
            }

            $Software_List = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "Tibco Spotfire Server $oldVersion*"}
			$Uninstall_String = $Software_List.QuietUninstallString
            if($Uninstall_String){
                $result=Invoke-Command -ScriptBlock { & cmd /c $Uninstall_String /norestart }
                $logger.logInfo("Tibco Spotfire Server $oldVersion Uninstall completed.", $True)
            }else{
                $logger.logInfo("Unable to find Tibco Spotfire Server $oldVersion to Uninstall", $True)
            }

            # Remove old directories
            if((Test-Path($installParams.OldNetAnServerDir))){
                Get-ChildItem $installParams.OldNetAnServerDir -Recurse | Remove-Item -Force -Recurse
                Remove-Item $installParams.OldNetAnServerDir -Recurse
                $logger.logInfo("Previous Tomcat directory cleanup completed.", $True)
            }

            if((Test-Path($installParams.automationServicesDirectoryOld))){
                Get-ChildItem $installParams.automationServicesDirectoryOld -Recurse | Remove-Item -Force -Recurse
                Remove-Item $installParams.automationServicesDirectoryOld -Recurse

            }

            if((Test-Path($installParams.statsServicesDirectoryOld))){
                Get-ChildItem $installParams.statsServicesDirectoryOld -Recurse | Remove-Item -Force -Recurse
                Remove-Item $installParams.statsServicesDirectoryOld -Recurse

            }

            if((Test-Path($installParams.hotfixesDirectory))){
                Get-ChildItem $installParams.hotfixesDirectory -Recurse | Remove-Item -Force -Recurse
                Remove-Item $installParams.hotfixesDirectory -Recurse

            }

            if((Test-Path($installParams.migrationDir))){
                Get-ChildItem $installParams.migrationDir -Recurse | Remove-Item -Force -Recurse
                Remove-Item $installParams.migrationDir -Recurse

            }

            # delete the 7.x version of the analyst tool. 10.10 and above are always called setup.exe and are replaced - no need to delete
            if((Test-Path($installParams.analystinstallerExeOld)) -and ($installParams.analystinstallerExeOld -like "*setup-7*") ){
                Remove-Item $installParams.analystinstallerExeOld -Recurse

            }

            }
			# Remove Unwanted Environment Paths
			$path = $env:PSModulePath
			$path = ($path.Split(';') | Where-Object { $_ -ne 'C:\Ericsson\tmp\Scripts\modules' }) -join ';'
			[Environment]::SetEnvironmentVariable("PSModulePath", $path, "Machine")
			
			# Remove Stage File
			if((Test-Path($stageFile))){
                Remove-Item $stageFile
				$logger.logInfo("$($stageFile) cleanup completed.", $True)
			}
			
			# Remove backup taken for SSO
			if(Test-Path $($installParams.logDir+"\sso-config-enable.txt")){
				Set-ItemProperty $($installParams.logDir+"\sso-config-enable.txt") -name IsReadOnly -value $false
				Remove-Item $($installParams.logDir+"\sso-config-enable.txt")
			}
			
			# Remove SSO Directory
			if((Test-Path($installParams.SSOScriptDir))){
                Get-ChildItem $installParams.SSOScriptDir -Recurse | Remove-Item -Force -Recurse
                Remove-Item $installParams.SSOScriptDir -Recurse
				$logger.logInfo("SSO Directory Removal Completed", $True)
            }
			
			if(Test-Path $($installParams.logDir+"\sso-disabled.touch")) {
				Set-ItemProperty $($installParams.logDir+"\sso-disabled.touch") -name IsReadOnly -value $false
				Remove-Item $($installParams.logDir+"\sso-disabled.touch")
			}
			
			$decryptFlagFile = $deployDir+"\$($installparams.sv)ExtractionFlagFile.txt"
			
			if(Test-Path $($decryptFlagFile)) {
				Set-ItemProperty $($decryptFlagFile) -name IsReadOnly -value $false
				Remove-Item $($decryptFlagFile)
			}
			
			# Remove old version_strings.xml, version_string.txt and platform-release.xml from NetAnServer\RestoreDataResources\version
			if(Test-Path $(($installparams.installDir)+"\RestoreDataResources\version\platform-release*")) {
				Set-ItemProperty $(($installparams.installDir)+"\RestoreDataResources\version\platform-release*") -name IsReadOnly -value $false
				Remove-Item $(($installparams.installDir)+"\RestoreDataResources\version\platform-release*")
			}
			
			if(Test-Path $(($installparams.installDir)+"\RestoreDataResources\version\version_string*")) {
				Set-ItemProperty $(($installparams.installDir)+"\RestoreDataResources\version\version_string*") -name IsReadOnly -value $false
				Remove-Item $(($installparams.installDir)+"\RestoreDataResources\version\version_string*")
			}
			
			if(Test-Path $(($installparams.installDir)+"\RestoreDataResources\version\version_strings*")) {
				Set-ItemProperty $(($installparams.installDir)+"\RestoreDataResources\version\version_strings*") -name IsReadOnly -value $false
				Remove-Item $(($installparams.installDir)+"\RestoreDataResources\version\version_strings*")
			}

        $logger.logInfo("Performing cleanup completed.", $True)
    } catch {
        $logger.logError($MyInvocation, "Performing cleanup failed", $True)
    }
    stageExit($MyInvocation.MyCommand)
}

Function Touch-File
{
    $file = $args[0]
    if($file -eq $null) {
        throw "No filename supplied"
    }

    if(Test-Path $file)
    {
        (Get-ChildItem $file).LastWriteTime = Get-Date
    }
    else
    {
        echo $null > $file
    }
}



#----------------------------------------------------------------------------------
#  Exit Function to Log error and terminate.
#----------------------------------------------------------------------------------
Function MyExit($errorString) {
    $logger.logError($MyInvocation, "Installation of NetAnServer failed in method: $errorString", $True)
    Exit
}


Function stageEnter([string]$myText) {
    $Script:stage=$Script:stage+1
	([string]$myText)| Add-Content $stageFile
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

Function customWrite-host($text) {
      Write-Host $text -ForegroundColor White
 }

Function customRead-host($text) {
      Write-Host $text -ForegroundColor White -NoNewline
      Read-Host
 }

Function Test-hostAndDomainURL([string]$value){
    try{
        if(!$TestHostAndDomainStatus){
	        if(Test-Connection $value -Quiet -WarningAction SilentlyContinue){
	            return $True
            }
	        else {
	            $logger.logError($MyInvocation, "Could not resolve $($value)`nPlease confirm that the correct host-and-domain has been entered and retry.`nIf issue persists please contact your local network administrator", $True)
            }
        }
    }
    catch{
        $logger.logError($MyInvocation, "Could not resolve $($value). Please contact your local network administrator", $False)
    }

}
if(($MyInvocation.PSCommandPath -ne 'C:\Ericsson\tmp\Scripts\Install\NetAnServer_upgrade.ps1') -and ($MyInvocation.PSCommandPath -ne 'C:\Ericsson\tmp\Scripts\Install\NetAnServer_upgrade_ansible.ps1')){
	Main
}
