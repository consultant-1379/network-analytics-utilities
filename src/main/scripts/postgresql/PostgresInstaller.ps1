# ********************************************************************
# Ericsson Radio Systems AB                                     Script
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
# Name    : PostgresInstaller.ps1
# Date    : 19/07/2021
# Revision: PA1
# Purpose : To install or upgrade PostgreSQL server and ODBC driver
# 
# Usage   :  .\PostgresInstaller.ps1
#
#---------------------------------------------------------------------------------

Function Install-Postgres {
# Installs PostgreSQL 
	Param
    (
        [Parameter(Mandatory=$true)]
        [string]$password,
        [Parameter(Mandatory=$true)]
        [int]$port
    )
	$serverInstaller = Get-Installer "psqlserver"
	$logger.logInfo("PostgreSQL `(version $targetVersion`) installation has started. This may take few minutes.", $True)
	$installCommand = $serverInstaller + " --unattendedmodeui none  --mode unattended --superpassword " + $password + " --serverport " + $port
	$installed = cmd /c $installCommand
	$logger.logInfo("PostgreSQL installation completed.", $True)
}

Function hide-password($text) {
# Writes text to screen and hides the password
      Write-Host $text -ForegroundColor White -NoNewline
      $EncryptedPass=Read-Host -AsSecureString
      $unencryptedpassword = (New-Object System.Management.Automation.PSCredential 'N/A', $EncryptedPass).GetNetworkCredential().Password
      return $unencryptedpassword
}

Function confirm-password([string]$FirstPass,[string]$SecondPass) {
# Checks if password entered by user matches
    if (($FirstPass -clike $SecondPass)) {
        return 'y'
    } else {
        Write-host "`nPassword doesn't match.`n"
        return 'n'
    }
}

Function Get-Password {
# Prompts user and gets PostgreSQL password during initial installation
	$PassMatchedpsql = 'n'
	while ($PassMatchedpsql -ne 'y') {
		$psqlAdminPassword = hide-password("`nPostgreSQL Administrator Password:`n")
		$repsqlAdminPassword = hide-password("Confirm PostgreSQL Administrator Password:`n")
		$PassMatchedpsql = confirm-password $psqlAdminPassword $repsqlAdminPassword
    }$PassMatchedpsql = 'n'
	return $psqlAdminPassword
}

Function Update-Configuration {
# Updates pg_hba.conf file and restarts postgres service
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$path,
		[Parameter(Mandatory=$true)]
        [string]$service
		
	)
	try {
		$confPath = $path + "\data\pg_hba.conf"
		$oldContent = Get-Content $confPath
		$oldContent | ForEach-Object { 
			if($_) {
				if ($_.Substring(0, 1) -ne "#") {"#" + $_} 
				else {$_}
			} else {$_}
		} | Set-Content $confPath
		Add-Content $confPath "`nhost all all 0.0.0.0/0 md5`nhost all all ::0/0 md5"
		$logger.logInfo("PostgreSQL configuration is updated.", $True)
		Restart-PostgresService $service
	} catch {
		$logger.logError($MyInvocation, "PostgreSQL configuration update failed.", $True)
	}
}

Function Restart-PostgresService {
# Restarts Postgres service
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$service
	)
	Restart-Service $service -ErrorAction stop -WarningAction SilentlyContinue
	if (Test-ServiceRunning($service)) {
		$logger.logInfo("PostgreSQL service is restarted.", $True)
	} else {
		$logger.logInfo("PostgreSQL service is restarted. Waiting for it to start running.", $True)
	}
}


Function Check-ServiceExists {
# Checks if postgres service exists and returns the service name
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$service
	)
	$serviceDetails = Get-Service -Name $service -ErrorAction SilentlyContinue
	if ($serviceDetails.Length -gt 0) {
		return $True,$serviceDetails.Name
	} else {
		return $False,$NULL
	}
}

Function Install-ODBCDriver {
# Installs postgres ODBC driver
	try {
		$odbcInstaller = Get-Installer "psqlodbc"
		$a = Invoke-Command -ScriptBlock {msiexec.exe /i $odbcInstaller /quiet /norestart}
		write-host ($a)
		return @($True,"PostgreSQL ODBC driver is installed.")
	} catch {
		return @($False,"PostgreSQL ODBC driver installation failed.")
	}
}

Function Upgrade-ODBCDriver {
# Upgrades postgres ODBC driver
	[xml]$versionXml = Get-Content "$resourceDirectory\postgresql_version.xml"
	$targetVersion = [double]($versionXml.postgresql.'driver-details'.version)
	$installedVersion = ((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -eq "psqlODBC_x64" }).VersionMajor) + (((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -eq "psqlODBC_x64" }).VersionMinor)/10)
	if($installedVersion -gt 0) {
		$logger.logInfo("Current ODBC driver version :: $($installedVersion)", $True)
	}
	if ($targetVersion -gt $installedVersion) {
		$logger.logInfo("New ODBC driver version :: $($targetVersion)", $True)
		$MyApp = Get-WmiObject -Class Win32_Product | Where-Object{$_.Name -eq "psqlODBC_x64"}
		if($MyApp) {
			$inst=$MyApp.Uninstall()
		}
		$result = Install-ODBCDriver
	} else {
		$result = @($True,"Same or higher version of PostgeSQL ODBC driver is already installed.")
	}
	return $result
}

Function Get-Installer {
# Gets installer file details for both postgres server and odbc driver
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$component
	)
	$directory = $installerDirectory + $component
	$installerZip = $installerDirectory + (Get-ChildItem -Path "$directory*" -Name)
	$unzippedInstaller = Unzip-File $installerZip $directory
	if(-not $unzippedInstaller[0]) {
		$logger.logWarning($unzippedInstaller[1], $True)
		return
	} else {
		$installerFile = $directory + "\" + (Get-ChildItem -Path $directory -Include *.exe,*.msi -Name)
		return $installerFile
	}
}

Function Clean-Up {
# Removes unzipped installer files and temporary user
	if (Test-Path "$installerDirectory\psqlserver") {
		Remove-Item "$installerDirectory\psqlserver"  -Recurse -Force
	}
	if (Test-Path "$installerDirectory\psqlodbc") {
		Remove-Item "$installerDirectory\psqlodbc"  -Recurse -Force
	}
	if (Get-LocalUser | Where-Object {$_.Name -eq $tempUser}) {
		Remove-LocalUser -Name $tempUser | Out-Null
	}
	Clean-EnvPath
}

Function Clean-EnvPath {
    $env:PSModulePath = $originalEnvPath
    [Environment]::SetEnvironmentVariable("PSModulePath", $originalEnvPath, "Machine")
}

Function Get-PostgresVersion {
# Gets installed postgres version
	$majorVersion = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres* | Select MajorVersion).MajorVersion
	$minorVersion = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres* | Select MinorVersion).MinorVersion
	return $majorVersion,$minorVersion
}

Function Get-PostgresVersionDB {
	$adminPassword = $installParams.sqladminpassword
	$result = Invoke-UtilitiesSQL -Database postgres -Username postgres -Password $adminPassword -ServerInstance localhost -Query "SHOW server_version;" -Action fetch
	
	if ( -not $result[0]) {
		$logger.logError($MyInvocation, "Incorrect password or the PostgreSQL service is not running.", $True)
		Exit
	}
	return $result[1].server_version

}

Function Get-TargetVersion {
# Gets the target version
	[xml]$versionXml = Get-Content "$resourceDirectory\postgresql_version.xml"
	return $versionXml.postgresql.'server-details'.version
}

Function Verify-Password {
# Verify postgres admin password during upgrade
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$password
	)
	$result = Invoke-UtilitiesSQL -Database postgres -Username postgres -Password $password -ServerInstance localhost -Query "SHOW server_version;" -Action fetch
	return $result[0]
}

Function Take-Backup {
# Take postgres backup
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$password
	)
	try {
		& "$($backupScriptDirectory)\NetAnServer_migration_backup_postgresql.ps1"
	} catch {
		$logger.logError($MyInvocation, "PostgreSQL backup failed.", $True)
		Exit
	} 
}

Function Perform-Prerequisites {
# Give postgres user all required permissions for executing pg_upgrade
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$path,
		[Parameter(Mandatory=$true)]
        [Security.AccessControl.FileSystemAccessRule]$rule
	)
	$acl = Get-ACL "$path\data"
	$acl.SetAccessRule($rule)
	Set-ACL -Path "$path\data" -AclObject $acl
	Rename-Item "$path\data\pg_hba.conf" "pg_hba.conf.backup"
	Copy-Item -Path "$resourceDirectory\pg_hba.conf" -Destination "$path\data"
}

Function Minor-Upgrade {
# Performs minor version upgrade
	$installedVersion = Get-PostgresVersion
	$targetVesrion = Get-TargetVersion
	$installedVersionDB = Get-PostgresVersionDB
	$adminPassword = $installParams.sqladminpassword
	$targetMajorVersion = ($targetVersion.Split("."))[0]
	$oldInstallationPath = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).InstallLocation
	if ( -not (Verify-Password $adminPassword)) {
		$logger.logError($MyInvocation, "Incorrect password or the PostgreSQL service is not running.", $True)
		Exit
	} else {
		$confirmation = $installParams.PostgresBkpConfirmation
		if ($confirmation -ne "y" -and $confirmation -ne "n") {
			$logger.logError($MyInvocation, "Invalid input.", $True)
			Clean-Up
		} else {
			try {
				if($confirmation -eq "y") {
					Take-Backup $adminPassword
				}
				$logger.logInfo("", $True)
				$logger.logInfo("------------------------------------------------------", $True)
				$logger.logInfo("|         Starting PostgreSQL installation", $True)
				$logger.logInfo("|", $True)
				$logger.logInfo("------------------------------------------------------", $True)
				$logger.logInfo("", $True)
				Install-Postgres $adminPassword 5433
				Stop-Services
				$newInstallationPath = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres* | Where-Object {$_.MajorVersion -like $targetMajorVersion}).InstallLocation
				Start-PGupgrade_Minor $oldInstallationPath $newInstallationPath
				$serviceDetails = Check-ServiceExists "*postgresql-x64*$targetMajorVersion*"
				Restart-PostgresService $serviceDetails[1]
				Analyze-Cluster $newInstallationPath
				if (Verify-Upgrade $adminPassword $serviceDetails) {
					Remove-Item -Path "$newInstallationPath\data\pg_hba.conf"
					Rename-Item "$newInstallationPath\data\pg_hba.conf.backup" "pg_hba.conf"
					Update-Configuration $newInstallationPath $serviceDetails[1]
					Start-NetAnServices
					if([int]($targetVesrion.Split(".")[0]) -gt $installedVersion[0]) {
						Uninstall-OldPostgres $oldInstallationPath
					}
				} else {
					$logger.logError($MyInvocation, "PostgreSQL upgrade failed. Starting rollback.", $True)
					Start-Rollback $oldInstallationPath $newInstallationPath
				}
			} catch {
				$logger.logError($MyInvocation, "PostgreSQL upgrade failed. Starting rollback.", $True)
				Start-Rollback $oldInstallationPath $newInstallationPath
			} 
		}
	}
}

Function Start-PGupgrade_Minor {
# Performs pg_upgrade for Minor Version
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$oldPath,
		[Parameter(Mandatory=$true)]
        [string]$newPath
	)
	$logger.logInfo("Updating data files. Do not close the command line window.", $True)
	$pass = ConvertTo-SecureString $tempPassword -AsPlainText -Force
	if ( -not (Get-LocalUser | Where-Object {$_.Name -eq $tempUser})) {
			New-LocalUser -Name $tempUser -Description "Account used for Postgresql upgrade" -Password $pass | Out-Null
		}
	if ( -not ((Get-LocalGroupMember "Administrators").Name -contains "$env:COMPUTERNAME\$tempUser")) {
		Add-LocalGroupMember -Group "Administrators" -Member $tempUser | Out-Null
	}
	$rule = new-object System.Security.AccessControl.FileSystemAccessRule ($tempUser,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
	Perform-Prerequisites $oldPath $rule
	#Perform-Prerequisites $newPath $rule
	$acl = Get-ACL $scriptDirectory
	$acl.SetAccessRule($rule)
	Set-ACL -Path $scriptDirectory -AclObject $acl
	$cred = new-object System.Management.Automation.PSCredential $tempUser,$pass
	$oldPathCmd = ($oldPath -replace "\\","/")
	$newPathCmd = ($newPath -replace "\\","/")
	Start-Process -FilePath "$newPath\bin\pg_upgrade.exe" -Wait -ArgumentList "--old-datadir `"$oldPathCmd/data`" --new-datadir `"$newPathCmd/data`" --old-bindir `"$oldPathCmd/bin`" --new-bindir `"$newPathCmd/bin`"" -RedirectStandardOutput "$logDir\pg_upgrade_log.log" -Credential $cred -NoNewWindow
	((Get-Content -path "$newPath\data\postgresql.conf") -replace '5433','5432') | Set-Content -Path "$newPath\data\postgresql.conf"
	$logger.logInfo("Data file update completed.", $True)
}


Function Stop-Services {
# Stops postgres service and the netan services
	$logger.logInfo("Stopping all the services.", $False)
	$serviceList = "*postgresql-x64*","Tss*","WpNmRemote*"
	foreach ($service in $serviceList) {
		$serviceNames = (Check-ServiceExists $service)[1]
		foreach ($serviceName in $serviceNames) {
			$result = Stop-SpotfireService $serviceName
		}
	}
	#kill the node manager processes if they are still running
    foreach ($proc in (Get-Process | Where {$_.Path -Like "*C:\Ericsson\NetAnServer\NodeManager*"}).Id) {
		taskkill /F /PID $proc 2>&1 | Out-Null
	}
}

Function Start-NetAnServices {
# Starts netan services
	$logger.logInfo("Starting NetAn services.", $False)
	$serviceList = "Tss*","WpNmRemote*"
	foreach ($service in $serviceList) {
		$serviceNames = (Check-ServiceExists $service)[1]
		foreach ($serviceName in $serviceNames) {
			if ($serviceName -ne "TSSS711StatisticalServices711"){
				$result = Start-SpotfireService $serviceName 
			}
		}
	}
}

Function Start-Rollback {
# Performs rollback in case upgrade fails
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$oldPath,
		[Parameter(Mandatory=$true)]
        [string]$newPath
	)
	cmd /c "$newPath\uninstall-postgresql.exe" --mode unattended
	Remove-Item -Path "$newPath" -Force -Recurse
	if (Test-Path "$oldPath\data\pg_hba.conf.backup") {
		Remove-Item -Path "$oldPath\data\pg_hba.conf"
		Rename-Item "$oldPath\data\pg_hba.conf.backup" "pg_hba.conf"
	}
	if (Get-LocalUser | Where-Object {$_.Name -eq $tempUser}) {
		Remove-LocalUser -Name $tempUser | Out-Null
	}
	Clean-Up
	Start-Service "*postgres*" -ErrorAction stop -WarningAction SilentlyContinue
	Start-NetAnServices
}

Function Uninstall-OldPostgres {
# Performs uninstallation of old postgres version after upgrade
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$oldPath
	)
	try {
		cmd /c "$oldPath\uninstall-postgresql.exe" --mode unattended
		$logger.logInfo("Old PostgreSQL version is uninstalled.", $True)
		Start-Sleep -s 10
		Remove-Item -Path "$oldPath" -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
		if (Test-Path $oldPath) {
			$logger.logInfo("Could not delete old PostgreSQL files. Please delete the folder $oldPath manually.", $True)
		}
	} catch {
		$logger.logError($MyInvocation,"Could not uninstall old PostgreSQL version.", $True)
	} 
}

Function Start-PGupgrade {
# Performs pg_upgrade
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$oldPath,
		[Parameter(Mandatory=$true)]
        [string]$newPath
	)
	$logger.logInfo("Updating data files. Do not close the command line window.", $True)
	$pass = ConvertTo-SecureString $tempPassword -AsPlainText -Force
	if ( -not (Get-LocalUser | Where-Object {$_.Name -eq $tempUser})) {
			New-LocalUser -Name $tempUser -Description "Account used for Postgresql upgrade" -Password $pass | Out-Null
		}
	if ( -not ((Get-LocalGroupMember "Administrators").Name -contains "$env:COMPUTERNAME\$tempUser")) {
		Add-LocalGroupMember -Group "Administrators" -Member $tempUser | Out-Null
	}
	$rule = new-object System.Security.AccessControl.FileSystemAccessRule ($tempUser,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
	Perform-Prerequisites $oldPath $rule
	Perform-Prerequisites $newPath $rule
	$acl = Get-ACL $scriptDirectory
	$acl.SetAccessRule($rule)
	Set-ACL -Path $scriptDirectory -AclObject $acl
	$cred = new-object System.Management.Automation.PSCredential $tempUser,$pass
	$oldPathCmd = ($oldPath -replace "\\","/")
	$newPathCmd = ($newPath -replace "\\","/")
	Start-Process -FilePath "$newPath\bin\pg_upgrade.exe" -Wait -ArgumentList "--old-datadir `"$oldPathCmd/data`" --new-datadir `"$newPathCmd/data`" --old-bindir `"$oldPathCmd/bin`" --new-bindir `"$newPathCmd/bin`"" -RedirectStandardOutput "$logDir\pg_upgrade_log.log" -Credential $cred -NoNewWindow
	((Get-Content -path "$newPath\data\postgresql.conf") -replace '5433','5432') | Set-Content -Path "$newPath\data\postgresql.conf"
	$logger.logInfo("Data file update completed.", $True)
}

Function Analyze-Cluster {
# Analyzes internal statistics - useful for optimizing query
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$path
	)
	$logger.logInfo("Analyzing new cluster.", $True)
	Start-Process -FilePath "$path\bin\vacuumdb.exe" -Wait -ArgumentList "--all --analyze-in-stages -U postgres" -RedirectStandardOutput "$logDir\analyze_new_cluster_log.log" -NoNewWindow
}

Function Verify-Upgrade {
# Checks if postgres upgrade is successful
	Param
	(
        [Parameter(Mandatory=$true)]
        [string]$pass,
		[Parameter(Mandatory=$true)]
        $serviceDetails
	)
	$logger.logInfo("Verifying upgrade.", $True)
	$errorFlag = 0
	if($serviceDetails[0]){
		$newPostgresService = $serviceDetails[1]
		$installedVersion = (Invoke-UtilitiesSQL -Database postgres -Username postgres -Password $pass -ServerInstance localhost -Query "SHOW server_version" -Action fetch).server_version
		if($installedVersion -eq $targetVersion){
			$db_in_server = (Invoke-UtilitiesSQL -Database postgres -Username postgres -Password $pass -ServerInstance localhost -Query "SELECT datname FROM pg_database" -Action fetch).datname
			Foreach ($db in $netan_db_list) {
				if ( -not $db_in_server.contains($db)) {
					$errorFlag = $errorFlag + 1
				}
			}
		} else {
			$errorFlag = $errorFlag + 1
		}
	} else {
		$errorFlag = $errorFlag + 1
	}
	if($errorFlag -eq 0) {
		$logger.logInfo("Verfication completed. Upgrade is successful.", $True)
		return $True
	} else {
		return $False
	}
}

Function Major-Upgrade {
# Performs major version upgrade
	$installedVersion = Get-PostgresVersion
	$targetVesrion = Get-TargetVersion
	$installedVersionDB = Get-PostgresVersionDB
	$adminPassword = $installParams.sqladminpassword
	$targetMajorVersion = ($targetVersion.Split("."))[0]
	$oldInstallationPath = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).InstallLocation
	if ( -not (Verify-Password $adminPassword)) {
		$logger.logError($MyInvocation, "Incorrect password or the PostgreSQL service is not running.", $True)
		Exit
	} else {
		$confirmation = $installParams.PostgresBkpConfirmation
		if ($confirmation -ne "y" -and $confirmation -ne "n") {
			$logger.logError($MyInvocation, "Invalid input.", $True)
			Clean-Up
		} else {
			try {
				if($confirmation -eq "y") {
					Take-Backup $adminPassword
				}
				$logger.logInfo("", $True)
				$logger.logInfo("------------------------------------------------------", $True)
				$logger.logInfo("|         Starting PostgreSQL installation", $True)
				$logger.logInfo("|", $True)
				$logger.logInfo("------------------------------------------------------", $True)
				$logger.logInfo("", $True)
				Install-Postgres $adminPassword 5433
				Stop-Services
				$newInstallationPath = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres* | Where-Object {$_.MajorVersion -like $targetMajorVersion}).InstallLocation
				Start-PGupgrade $oldInstallationPath $newInstallationPath
				$serviceDetails = Check-ServiceExists "*postgresql-x64*$targetMajorVersion*"
				Restart-PostgresService $serviceDetails[1]
				Analyze-Cluster $newInstallationPath
				if (Verify-Upgrade $adminPassword $serviceDetails) {
					Remove-Item -Path "$newInstallationPath\data\pg_hba.conf"
					Rename-Item "$newInstallationPath\data\pg_hba.conf.backup" "pg_hba.conf"
					Update-Configuration $newInstallationPath $serviceDetails[1]
					Start-NetAnServices
					if([int]($targetVesrion.Split(".")[0]) -gt $installedVersion[0]) {
						Uninstall-OldPostgres $oldInstallationPath
					}
				} else {
					$logger.logError($MyInvocation, "PostgreSQL upgrade failed. Starting rollback.", $True)
					Start-Rollback $oldInstallationPath $newInstallationPath
				}
			} catch {
				$logger.logError($MyInvocation, "PostgreSQL upgrade failed. Starting rollback.", $True)
				Start-Rollback $oldInstallationPath $newInstallationPath
			} 
		}
	}
}

Function Upgrade-Postgres {
# Upgrades postgres server and ODBC driver
	$installedVersion = Get-PostgresVersion
	$targetVesrion = Get-TargetVersion
	$installedVersionDB = Get-PostgresVersionDB
	if([int]($targetVesrion.Split(".")[0]) -gt $installedVersion[0]) {
		Major-Upgrade
	} elseif(([int]($targetVesrion.Split(".")[0]) -eq $installedVersion[0]) -and ([int]($targetVesrion.Split(".")[1]) -gt [int]($installedVersionDB.Split(".")[1]))){
		Minor-Upgrade
	} else {
		$logger.logInfo("Same or higher version of PostgreSQL server is already installed.`n", $True)
	}
	$logger.logInfo("Installing PostgreSQL ODBC driver.", $True)
	$driverInstallation = Upgrade-ODBCDriver
	if($driverInstallation[0]){
		$logger.logInfo($driverInstallation[1], $True)
	} else {
		$logger.logError($MyInvocation, $driverInstallation[1], $True)
	}
	Clean-EnvPath
}

Function InitialInstall-Postgres($installParams) {
# Performs initial installation 
	$adminPassword = $installParams.sqladminpassword
	try {
		$result = Install-ODBCDriver
		Install-Postgres $adminPassword 5432
		$serviceName = (Check-ServiceExists "*postgresql-x64*")[1]
		$installationPath = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres* | Select InstallLocation).InstallLocation
		if ($serviceName) {
			if (Test-ServiceRunning $serviceName) {
				$logger.logInfo("PostgreSQL service is running.", $True)
				Update-Configuration $installationPath $serviceName
				if ($result[0]){
					$logger.logInfo($result[1], $True)
				} else {
					$logger.logError($MyInvocation, $result[1], $True)
				}
			} else {
				$logger.logError($MyInvocation, "PostgreSQL service is not running.", $True)
			}
		}
	} catch {
		$logger.logError($MyInvocation, "PostgreSQL installation failed.", $True)
	} finally {
		Clean-Up
	}
}

#Main

$modulesDir = "C:\Ericsson\tmp\Scripts\modules"
$originalEnvPath = $env:PSModulePath
$env:PSModulePath = $modulesDir + ";" + $env:PSModulePath

Import-Module Logger
<# if (Get-Module -Name NetAnServerUtility) { #there is an update in this module which is necessary for this script to work
	Remove-Module NetAnServerUtility
	Set-ItemProperty -Path "C:\Ericsson\NetAnServer\Modules\NetAnServerUtility\NetAnServerUtility.psm1" -Name IsReadOnly -Value $false | Out-Null
	Copy-Item -Path $modulesDir\NetAnServerUtility\NetAnServerUtility.psm1 -Destination "C:\Ericsson\NetAnServer\Modules\NetAnServerUtility\" -force | Out-Null
} #>
Import-Module NetAnServerUtility
Import-Module ZipUnZip -DisableNameChecking

#$global:logger = Get-Logger("postgres_installation")
$logger = Get-Logger("postgres_installation")
$installerDirectory = "C:\Ericsson\tmp\Software\"
$scriptDirectory = "C:\Ericsson\tmp\Scripts\postgresql"
$backupScriptDirectory = "C:\Ericsson\tmp\Scripts\migration"
$resourceDirectory = "C:\Ericsson\tmp\Resources\postgresql"
$logDir = "C:\Ericsson\NetANServer\logs"
$targetVersion = Get-TargetVersion
$netan_db_list = "netanserver_db","netanserveractionlog_db","netanserver_repdb"
$tempUser = "postgres"
$tempPassword = "TempAccount#01"

if ((Check-ServiceExists "*postgresql-x64*")[0]) {
	$logger.setLogDirectory("C:\Ericsson\NetANServer\logs\")
	Upgrade-Postgres	
} else {
	$logger.setLogDirectory("C:\Ericsson\tmp\")
	InitialInstall-Postgres $installParams
}
#Clear-Variable -Name $logger