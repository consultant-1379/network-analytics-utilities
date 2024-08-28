Import-Module NetAnServerUtility
$installPa =@{}
Function DisableSSO(){
	   $envVariable = "NetAnVar"
	   
        while ($PassMatchedplat -ne 'y') {
			$platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
            $replatformPassword = hide-Password("Network Analytics Server Platform Password:`n")
            #$PassMatchedplat = confirm-password $platformPassword $replatformPassword
			if($platformPassword -ne $replatformPassword){
				write-host "Incorrect Platform Password. Please Re-enter. `n"
				$PassMatchedplat = 'n'
			}
			else{
				$PassMatchedplat = 'y'
			}
		}$PassMatchedplat = 'n'
			
		$installPa.Add('dbPassword' , $platformPassword)
}
Function EnableSSO(){
	$configEnable = "C:\Ericsson\NetAnServer\Scripts\sso\sso-config-enable.txt"
    $envVariable = "NetAnVar"
		while ($PassMatchedplat -ne 'y') {
			$platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
            $replatformPassword = hide-Password("Enter Network Analytics Server Platform Password:`n")
            #$PassMatchedplat = confirm-password $platformPassword $replatformPassword
			if($platformPassword -ne $replatformPassword){
				write-host "Incorrect Platform Password. Please Re-enter. `n"
				$PassMatchedplat = 'n'
			}
			else{
				$PassMatchedplat = 'y'
			}
			}$PassMatchedplat = 'n'
		while ($PassMatchedSSO -ne 'y'){
			$servAcc = (Get-Content $configEnable | Select-String "set SERVICE_ACCOUNT").Line.split("=")[1].replace("""","").trim()
			$ssoServiceAccountPassword = hide-password("Enter password for the SSO Serviceaccount $servAcc :`n")
			$ressoServiceAccountPassword = hide-password("Confirm password for the SSO Serviceaccount $servAcc :`n")
			$PassMatchedSSO = confirm-password $ssoServiceAccountPassword $ressoServiceAccountPassword
			}$PassMatchedSSO = 'n'
			
		$installPa.Add('dbPassword' , $platformPassword)
		$installPa.Add('ssoServiceAccountPassword' , $ssoServiceAccountPassword)
        }
if($args -eq "disable")
{
	DisableSSO
	Set-Location C:\Ericsson\NetAnServer\Scripts\sso
	$status = & .\ConfigureNetAnSSO.ps1 disable $installPa
	if($status -eq $True){
	return $True
	}
	else{
	return $False
	}
}
if($args -eq "re-enable"){
	EnableSSO
	Set-Location C:\Ericsson\NetAnServer\Scripts\sso
	$status = & .\ConfigureNetAnSSO.ps1 re-enable $installPa
	if($status -eq $True){
	return $True
	}
	else{
	return $False
	}
}
if($args -eq "enable"){
	EnableSSO
	Set-Location C:\Ericsson\NetAnServer\Scripts\sso
	$status = & .\ConfigureNetAnSSO.ps1 enable $installPa
	if($status -eq $True){
	return $True
	}
	else{
	return $False
	}
}