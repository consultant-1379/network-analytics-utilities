# ********************************************************************
# Ericsson Radio Systems AB                                     Module
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
# Name    : ConfigurationUpdater.psm1
# Date    : 20/08/2020
# Purpose : Updates the web player service configuration files as part of the automated install.


Import-Module Logger
Import-Module NetAnServerUtility

$loc=Get-Location
$drive = (Get-ChildItem Env:SystemDrive).value

$global:logger = Get-Logger($LoggerNames.Install)


### Function: ConfigurationUpdater($installParams) ###
#
#    Update configuration files for the Server, and Web Player service.
#
# Arguments:
#       $installParams - install parameters
#
# Return Values:
#       [boolean]$true|$false
# Throws:
#       [none]
#
Function Update-Configurations(){
    param (
            [Parameter(Mandatory=$true)]
            [hashtable]$installParams
    )

    try{
        $logger.logInfo("Updating configuration files....", $True)
		

        $webConfigTest=Test-WebConfig($installParams)
        $jobSenderTest = Test-JobSenderConfig($installParams)

		$webConfigUpdate=$True
        If (-not $webConfigTest) {
            $webConfigUpdate=$False
		    $logger.logInfo("Updating Config files for Network Analytics Node manager", $False)
			$serviceStopped = Stop-SpotfireService($installParams.nodeServiceName)
            if($serviceStopped) {
                $process=1
                while($process.Count){
                    try{
                        $process =  Get-Process -ProcessName "Spotfire.Dxp.Worker.Host" -ea Stop
                    }
                    catch {
                    $process=$null
                    }
                }
            
            } else {
                $logger.logError($MyInvocation," Updating configuration files for the web player service failed:  Node manager stop failed. ", $True)
                return $False
            }
            $webConfigUpdate=Update-WebConfiguration($installParams)
        }
		If (-not $webConfigUpdate) {
			return $False
		}
		
		$jobSenderUpdate=$True
        If (-not $jobSenderTest) {
            $jobSenderUpdate=$False
            $logger.logInfo("Updating Automation Services Config files for Network Analytics Server", $False)
            
            $jobSenderUpdate=Update-JobSenderFile($installParams)
        }
        If (-not $jobSenderUpdate) {
            return $False
        }
		
        If ($webConfigUpdate) {
            $logger.logInfo("Starting the node manager services....", $True)
            $serviceStarted = Start-SpotfireService($installParams.nodeServiceName)
            
            if(!$serviceStarted) {
                $logger.logError($MyInvocation," Updating configuration files for the web player service failed:  Node manager start failed. ", $True)
                return $False
            }
            $process=1
            while($process.Count -le 1){
                try{
                    Start-Sleep -s 1
                    $process =  Get-Process -ProcessName "Spotfire.Dxp.Worker.Host" -ea Stop
                }
                catch {        
                    $process=$null
                }

                if ($process.Count -gt 1) {
                    $logger.logInfo("$($serviceNodeManager) has started successfully`n", $True)
                    return $True
                }

            }  

        }
        
        
        return $True

    } catch {
        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation," Updating configuration files for the  web player service failed:  $errorMessage ", $True)
        return $False
    }
}


### Function: Update-JobSenderFile ###
#
#   Updates JobSender configuration file.
#
#
# Arguments:
#   [hashtable] $installParams
#
# Return Values:
#   [boolean]$true|$false
Function Update-JobSenderFile() {

     param(
        [hashtable] $installParams
    )

    $jobSenderFile = $installParams.automationServicesDir+"\Spotfire.Dxp.Automation.ClientJobSender.exe.config"
    $jobSenderExe =  $installParams.automationServicesDir+"\Spotfire.Dxp.Automation.ClientJobSender.exe"
    
    $oldTlsVersions = '<add key="Spotfire.AllowedTlsVersions" value="Tls, Tls11, Tls12"/>'
    $newTlsVersions = '<add key="Spotfire.AllowedTlsVersions" value="Tls12, Tls13"/>'
    $oldUserDetails = '<add key="Spotfire.Authentication.Basic.UserName" value=""/>'
    $newUserDetails = '<add key="Spotfire.Authentication.Basic.UserName" value="'+$installParams.administrator+'"/>'
    $oldPass = '<add key="Spotfire.Authentication.Basic.Password" value=""/>'
    $newPass = '<add key="Spotfire.Authentication.Basic.Password" value="'+$installParams.adminPassword+'"/>'


     try {
        (Get-Content $jobSenderFile)|% { $_ -replace $oldTlsVersions, $newTlsVersions } | Set-Content $jobSenderFile
        (Get-Content $jobSenderFile)|% { $_ -replace $oldUserDetails, $newUserDetails} | Set-Content $jobSenderFile
        (Get-Content $jobSenderFile)|% { $_ -replace $oldPass, $newPass} | Set-Content $jobSenderFile
        $encrypt = "$jobSenderExe -encryptPassword [encryptWithUserScope]"
        Invoke-Expression $encrypt | out-null
        $logger.logInfo("Network Analytics Automation Services configuration files updated.", $True)

        return $True
    } catch {
        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation," Updating Automation Services configuration files failed:  $errorMessage ", $True)
        return $False
    }
}

### Function: Update-WebConfiguration ###
#
#   Updates Web Player service configuration files.
#
#
# Arguments:
#   [hashtable] $installParams
#
# Return Values:
#   [boolean]$true|$false
#
Function Update-WebConfiguration() {

    param(
        [hashtable] $installParams
    )

    try {
        $log4netconfig=Get-ChildItem $installParams.webWorkerDir | Where-Object { $_.Name -match 'log4net' }

        foreach ($config in $log4netconfig.fullname)
        { 
            $Log4net = [xml](Get-content $config)
            $Log4net = [xml]( Get-content $installParams.webConfigLog4net)
            $Log4net.save($config)

        }

        Copy-Item -Path $installParams.webConfigWeb -Destination $installParams.installWebConfigWeb -Force
        Copy-Item -Path $installParams.webConfigHost -Destination $installParams.installWebConfigHost -Force
        Copy-Item -Path $installParams.webConfigHost -Destination $installParams.installautWebConfigHost -Force

        $logger.logInfo("Network Analytics Web Player service configuration files updated.", $True)

        return $True
    } catch {
        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation," Updating Web Player service configuration files failed:  $errorMessage ", $True)
        return $False
    }
}


### Function: Test-WebConfig ###
#
#   Verifies if the Web Player service configuration files have been updated.
#
#
# Arguments:
#   [hashtable] $installParams
#
# Return Values:
#   [boolean]$true|$false
#
Function Test-WebConfig() {

    param(
        [hashtable] $installParams
    )

	Set-Location $installParams.nodeManagerServices
	
	$timeout = new-timespan -Minutes 5
	$sw = [diagnostics.stopwatch]::StartNew()
	
	$autwebWorker=Get-ChildItem . | Where-Object { $_.Name -match 'AutomationServicesWorker' }
    while((!$autwebWorker) -and ($sw.elapsed -lt $timeout)){
	Start-Sleep -s 10
	$autwebWorker=Get-ChildItem . | Where-Object { $_.Name -match 'AutomationServicesWorker' }
	
	   if($autwebWorker){
        
         break
      }
	}
	
    $webWorker=Get-ChildItem . | Where-Object { $_.Name -match 'WebWorker' }
	
	$sw = [diagnostics.stopwatch]::StartNew()
    while((!$webWorker) -and ($sw.elapsed -lt $timeout)){
	Start-Sleep -s 10
	$webWorker=Get-ChildItem . | Where-Object { $_.Name -match 'WebWorker' }
	
	  if($webWorker){
        
         break
      }
	}
	
	
	Set-Location $loc
    $nodedir= $installParams.webWorkerDir 
    $installParams.webWorkerDir=$installParams.webWorkerDir + $webWorker
    $installParams.autwebWorkerDir=$nodedir + $autwebWorker

    $installParams.Add('installLog4Net',$installParams.webWorkerDir+"\log4net.config")
    $installParams.Add('installWebConfigWeb',$installParams.webWorkerDir+"\Spotfire.Dxp.Worker.Web.config")
    $installParams.Add('installWebConfigHost',$installParams.webWorkerDir+"\Spotfire.Dxp.Worker.Host.exe.config")
    $installParams.Add('installautWebConfigHost',$installParams.autwebWorkerDir+"\Spotfire.Dxp.Worker.Host.exe.config")

    $configs=@{}
    $configs.Add($installParams.installLog4Net,$installParams.webConfigLog4net)
    $configs.Add($installParams.installWebConfigWeb,$installParams.webConfigWeb)
    $configs.Add($installParams.installWebConfigHost,$installParams.webConfigHost)
    $configs.Add($installParams.installautWebConfigHost,$installParams.webConfigHost)
    $logger.logInfo($installParams.autwebConfigHost, $true)
    while( -not (Test-Path($installParams.installLog4Net)) ){
       Start-sleep -s 10
	   $logger.logInfo("Waiting for WebWorker to be created", $False)
    }

    foreach ($config in $configs.GetEnumerator()) {
        $configInstall = $config.Key
        $configResource = $config.Value

        If ((Get-FileHash $configInstall).Hash -ne (Get-FileHash $configResource).Hash) {
	return $False
        }
    }
    return $True
}

### Function: Test-JobSenderConfig ###
#
#   Verifies if the Spotfire.Dxp.Automation.ClientJobSender.exe.config has been updated.
#
#
# Arguments:
#   [hashtable] $installParams
#
# Return Values:
#   [boolean]$true|$false
#
Function Test-JobSenderConfig() {

    param(
        [hashtable] $installParams
    )

    $senderPath = $installParams.automationServicesDir+"\Spotfire.Dxp.Automation.ClientJobSender.exe.config"
    $senderFile=(Get-Content $senderPath)
    $containsWord = $senderFile | %{$_ -match "Ssl3, Tls, Tls11"}


    If($containsWord -contains $true) {
        return $False
    }

    return $True
}

