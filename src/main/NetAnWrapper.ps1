
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
# Name    : DeployNetAnUtilities.ps1
# Date    : 27/07/2021
# Revision: 1.0
# Purpose : To copy the content of network analytics utilities package to server
#			and install postgresql if needed.
# 
# Usage   :  .\DeployNetAnUtilities.ps1 (To copy the files from media to C:\Ericsson\tmp)
#			  DeployNetAnUtilities.ps1 InstallPostgresql (To install/upgrade postgresql)
#			  DeployNetAnUtilities.ps1 BackupNetAnDB (To backup netan db)
#			  DeployNetAnUtilities.ps1 RestoreNetAnDB (To restore netan db)
# Return Values: None
#
#---------------------------------------------------------------------------------

#Set-ExecutionPolicy -ExecutionPolicy Bypass -Force

$deployDir = "C:\Ericsson\tmp"
if((Test-Path($($deployDir+"\Resources")))){
     Get-ChildItem $($deployDir+"\Resources") -Recurse | Remove-Item -Force -Recurse
     Remove-Item $($deployDir+"\Resources") -Recurse
}
if((Test-Path($($deployDir+"\Scripts")))){
     Get-ChildItem $($deployDir+"\Scripts") -Recurse | Remove-Item -Force -Recurse
     Remove-Item $($deployDir+"\Scripts") -Recurse
}

if (!(Test-Path $deployDir)) {
	New-Item $deployDir -type directory | Out-Null
}

Copy-Item -Path $PSScriptRoot\Software -Destination $deployDir -Recurse -Force
Copy-Item -Path $PSScriptRoot\Resources -Destination $deployDir -Recurse -Force
Copy-Item -Path $PSScriptRoot\Scripts -Destination $deployDir -Recurse -Force
attrib -r C:\Ericsson\tmp\* /s /d

if ($args[0] -eq "UpgradePostgreSQL") {
	$PassMatchedpsql = 'n'
	while ($PassMatchedpsql -ne 'y') {
         $EncryptedSqlAdminPassword = Read-Host -AsSecureString ("PostgreSQL Administrator Password:")
		 $sqlAdminPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $EncryptedSqlAdminPassword).GetNetworkCredential().Password
         $EncryptedResqlAdminPassword = Read-Host -AsSecureString("Confirm PostgreSQL Administrator Password:")
		 $resqlAdminPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $EncryptedResqlAdminPassword).GetNetworkCredential().Password
		 if($sqlAdminPassword -eq $resqlAdminPassword) {
			 $PassMatchedpsql = 'y'
		 }
		 else {
			Write-host "`nPassword doesn't match.`n"
			$PassMatchedpsql = 'n'
		 }
    }$PassMatchedpsql = 'n'
	
	$PostgresBkpConfirmation = 'n'
	$PostgreseDetails = Get-Service -Name "*postgresql-x64*" -ErrorAction SilentlyContinue
	if ($PostgreseDetails.Length -gt 0) {
		$PostgresBkpConfirmation = Read-host("Do you want to take a backup before PostgreSQL upgrade? Backup may take some time depending on the database size. `n(y/n):")
	}
	$installParams = @{}
	$installParams.Add('sqlAdminPassword', $sqlAdminPassword)
	$installParams.Add('PostgresBkpConfirmation', $PostgresBkpConfirmation)
	
	$currLocation = Get-Location
	Set-Location $deployDir\Scripts\postgresql
	& .\PostgresInstaller.ps1 $installParams
	Set-Location $currLocation
}
if ($args[0] -eq "BackupNetAnDB") {
	$currLocation = Get-Location
	Set-Location $deployDir\Scripts\migration
	& "$deployDir\Scripts\migration\NetAnServer_migration.ps1" backup
	Set-Location $currLocation
}
if ($args[0] -eq "RestoreNetAnDB") {
	$currLocation = Get-Location
	Set-Location $deployDir\Scripts\migration
	& "$deployDir\Scripts\migration\NetAnServer_migration.ps1" restore
	Set-Location $currLocation
}

if ($args[0] -eq "FQDNSwitch") {
	$currLocation = Get-Location
	Set-Location $deployDir\Scripts\FqdnSwitch
	& "$deployDir\Scripts\FqdnSwitch\FQDNSwitch.ps1"
	Set-Location $currLocation
}

if ($args[0] -eq "InstallNetAn") {
	$currLocation = Get-Location
	Set-Location $deployDir\Scripts\Install
	& "$deployDir\Scripts\Install\NetAnServer_install.ps1"
	Set-Location $currLocation
}

if ($args[0] -eq "UpgradeNetAn") {
	$currLocation = Get-Location
	Set-Location $deployDir\Scripts\Install
	& "$deployDir\Scripts\Install\NetAnServer_upgrade.ps1"
	Set-Location $currLocation
}

if ($args[0] -eq "ExtractServerMedia") {
	if(($args[1].length -lt 5) -or (($args[1].Substring($args[1].Length - 4)) -eq ".iso")) {
		Write-host -ForegroundColor red "`nInvalid Argument Passed !!"
		Write-host "Please try again with Appropriate Argument !!`n"
		Exit
	}
	$isoFilePath = "C:/temp/media/netanserver/$($args[1]).iso"
	$mounted = Get-DiskImage -ImagePath $isoFilePath | ForEach-Object { $_.Attached }
	if ($mounted) {
		# If it's already mounted, unmount it
		Dismount-DiskImage -ImagePath $isoFilePath
	}
	if((Test-Path ("C:\Ericsson\tmp\CompressedFiles"))){
        Get-ChildItem "C:\Ericsson\tmp\CompressedFiles" -Recurse | Remove-Item -Force -Recurse
        Remove-Item "C:\Ericsson\tmp\CompressedFiles" -Recurse
	}
	if((Test-Path ("C:\Ericsson\tmp\Modules"))){
        Get-ChildItem "C:\Ericsson\tmp\Modules" -Recurse | Remove-Item -Force -Recurse
        Remove-Item "C:\Ericsson\tmp\Modules" -Recurse
	}
	
	write-host("Started Automated Server Media Decryption")
	write-host("Preparing to Mount and Decrypt NetAn Server ISO :: $($args[1])")
	$NetAnServerISO = $args[1]
	$mountResult = Mount-DiskImage C:/temp/media/netanserver/$NetAnServerISO.iso -PassThru
	$driveLetter = ($mountResult | Get-Volume).DriveLetter
	$driveLetter = $driveLetter + ':'
	if(!($driveLetter)) {
		Write-host -ForegroundColor red "Unable to Mount $($NetAnServerISO)"
		Exit
	}
	write-host("NetAn Server ISO Media Mounted Successfully on $($driveLetter) Drive")
	write-host("Decryption Process Started")
	$currLocation = Get-Location
	$loc = $deployDir + "\Scripts\DecryptNetAn\"
	
	Set-Location $loc
	. $loc\NetAnServerAnsible.ps1 $driveLetter
	
	$DecryptedSoftwareLoc = $deployDir+"\Software"
	if(test-path -Path $DecryptedSoftwareLoc) {
    "analyst", "deployment", "server", "nodemanager", "languagepack" | ForEach-Object {
        $filePath = $_
			if (Test-Path -Path "$DecryptedSoftwareLoc\$filePath") {
				
			}
			else {
				Write-host "$DecryptedSoftwareLoc\$filePath is not found"
				Write-host -ForegroundColor red "Unable to Decrypt NetAn Server Media"
				DisMount-DiskImage C:/temp/media/netanserver/$NetAnServerISO.iso
				Set-Location $currLocation
				Exit
			}
		}
	}
	else {
		Write-host -ForegroundColor red "`Unable to Decrypt NetAn Server Media"
		DisMount-DiskImage C:/temp/media/netanserver/$NetAnServerISO.iso
		Set-Location $currLocation
		Exit
	}
	
	Write-host("Successfully Decrypted NetAn Server Media")
	DisMount-DiskImage C:/temp/media/netanserver/$NetAnServerISO.iso
	Write-host("Successfully Unmounted the NetAn Server Media ISO File")
	
	[xml]$xmlObj = Get-Content "$($deployDir)\Resources\version\supported_NetAnPlatform_versions.xml"
	$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")
	
	foreach ($platformVersionString in $platformVersionDetails)
	{
		if ($platformVersionString.'current' -eq 'y') {
            $serviceVersion = $platformVersionString.'service-version'
        }
	}
	
	$decryptFlagFile = $deployDir+"\$($serviceVersion)ExtractionFlagFile.txt"
	
	if(test-path -Path $decryptFlagFile) {
		Remove-Item $($decryptFlagFile)
	}
	Out-File -FilePath $decryptFlagFile | Out-Null
	Set-Location $currLocation
}

if ($args[0] -eq "UpgradeNetAn_Ansible") {
	$currLocation = Get-Location
	$DecryptedSoftwareLoc = $deployDir+"\Software"
	
	[xml]$xmlObj = Get-Content "$($deployDir)\Resources\version\supported_NetAnPlatform_versions.xml"
	$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")
	
	foreach ($platformVersionString in $platformVersionDetails)
	{
		if ($platformVersionString.'current' -eq 'y') {
            $serviceVersion = $platformVersionString.'service-version'
        }
	}
	
	$decryptFlagFile = $deployDir+"\$($serviceVersion)ExtractionFlagFile.txt"
	if( -not (Test-Path($decryptFlagFile))){
		Write-host "$decryptFlagFile not found"
		Write-host -ForegroundColor red "NetAn Server Media Not Decrypted Successfully!!"
		Exit
	}
	
	if(test-path -Path $DecryptedSoftwareLoc) {
    "analyst", "deployment", "server", "nodemanager", "languagepack" | ForEach-Object {
        $filePath = $_
			if (Test-Path -Path "$DecryptedSoftwareLoc\$filePath") {
				
			}
			else {
				Write-host "$DecryptedSoftwareLoc\$filePath is not found"
				Write-host -ForegroundColor red "NetAn Server Media Not Decrypted Successfully!!"
				Exit
			}
		}
	}
	else {
		Write-host -ForegroundColor red "`nNetAn Server Media Not Decrypted Successfully!!"
		Write-host -ForegroundColor red "`nPlease try again after Decryption is Successful !!"
		Exit
	}
	if($args.length -ne 9) {
		Write-host -ForegroundColor red "`nInvalid Arguments Passed !!"
		Write-host "Please try again with Appropriate Arguments !!`n"
		Exit
	}
	elseif((($args[5] -ne 'y') -and ($args[5] -ne 'n')) -or (($args[7] -ne 'False') -and ($args[7].length -lt 5) -or (($args[7].Substring($args[7].Length - 4)) -eq ".zip")) -or (($args[8] -ne 'y') -and ($args[8] -ne 'n'))) {
		Write-host -ForegroundColor red "`nInvalid Arguments Passed !!"
		Write-host "Please try again with Appropriate Arguments !!`n"
		Exit
	}
	Else {
		Set-Location $deployDir\Scripts\Install
		$ansibleParams = @{}
		$ansibleParams.Add('hostAndDomain', $args[1])
		$ansibleParams.Add('username', $args[2])
		$ansibleParams.Add('adminPassword', $args[3])
		$ansibleParams.Add('sqlAdminPassword', $args[4])
		$ansibleParams.Add('PostgresBkpConfirmation', $args[5])
		$ansibleParams.Add('certPassword', $args[6])
		$ansibleParams.Add('PMDataPackage', $args[7])
		$ansibleParams.Add('resumeConfirmation', $args[8])

		& "$deployDir\Scripts\Install\NetAnServer_upgrade_ansible.ps1" $ansibleParams
		Set-Location $currLocation
	}
}