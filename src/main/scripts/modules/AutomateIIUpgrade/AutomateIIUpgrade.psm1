# ********************************************************************
# Ericsson Radio Systems AB                                     MODULE
# ********************************************************************
#
#
# (c) Ericsson Radio Systems AB 2022 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Radio Systems AB, Sweden. The programs may be used 
# and/or copied only with the written permission from Ericsson Radio 
# Systems AB or in accordance with the terms and conditions stipulated 
# in the agreement/contract under which the program(s) have been 
# supplied.
#
# ********************************************************************
# Name    : Automate.psm1
# Date    : 08/12/2022
# Purpose : This contains generic automation functions that are used in
#           NetAn Installation and upgrade
#
#

#https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/export-modulemember?view=powershell-7.3
Import-Module Logger

function BackupNetAnDBUtilities($installP)
{
	$logger.logInfo("Starting Automated NetAn DB backup",$True)
	$NetAnUtilitiesISO = $installP.NetAnUtilitiesISO
	$mediaDir = $installP.mediaDir 
	if ( -not (Test-Path -Path $mediaDir\$NetAnUtilitiesISO.iso)) {
        $logger.logError($MyInvocation, "$($NetAnUtilitiesISO).iso not found at $($mediaDir). `n", $True)
		return $False
     }
	 
    $mountResult = Mount-DiskImage $mediaDir\$NetAnUtilitiesISO.iso -PassThru
    $driveLetter = ($mountResult | Get-Volume).DriveLetter
    $driveLetter = $driveLetter + ':'
    
    $currLocation = Get-Location
    if ( -not (Test-Path -Path $driveLetter\DeployNetAnUtilities.ps1)) {
        $logger.logError($MyInvocation, "DeployNetAnUtilities.ps1 File not found at $($driveLetter). `n", $True)
		return $False
     }
    Set-Location $driveLetter
    & .\DeployNetAnUtilities.ps1 BackupNetAnDB
    Set-Location $currLocation
    DisMount-DiskImage $mediaDir\$NetAnUtilitiesISO.iso -PassThru
    $logger.logInfo("Successfully completed Automated NetAn DB backup",$True)
    return $True
}

Function DecryptMediaServer($installP){
    $logger.logInfo("Started Automated Server Media Decryption",$True)
	$logger.logInfo("Preparing to Mount and Decrypt NetAn Server ISO :: $($installP.NetAnServerISO)",$True)
	$NetAnServerISO = $installP.NetAnServerISO
	$mountResult = Mount-DiskImage C:/temp/media/netanserver/$NetAnServerISO.iso -PassThru
	$driveLetter = ($mountResult | Get-Volume).DriveLetter
	$driveLetter = $driveLetter + ':'
	$logger.logInfo("NetAn Server ISO Media Mounted Successfully on $($driveLetter) Drive", $True)
	
	$logger.logInfo("Decryption Process Started", $True)
	$currLocation = Get-Location
	
	$loc = $installP.decryptNetAn
	Set-Location $loc
	. $loc\NetAnServer.ps1 $driveLetter
	
	$directoryInfo = Get-ChildItem $installP.mediaDir | Measure-Object
	if($directoryInfo.count -lt 5) {
		$logger.logError($MyInvocation, "Unable to Decrypt NetAn Server Media", $True)
		DisMount-DiskImage C:/temp/media/netanserver/$NetAnServerISO.iso
		Set-Location $currLocation
		return $False
	}
	
	$logger.logInfo("Successfully Decrypted NetAn Server Media", $True)
	DisMount-DiskImage C:/temp/media/netanserver/$NetAnServerISO.iso
	$logger.logInfo("Successfully Unmounted the NetAn Server Mediqa ISO File", $True)
	Set-Location $currLocation
	return $True
}

Function UpgradeNetAnServer($installP) {
    $logger.logInfo("Started Automated upgrade of NetAn Server",$True)
	$deployDir = $installP.deployDir
	$softwareDir = $installP.softwareDir
	$deployInstallDir = $installP.deployInstallDir
    if ( -not (Test-Path -Path $softwareDir )) {
        $logger.logError($MyInvocation, "Server media not decrypted. Server media not found at $($deployDir). `n", $True)
		return $False
     }
    $currLocation = Get-Location
	#& .\NetAnServer_Install.ps1 $installP
    if ( -not (Test-Path -Path $deployInstallDir\NetAnServer_upgrade.ps1 )) {
        $logger.logError($MyInvocation, "NetAnServer_upgrade.ps1 File not found at $($deployInstallDir). `n", $True)
		return $False
     }
    Set-Location $deployInstallDir
	. $deployInstallDir\NetAnServer_upgrade.ps1
    Set-Location $currLocation
    $logger.logInfo("Successfully completed Automated upgrade of NetAn Server",$True)
    return $True
}

#Remove-Item C:\Ericsson\tmp\pmdata -Force -ErrorAction SilentlyContinue
#Unzip-File C:\Ericsson\tmp\network-analytics-pm-data-R3A114.zip C:\Ericsson\tmp\pmdata
#C:\Ericsson\tmp\pmdata\resources\PmDB_Backup_Restore.ps1 backup

Function BackupPMData($installP){
	$logger.logInfo("Starting Automated PMData backup",$True)
	$deployDir = $installP.deployDir
	$deployPMDataDir = $installP.deployPMDataDir
	$PMDataResourcesDir = $installP.PMDataResourcesDir
	$PMDataPackage = $installP.PMDataPackage
	
	if ( -not (Test-Path -Path $deployDir\$PMDataPackage.zip)) {
        $logger.logError($MyInvocation, "$($PMDataPackage) package not found at $($deployDir). `n", $True)
		return $False
     }
	$logger.logInfo("Removing $($deployPMDataDir) folder",$True)
	Remove-Item $deployPMDataDir -Force -ErrorAction SilentlyContinue -Confirm:$false -Recurse
	$logger.logInfo("Unzipping the $($PMDataPackage) package",$True)
    Unzip-File $deployDir\$PMDataPackage.zip $deployPMDataDir
    $currLocation = Get-Location
    if ( -not (Test-Path -Path $PMDataResourcesDir\PmDB_Backup_Restore.ps1)) {
        $logger.logError($MyInvocation, "PmDB_Backup_Restore.ps1 File not found at $($PMDataResourcesDir). `n", $True)
		return $False
    }
	$file = $PMDataResourcesDir +"\PmDB_Backup_Restore.ps1"
	Set-ItemProperty $file -name IsReadOnly -value $false
	$search = "`$global:logger = Get-Logger(`$LoggerNames.Install)"
	$replace = "`$logger = Get-Logger(`"backup`")"
	(Get-Content $file).replace($search, $replace) | Set-Content $file
	Set-Location $deployDir
    . $PMDataResourcesDir\PmDB_Backup_Restore.ps1 backup
    Set-Location $currLocation
    $logger.logInfo("Successfully completed Automated PMData backup",$True)
    return $True
}

Function DisableSSOServer($installP) {
    $logger.logInfo("Started Automated disabling of SSO on NetAn Server",$True)
	$deploySSODir = $installP.deploySSODir
	$scriptsDir = $installP.scriptsDir
	$SSOScriptDir = $installP.SSOScriptDir
    $currLocation = Get-Location
    if ( -not (Test-Path -Path $deploySSODir )) {
        $logger.logError($MyInvocation, "SSO Scripts not found at $($deploySSODir). `n", $True)
		return $False
     }
    if ( -not (Test-Path -Path $SSOScriptDir\ConfigureNetAnSSO.ps1 )) {
        $logger.logError($MyInvocation, "ConfigureNetAnSSO.ps1 File not found at $($SSOScriptDir). `n", $True)
		return $False
     }
    Set-Location $SSOScriptDir
	$status = & .\ConfigureNetAnSSO.ps1 disable $installP
	if($status -eq $True)
	{
		$logger.logInfo("Successfully completed Automated disabling of SSO on NetAn Server",$True)
		return $True
	 
	 }
	 else{
	 return $False
	 }
}

Export-ModuleMember -Function * -Alias *