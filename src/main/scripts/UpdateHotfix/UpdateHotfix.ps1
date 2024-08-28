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
# Name    : UpdateHotfix.ps1
# Date    : 03/01/2023
# Purpose : Used to Apply Latest Hotfix and Custom Packages
#
#---------------------------------------------------------------------------------
$loc = Get-Location
$drive = (Get-ChildItem Env:SystemDrive).value
$netanserver_media_dir = (get-item $PSScriptRoot).parent.parent.FullName

# get platform current version num
[xml]$xmlObj = Get-Content "$($netanserver_media_dir)\Resources\version\supported_NetAnPlatform_versions.xml"
$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")

foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'y') {
            $version = $platformVersionString.'version'
            $serviceVersion = $platformVersionString.'service-version'
            $versionType = $platformVersionString.'release-type'
        }
}

$installParams = @{}
$installParams.Add('currentPlatformVersion', $version)
$installParams.Add('installDir', $drive + "\Ericsson\NetAnServer")
$installParams.Add('logDir', $installParams.installDir + "\Logs")
$installParams.Add('setLogName', 'Update_Hotfix.log')
$installParams.Add('resourcesDir', $netanserver_media_dir +"\Resources")
$installParams.Add('hotfixDir', $installParams.resourcesDir +"\hotfix")
$installParams.Add('webConfigLog4net', $installParams.resourcesDir + "\webConfig\log4net.config")
$installParams.Add('webConfigWeb', $installParams.resourcesDir + "\webConfig\Spotfire.Dxp.Worker.Web.config")
$installParams.Add('webConfigHost', $installParams.resourcesDir + "\webConfig\Spotfire.Dxp.Worker.Host.exe.config")


Function InitiateLogs {
	stageEnter($MyInvocation.MyCommand)
    $creationMessage = $null

    if ( -not (Test-FileExists($installParams.logDir))) {
        New-Item $installParams.logDir -ItemType directory | Out-Null
        $creationMessage = "Creating new log directory $($installParams.logDir)"
    }

    $logger.setLogDirectory($installParams.logDir)
    $logger.setLogName($installParams.setLogName)

    $logger.logInfo("Starting the Hotfix Installation Process for Ericsson Network Analytics Server.", $True)

    if ($creationMessage) {
        $logger.logInfo($creationMessage, $true)
    }

    $logger.logInfo("Log created $($installParams.logDir)\$($logger.timestamp)_$($installParams.setLogName)", $True)
    Set-Location $loc
	stageExit($MyInvocation.MyCommand)
}

#----------------------------------------------------------------------------------
#  This Function prompts the user for the necessary input parameters required to
#  Apply Hotfix:
#----------------------------------------------------------------------------------
Function InputParameters() {
	stageEnter($MyInvocation.MyCommand)
	$ConfigPasswordStatus = $false
	$counter = 0
    while (($ConfigPasswordStatus -ne $true) -and ($counter -lt 4)) {
		if($counter -gt 0)
		{
			Write-Host("`n")
			$logger.logInfo("********************Attempt $($counter) of 3********************", $True)
		}
		$ConfigPassword = hide-password("`nEnter Network Analytics Server Platform Password:`n")
		$ConfigPasswordStatus = Test-ConfigPassword $ConfigPassword
		$counter = $counter + 1
	}
	if($counter -gt 3)
	{
		Write-Host("`n")
		$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
		$logger.logInfo("Please verify the Platform Password and re-run the script.", $True)
		stageExit($MyInvocation.MyCommand)
		Exit
	}
    $installParams.Add('configPassword', $ConfigPassword)
	$logger.logInfo("Network Analytics Server Platform Password Validated", $True)
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
			Exit
		}
		else{
			$logger.logInfo("$($hotfixfiles.count) Deployment Files Found !!", $True)
		}
	}
	
	stageExit($MyInvocation.MyCommand)
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
	$pass = $installParams.configPassword
	$command = "update-deployment -t $pass -a Production $allpackages"
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

Function Test-ConfigPassword($ConfigPassword)
{
	$loc = Get-Location
	$TSSPath = $installParams.TSSPath
	set-Location -Path $TSSPath
	$temp = .\config list-addresses -t $ConfigPassword
	Add-Content -Path Temp.txt -Value $temp
	(Get-Content -Path Temp.txt).Trim() -ne '' | Set-Content Temp.txt
	$lengthOfFile = (Get-Content -Path Temp.txt) | Measure-Object
	if($lengthOfFile.Count -gt 1)
	{
		Remove-Item 'Temp.txt'
		Set-Location $loc
		Return $True
	}
	else
	{
		Remove-Item 'Temp.txt'
		Set-Location $loc
		Return $false
	}
	
}

Function ServiceVersion() {
	stageEnter($MyInvocation.MyCommand)
	$loc = Get-Location
	$check = TestFolderpath "C:\Ericsson\NetAnServer\Server"
	$version = $installParams.currentPlatformVersion
	if($check -ne $false) {
	$rootFolder = "C:\Ericsson\NetAnServer\Server"
	$PlaylistPath = Get-ChildItem -Directory -Path "$rootFolder" | Sort-Object Desc
	foreach ($PLP in $PlaylistPath) {
	$NewDir = $PLP
	}
	$logger.logInfo("Installed NetAn Version :: $($NewDir)", $True)
	
	$folder = $NewDir.Name
	$vz = $NewDir.Name -replace '\.', ''
	$serviceList = @("Tss$($vz)", "WpNmRemote$($vz)")
	$serviceNetAnServer = $serviceList[0]
	$serviceNodeManager = $serviceList[1]
	$installParams.Add('folder', $folder)
	$installParams.Add('serviceNetAnServer', $serviceNetAnServer)
	$installParams.Add('serviceNetAnNode', $serviceNodeManager)
	$installParams.Add('TSSPath', "C:\Ericsson\NetAnServer\Server\"+$installParams.folder+"\tomcat\spotfire-bin")
	$installParams.Add('spotfirebin', "C:\Ericsson\NetAnServer\Server\"+$installParams.folder+"\tomcat\spotfire-bin\")
	$installParams.Add('TSNMPath', "C:\Ericsson\NetAnServer\NodeManager\"+$installParams.folder+"\nm\config\nodemanager.properties")
	$installParams.Add('TSNMKeyStorePath', "C:\Ericsson\NetAnServer\NodeManager\"+$installParams.folder+"\nm\trust\keystore.p12")
	$installParams.Add('nodeManagerServices', "C:\Ericsson\NetAnServer\NodeManager\"+$installParams.folder+"\nm\services\")
	$installParams.Add('webWorkerDir', $installParams.nodeManagerServices)
	
	if($version -ne $NewDir) {
		$logger.logInfo("Hotfix package should be used for $version NetAn Version", $True)
		$logger.logError($MyInvocation, "Intended NetAn Versions do not match", $True)
		Set-Location $loc
		Exit
	}

	Set-Location $loc
	stageExit($MyInvocation.MyCommand)
	}
	else{
		$logger.logError($MyInvocation, "Path does not exist:: "+"$($installParams.installDir)", $True)
		Set-Location $loc
		Exit
	}
}

Function customWrite-host($text) {
      Write-Host $text -ForegroundColor White
 }

Function customRead-host($text) {
      Write-Host $text -ForegroundColor White -NoNewline
      Read-Host
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

Function TestFolderpath($path) {
	try
	{
		Test-Path -Path $path
		return Test-Path -Path $path
	}
	catch{
		$logger.logError($MyInvocation, "File Not Found or Path does not exist::"+$path, $True)
		Exit
	}
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

Function StopServer() {
	stageEnter($MyInvocation.MyCommand)
	
	$service = $installParams.serviceNetAnServer
	
	$serviceExists = Test-ServiceExists "$($service)"
    $logger.logInfo("Service $($service) found: $serviceExists", $True)
	
	if ($serviceExists) {
		Set-Service "$($service)" -StartupType Manual
        $isRunning = Test-ServiceRunning "$($service)"

        if (!$isRunning) {
            $logger.logInfo("Server is already stopped....", $True)
        } else {

            try {
                $logger.logInfo("Stopping NetAn Server....", $True)
                Stop-Service -Name "$($service)" -ErrorAction stop -WarningAction SilentlyContinue
				while($isRunning){
				Start-Sleep -s 10
				$isRunning = Test-ServiceRunning "$($service)"
				}
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not stop NetAn Server. `n $errorMessage", $True)
				stageExit($MyInvocation.MyCommand)
				Exit
            }
        }

    } else {
        $logger.logError($MyInvocation, "$($service) not found.
            Please check server install was executed correctly")
        stageExit($MyInvocation.MyCommand)
		Exit
    }
	
	stageExit($MyInvocation.MyCommand)
}

Function StopNodeManager() {
	stageEnter($MyInvocation.MyCommand)
	
	$service = $installParams.serviceNetAnNode
	
	$serviceExists = Test-ServiceExists "$($service)"
    $logger.logInfo("Service $($service) found: $serviceExists", $True)
	
	if ($serviceExists) {
		Set-Service "$($service)" -StartupType Manual
        $isRunning = Test-ServiceRunning "$($service)"

        if (!$isRunning) {
            $logger.logInfo("Server is already stopped....", $True)
        } else {

            try {
                $logger.logInfo("Stopping NetAn Node Manager Service....", $True)
                Stop-Service -Name "$($service)" -ErrorAction stop -WarningAction SilentlyContinue
				while($isRunning){
				Start-Sleep -s 10
				$isRunning = Test-ServiceRunning "$($service)"
				}
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not stop NetAn Node Manager Service. `n $errorMessage", $True)
				stageExit($MyInvocation.MyCommand)
				Exit
            }
        }

    } else {
        $logger.logError($MyInvocation, "$($service) not found.
            Please check server install was executed correctly")
        stageExit($MyInvocation.MyCommand)
		Exit
    }
	
	stageExit($MyInvocation.MyCommand)
}

Function StartNodeManager() {
    stageEnter($MyInvocation.MyCommand)

    $logger.logInfo("Preparing to Start Node Manager", $True)
    $serviceExists = Test-ServiceExists "$($installParams.serviceNetAnNode)"
    $logger.logInfo("Service $($installParams.nodeServiceName) found: $serviceExists", $True)

    if ($serviceExists) {
		
		Set-Service "$($installParams.serviceNetAnNode)" -StartupType Automatic
        $isRunning = Test-ServiceRunning "$($installParams.serviceNetAnNode)"

        if ($isRunning) {
            $logger.logInfo("Node Manager is already running....", $True)
        } else {

            try {
                $logger.logInfo("Starting service....", $True)
                Start-Service -Name "$($installParams.serviceNetAnNode)" -ErrorAction stop -WarningAction SilentlyContinue
				while(!$isRunning){
				Start-Sleep -s 25
				$isRunning = Test-ServiceRunning "$($installParams.serviceNetAnNode)"
				$logger.logInfo("Service $($installParams.serviceNetAnNode) is Running: $isRunning", $True)

				}
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not start service. `n $errorMessage", $True)
            }
        }

        stageExit($MyInvocation.MyCommand)

    } else {
        $logger.logError($MyInvocation, "Service $($installParams.nodeServiceName) not found.
            Please check server install was executed correctly")
		Exit
    }
}

Function UpdateConfigurations() {
    stageEnter($MyInvocation.MyCommand)
	$loc = Get-Location
	
	Set-Location $installParams.nodeManagerServices
	$autwebWorker=Get-ChildItem . | Where-Object { $_.Name -match 'AutomationServicesWorker' }
	$webWorker=Get-ChildItem . | Where-Object { $_.Name -match 'WebWorker' }
	
	$nodedir= $installParams.webWorkerDir
	$installParams.webWorkerDir=$installParams.webWorkerDir + $webWorker
	$installParams.autwebWorkerDir=$nodedir + $autwebWorker
	$installParams.Add('installLog4Net',$installParams.webWorkerDir+"\log4net.config")
	$installParams.Add('installWebConfigWeb',$installParams.webWorkerDir+"\Spotfire.Dxp.Worker.Web.config")
	$installParams.Add('installWebConfigHost',$installParams.webWorkerDir+"\Spotfire.Dxp.Worker.Host.exe.config")
	$installParams.Add('installautWebConfigHost',$installParams.autwebWorkerDir+"\Spotfire.Dxp.Worker.Host.exe.config")

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

    } catch {
        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation," Updating Web Player service configuration files failed:  $errorMessage ", $True)
    }
	Set-Location $loc
	stageExit($MyInvocation.MyCommand)
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


Import-Module Logger
$global:logger = Get-Logger($LoggerNames.Install)

Function Main() {
	InitiateLogs
	ServiceVersion
	DeploymentPackageCheck
	InputParameters
	StopNodeManager
	StopServer
	ApplyDeployment
	UpdateConfigurations
	StartServer
	StartNodeManager
	$logger.logInfo("Hotfix Applied Successfully !!", $True)
}
Main

