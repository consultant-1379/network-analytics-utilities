Import-Module Logger

Function InstallPMData($installP){
	$deployDir = $installP.deployDir
	$deployPMDataDir = $installP.deployPMDataDir
	$PMDataResourcesDir = $installP.PMDataResourcesDir
	$PMDataPackage = $installP.PMDataPackage
	if ( -not (Test-Path -Path $deployDir\$PMDataPackage.zip)) {
        $logger.logError($MyInvocation, "$($PMDataPackage) package not found at $($deployDir). `n", $True)
		return $False
    }
	if(Test-Path -Path $deployPMDataDir){
		$logger.logInfo("Removing $($deployPMDataDir) folder",$True)
		Remove-Item $deployPMDataDir -Force -ErrorAction SilentlyContinue -Confirm:$false -Recurse
	}
	$logger.logInfo("Unzipping the $($PMDataPackage) package",$True)
	$status = Unzip-File $deployDir\$PMDataPackage.zip $deployPMDataDir
	if($status -eq $False){
		$logger.logInfo("Successfully unzipped $PMDataPackage")
		return $False
	}
	$logger.logInfo("Installing $PMDataPackage",$True)
	$currLocation = Get-Location
	Set-Location $PMDataResourcesDir
	& .\Pre-Installation.ps1 install
	$status = Install-Feature $deployPMDataDir\feature.zip -force
	if($status -eq $True){
		set-Location $currLocation
		$logger.logInfo("Successfully installed $PMDataPackage",$True)
		return $True
	}
	else{
		$logger.logError("$PMDataPackage installation failed",$False)
		return $False
	}
}
 
 Function updateCustomLibrary(){
	$NetAnPlatformPassword = $installP.NetAnPlatformPassword
	$ConfigbatDir = $installP.ConfigbatDir 
	$LogDir = $installP.LogDir
	if ( -not (Test-Path -Path $ConfigbatDir\config.bat)) {
        $logger.logError($MyInvocation, "config.bat File not found at $($ConfigbatDir). `n", $True)
		return $False
     }
	 $logger.logInfo("Updating CustomLibrary",$True)
	cmd /C "$ConfigbatDir\config.bat find-analysis-scripts -t $NetAnPlatformPassword -d true -s true -q true --library-parent-path=`"/Custom Library/`" $LogDir"
	$logger.logInfo("Successfully updated CustomLibrary",$True)
	return $True
}

Function hsts($installP){
	$ConfigbatDir = $installP.ConfigbatDir
	$PlatformPassword = $installP.NetAnPlatformPassword
	$PlatformVersion = $installP.PlatformVersion
		if ( -not (Test-Path -Path $ConfigbatDir)) {
			
        $logger.logError($MyInvocation, "config.bat File not found at $($ConfigbatDir). `n", $True)
		return $False
     }
	 $currLocation = Get-Location
	 set-Location $ConfigbatDir
	 $logger.logInfo("Exporting config.bat file",$True)
	 ./config.bat export-config --force -t $PlatformPassword
	 $logger.logInfo("Updating security.hsts.max-age-seconds in config.bat file",$True)
	 ./config.bat set-config-prop -n security.hsts.max-age-seconds -v 31536000
	 $logger.logInfo("Importing config.bat file",$True)
	 ./config.bat import-config -c "Enabled HSTS" -t $PlatformPassword
	 Restart-Service Tss$PlatformVersion
	 set-Location $currLocation
	 return $True
}

Function InstallPMExplorer($installP){
	$PMExplorerPackage = $installP.PMExplorerPackage
	$deployDir = $installP.deployDir
	if ( -not (Test-Path -Path $deployDir\$PMExplorerPackage.zip)) {
        $logger.logError($MyInvocation, "$($PMExplorerPackage) package not found at $($deployDir). `n", $True)
		return $False
     }
	 $logger.logInfo("Installing $PMExplorerPackage",$True)
	 $status = Install-Feature $deployDir\$PMExplorerPackage.zip -force
	if($status -eq $True)
	{
		$logger.logInfo("Successfully installed $PMExplorerPackage",$True)
		return $True
	}
	else{
		$logger.logError("$($PMExplorerPackage) installation failed",$False)
		return $False
	}
}

Function InstallPMAlarm($installP){
	$PMAlarmPackage = $installP.PMAlarmPackage
	$deployDir = $installP.deployDir
	if ( -not (Test-Path -Path $deployDir\$PMAlarmPackage.zip)) {
        $logger.logError($MyInvocation, "$($PMAlarmPackage) package not found at $($deployDir). `n", $True)
		return $False
     }
	 $logger.logInfo("Installing $PMAlarmPackage",$True)
	$status = Install-Feature $deployDir\$PMAlarmPackage.zip -force
	if($status -eq $True){
		$logger.logInfo("Successfully installed $PMAlarmPackage",$True)
		return $True
	}
	else{
		$logger.logError("$($PMAlarmPackage) installation failed" ,$False)
		return $False
	} 
}

Function XcontentType($installP){
	$ConfigbatDir = $installP.ConfigbatDir
	$PlatformPassword = $installP.NetAnPlatformPassword
	$PlatformVersion = $installP.PlatformVersion
		if ( -not (Test-Path -Path $ConfigbatDir)) {
			
        $logger.logError($MyInvocation, "config.bat File not found at $($ConfigbatDir). `n", $True)
		return $False
     }
	 $currLocation = Get-Location
	 set-Location $ConfigbatDir
	 $logger.logInfo("Exporting config.bat file", $True)
	 ./config.bat export-config --force -t $PlatformPassword
	 $logger.logInfo("Updating x-content-type-options in config.bat file", $True)
	 ./config.bat set-config-prop -n security.x-content-type-options.enabled -v false
	 $logger.logInfo("Importing config.bat file",$True)
	 ./config.bat import-config -c "Disabled X-Content-Type-Options" -t $PlatformPassword
	 Restart-Service Tss$PlatformVersion
	 set-Location $currLocation
	 return $True
}

Function addDomainToTrustedSites($installP){
	Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -name 'SecureProtocols' -value '0x00000800' -Type DWord
	$url = $installP.hostAndDomainURL
	#write-host $url
    $httpType=.{[void]($url -match '^(https{0,1})');$matches[1]}
    $domain=([uri]$url).Host
    $rootDomain = $domain
    $dwordValue=2 # value of true correlates to 'enable'
    $domainRegistryPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains'
     
    if (!(test-path "$domainRegistryPath\$rootDomain")){$null=New-Item -Path "$domainRegistryPath" -ItemType File -Name "$rootDomain"}
    $null=Set-ItemProperty -Path "$domainRegistryPath\$rootDomain" -Name $httpType -Value $dwordValue
    $valueAfterChanged=(Get-ItemProperty "$domainRegistryPath\$rootDomain")."$httpType"
    if ($valueAfterChanged -ne 2){
        $logger.logInfo( "$rootDomain has NOT been added to Internet Options",$True)
        return $False
    }
    else{
		$domainRegistryPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains'
		if(test-path "$domainRegistryPath") {
			if (!(test-path "$domainRegistryPath\$rootDomain")){$null=New-Item -Path "$domainRegistryPath" -ItemType File -Name "$rootDomain"}
			$null=Set-ItemProperty -Path "$domainRegistryPath\$rootDomain" -Name $httpType -Value $dwordValue
			$valueAfterChanged=(Get-ItemProperty "$domainRegistryPath\$rootDomain")."$httpType"
			if ($valueAfterChanged -eq 2){
				$logger.logInfo( "$rootDomain has been added to Internet Options",$True)
				return $True
			}
			else {
				$logger.logInfo( "$rootDomain has NOT been added to Internet Options",$True)
				return $False
			}
		}
		else {
			$logger.logInfo( "$rootDomain has been added to Internet Options",$True)
			return $True
		}
    
    }
}


Function EnableSSOServer($installP){
	#$PlatformPassword = $installP.PlatformPassword
	#$ServiceAccPwd = $installP.ssoServiceAccountPassword
	$SSODir = $installP.SSOScriptDir
	$configEnable = $installP.SSOScriptDir + "\sso-config-enable.txt" #change according to backup files location
	$configReEnable = $installP.SSOScriptDir + "\sso-config-Re-enable.txt"
	if ( -not (Test-Path -Path $configEnable)) {
        $logger.logError($MyInvocation, " configEnable File not found at $($configEnable). `n", $True)
		return $False
    }
	$logger.logInfo("Collecting Required values from $ConfigEnable",$True)
	$configContent = (Get-Content $configEnable)
	 
	$netanFQDN = ($configContent | Select-String "set NETAN_FQDN").Line
	$adFQDN = ($configContent | Select-String "set AD_FQDN").Line
	$adCONTEXT = ($configContent | Select-String "set AD_CONTEXT").Line
	$adDomain = ($configContent | Select-String "set AD_DOMAIN").Line
	$adHost = ($configContent | Select-String "set AD_HOSTNAME").Line
	$ssoServer = ($configContent | Select-String "set SERVICE_ACCOUNT =").Line
	$enmLauncher = ($configContent | Select-String "set ENM_LAUNCHER_FQDN").Line
	$logger.logInfo("Successfully collected required values from $ConfigEnable", $True)
	 
	$reConfigContent = (Get-Content $configReEnable)
	 
	$netanFQDN_re = ($reConfigContent | Select-String "set NETAN_FQDN").Line
	$adFQDN_re = ($reConfigContent  | Select-String "set AD_FQDN").Line
	$adCONTEXT_re = ($reConfigContent  | Select-String "set AD_CONTEXT").Line
	$adDomain_re = ($reConfigContent  | Select-String "set AD_DOMAIN").Line
	$adHost_re = ($reConfigContent  | Select-String "set AD_HOSTNAME").Line
	$ssoServer_re = ($reConfigContent  | Select-String "set SERVICE_ACCOUNT =").Line
	$enmLauncher_re = ($reConfigContent  | Select-String "set ENM_LAUNCHER_FQDN").Line
	 $logger.logInfo("Updating required values in $ConfigReEnable", $True)
	if(($netanFQDN_re) -and ($netanFQDN)) 
	{
	$reConfigContent = $reConfigContent.replace($netanFQDN_re, $netanFQDN)
	}
	else{
	Exit
	}
	if (($adFQDN_re) -and ($adFQDN)) 
	{
	$reConfigContent = $reConfigContent.replace($adFQDN_re, $adFQDN)
	}
	else{
	Exit
	}
	if (($adCONTEXT_re) -and ($adCONTEXT))
	{
	$reConfigContent = $reConfigContent.replace($adCONTEXT_re, $adCONTEXT)
	}
	else{
	Exit
	}
	if (($adDomain_re) -and ($adDomain)) 
	{
	$reConfigContent = $reConfigContent.replace($adDomain_re, $adDomain)
	}
	else{
	Exit
	}
	if (($ssoServer_re) -and ($ssoServer)) 
	{
	$reConfigContent = $reConfigContent.replace($ssoServer_re, $ssoServer)
	}
	else{
	Exit
	}
	if (($enmLauncher_re) -and ($enmLauncher)) 
	{
	$reConfigContent = $reConfigContent.replace($enmLauncher_re, $enmLauncher)
	}
	else{
	Exit
	}
	Set-Content -Path $configReEnable -Value $reConfigContent
	$logger.logInfo("Successfully updated required values in $ConfigReEnable", $True)
	$logger.logInfo("Re-Enabling SSO")
	$currLocation = Get-Location
	Set-Location $SSODir
	$status = & .\ConfigureNetAnSSO.ps1 Re-enable $installP
	if($status -eq $True){
	return $True
	}
	else{
	return $False
	}
	return $True
 
}

Function RestorePMData($installP){
	$deployDir = $installP.deployDir
	$deployPMDataDir = $installP.deployPMDataDir
	$PMDataResourcesDir = $installP.PMDataResourcesDir
	$PMDataPackage = $installP.PMDataPackage
	if(Test-Path -Path $deployPMDataDir){
		$logger.logInfo("Removing $($deployPMDataDir) folder",$True)
		Remove-Item $deployPMDataDir -Force -ErrorAction SilentlyContinue -Confirm:$false -Recurse
	}
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
		$logger.logInfo("PMData restore started",$True)
     $status = . $PMDataResourcesDir\PmDB_Backup_Restore.ps1 Restore
	set-Location $currLocation
	if($status -eq $True){
		return $True
	}
	else{
		return $False
	}
}
	
Export-ModuleMember -Function * -Alias *