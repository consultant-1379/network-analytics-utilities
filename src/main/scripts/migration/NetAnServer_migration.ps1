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
# Name    : NetAnServer_migration.ps1
# Date    : 11/08/2021
# Revision: 1.0
# Purpose : To backup or restore netan database content during hardware or OS migration
# 
# Usage   :  .\NetAnServer_migration.ps1 <backup|restore>
#
#---------------------------------------------------------------------------------

#Main

Import-Module Logger

$logger = Get-Logger($LoggerNames.Install)
$logger.setLogDirectory("C:\Ericsson\NetANServer\logs\")
$postgresBackupLocation = "C:\Ericsson\Backup\postgresql_backup"

if ($args[0] -eq "backup") {
	if (Get-Service -Name "*postgresql-x64*"-ErrorAction Stop) {
		$logger.logInfo("PostgreSQL service found in the server.", $True)
		& "$PSScriptRoot\NetAnServer_migration_backup_postgresql.ps1"
	} else {
		$logger.logInfo("PostgreSQL service not found. Starting MSSQL backup.", $True)
		& "$PSScriptRoot\NetAnServer_migration_backup.ps1"
	}
} elseif ($args[0] -eq "restore") {
	if (Test-Path $postgresBackupLocation) {
		$logger.logInfo("PostgreSQL backup found in the server.", $True)
		& "$PSScriptRoot\NetAnServer_migration_restore_postgresql.ps1" 
	} else {
		$logger.logInfo("PostgreSQL backup not found. Starting to restore MSSQL backup.", $True)
		& "$PSScriptRoot\NetAnServer_migration_restore.ps1"
	}
} else {
	$logger.logError($MyInvocation, "Invalid argument.", $True)
}
	

