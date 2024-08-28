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
# Name    : NetanServer_FQDN_Switch.ps1
# Date    : 03/08/2022
# Purpose : Module Used to Check and Switch FQDN
#
#---------------------------------------------------------------------------------
$loc = Get-Location
$drive = (Get-ChildItem Env:SystemDrive).value

$installParams = @{}
$installParams.Add('currentPlatformVersion', $version)
$installParams.Add('installDir', $drive + "\Ericsson\NetAnServer")
$installParams.Add('logDir', $installParams.installDir + "\Logs")
$installParams.Add('setLogName', 'FQDN_Switch.log')
$installParams.Add('resourcesDir', $installParams.installDir + "\RestoreDataResources")
$installParams.Add('platformVersionDir', $installParams.resourcesDir + "\version")

Function InitiateLogs {
	stageEnter($MyInvocation.MyCommand)
    $creationMessage = $null

    if ( -not (Test-FileExists($installParams.logDir))) {
        New-Item $installParams.logDir -ItemType directory | Out-Null
        $creationMessage = "Creating new log directory $($installParams.logDir)"
    }

    $logger.setLogDirectory($installParams.logDir)
    $logger.setLogName($installParams.setLogName)

    $logger.logInfo("Starting the FQDN Switch Process for Ericsson Network Analytics Server.", $True)

    if ($creationMessage) {
        $logger.logInfo($creationMessage, $true)
    }

    $logger.logInfo("Log created $($installParams.logDir)\$($logger.timestamp)_$($installParams.setLogName)", $True)
    Set-Location $loc
	stageExit($MyInvocation.MyCommand)
}

#----------------------------------------------------------------------------------
#  This Function prompts the user for the necessary input parameters required to
#  Switch FQDN:
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
	
	$currentFQDN = CurrentFQDNCheck
	$confirmation = 'n'
	$counter = 0
	$TestHostAndDomainStatus = $false
	while (($confirmation -ne 'y') -and ($counter -lt 4)){
		while(($TestHostAndDomainStatus -ne $true) -and ($counter -lt 4)) {
			if($counter -gt 0)
			{
				$logger.logInfo("********************Attempt $($counter) of 3********************", $True)
			}
			$hostAndDomain = customRead-host("`nEnter Network Analytics Server Primary Host-And-Domain:`n")
			
			if($currentFQDN -eq $hostAndDomain)
			{
				Write-Host("`n")
				$logger.logInfo("Server is Already Configured to the Same Primary FQDN", $True)
				$logger.logInfo("Validation Completed. No Further Actions Required.", $True)
				stageExit($MyInvocation.MyCommand)
				Exit
			}
			else
			{
				$confirmation = 'y'
			}
			$TestHostAndDomainStatus = Test-hostAndDomainURL $hostAndDomain
			$hostAndDomainURL= "https://"+($hostAndDomain)

			if (($confirmation -ne 'y') -or ($TestHostAndDomainStatus -eq $false)) {
				$counter = $counter + 1
				
				if($counter -lt 4)
				{
					customWrite-host "`nPlease re-enter the parameters.`n"
				}
			}
		}
	}
	if($counter -gt 3)
	{
		Write-Host("`n")
		$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
		$logger.logInfo("Please verify the Primary Host-And-Domain and re-run the script.", $True)
		stageExit($MyInvocation.MyCommand)
		Exit
	}
	$installParams.Add('hostAndDomainURL', $hostAndDomainURL)
	$installParams.Add('hostAndDomain', $hostAndDomain)
	Write-Host("`n")
	$logger.logInfo("Parameters confirmed, proceeding with next Steps.", $True)
	stageExit($MyInvocation.MyCommand)
}

Function Test-ConfigPassword($ConfigPassword)
{
	$TSSPath = $installParams.TSSPath
	set-Location -Path $TSSPath
	$temp = .\config list-addresses -t $ConfigPassword
	Add-Content -Path Temp.txt -Value $temp
	(Get-Content -Path Temp.txt).Trim() -ne '' | Set-Content Temp.txt
	$lengthOfFile = (Get-Content -Path Temp.txt) | Measure-Object
	if($lengthOfFile.Count -gt 1)
	{
		Remove-Item 'Temp.txt'
		Return $True
	}
	else
	{
		Remove-Item 'Temp.txt'
		Return $false
	}
	
}

Function ServiceVersion() {
	stageEnter($MyInvocation.MyCommand)
	$check = TestFolderpath "C:\Ericsson\NetAnServer\Server"
	if($check -ne $false) {
	$rootFolder = "C:\Ericsson\NetAnServer\Server"
	$PlaylistPath = Get-ChildItem -Directory -Path "$rootFolder" | Sort-Object Desc
	foreach ($PLP in $PlaylistPath) {
	$NewDir = $PLP
	}
	$logger.logInfo("NetAN Version :: $($NewDir)", $True)
	if($NewDir.Name -ne "7.11")
	{
		$folder = $NewDir.Name
		$vz = $NewDir.Name -replace '\.', ''
		$serviceList = @("Tss$($vz)", "WpNmRemote$($vz)")
		$serviceNetAnServer = $serviceList[0]
		$serviceNodeManager = $serviceList[1]
		$installParams.Add('folder', $folder)
		$installParams.Add('serviceNetAnServer', $serviceNetAnServer)
		$installParams.Add('serviceNetAnNode', $serviceNodeManager)
		$installParams.Add('TSSPath', "C:\Ericsson\NetAnServer\Server\"+$installParams.folder+"\tomcat\spotfire-bin")
		$installParams.Add('TSNMPath', "C:\Ericsson\NetAnServer\NodeManager\"+$installParams.folder+"\nm\config\nodemanager.properties")
		$installParams.Add('TSNMKeyStorePath', "C:\Ericsson\NetAnServer\NodeManager\"+$installParams.folder+"\nm\trust\keystore.p12")
		
		stageExit($MyInvocation.MyCommand)
	}
	elseif($NewDir.Name -eq "7.11")
	{
		$folder = $NewDir.Name
		$serviceList = @("Tss7110", "WpNmRemote7110")
		$serviceNetAnServer = $serviceList[0]
		$serviceNodeManager = $serviceList[1]
		$installParams.Add('folder', $folder)
		$installParams.Add('serviceNetAnServer', $serviceNetAnServer)
		$installParams.Add('serviceNetAnNode', $serviceNodeManager)
		$installParams.Add('TSSPath', "C:\Ericsson\NetAnServer\Server\"+$installParams.folder+"\tomcat\bin")
		$installParams.Add('TSNMPath', "C:\Ericsson\NetAnServer\NodeManager\"+$installParams.folder+"\nm\config\nodemanager.properties")
		$installParams.Add('TSNMKeyStorePath', "C:\Ericsson\NetAnServer\NodeManager\"+$installParams.folder+"\nm\trust\keystore.p12")
		stageExit($MyInvocation.MyCommand)
	}
	else{
		$logger.logError($MyInvocation, "Path does not exist", $True)
		stageExit($MyInvocation.MyCommand)
		Exit
	}
	}
	else{
		$logger.logError($MyInvocation, "Path does not exist:: "+"$($installParams.installDir)", $True)
		stageExit($MyInvocation.MyCommand)
		Exit
	}
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
		stageExit($MyInvocation.MyCommand)
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
 
Function Test-hostAndDomainURL([string]$value){
    try{
        if(!$TestHostAndDomainStatus){
	        if(Test-Connection $value -Quiet -WarningAction SilentlyContinue){
	            return $True
            }
	        else {
	            $logger.logInfo("Could not resolve $($value)`n Please confirm that the correct host-and-domain has been entered and retry.`nIf issue persists please contact your local network administrator", $True)
		        return $False
            }
        }
    }
    catch{
        $logger.logError($MyInvocation, "Could not resolve $($value). Please contact your local network administrator", $False)
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

#----------------------------------------------------------------------------------
#    Stop the NetAnServer Server Service
#----------------------------------------------------------------------------------
Function StopNetAnServer($service) {
	stageEnter($MyInvocation.MyCommand)
	
	$serviceExists = Test-ServiceExists "$($service)"
    $logger.logInfo("Service $($service) found: $serviceExists", $True)
	
	if ($serviceExists) {
		Set-Service "$($service)" -StartupType Manual
        $isRunning = Test-ServiceRunning "$($service)"

        if (!$isRunning) {
            $logger.logInfo("Server is already stopped....", $True)
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
        stageExit($MyInvocation.MyCommand)
		Exit
    }
	
	stageExit($MyInvocation.MyCommand)
}

Function UntrustDeleteNode($service) {
	stageEnter($MyInvocation.MyCommand)
	$TSSPath = $installParams.TSSPath
	$TSNMKeyStorePath = $installParams.TSNMKeyStorePath
	set-Location -Path $TSSPath
	$logger.logInfo("Preparing to UnTrust and Delete Node", $True)
	$temp = .\config list-nodes -t $installParams.configPassword
	Add-Content -Path Temp.txt -Value $temp
	$search="Remote nodes:"
	$linenumber= Get-Content Temp.txt | select-string $search
	$temp = Get-Content Temp.txt | Select -Index ($linenumber.LineNumber+2)
	$NodeID = ($temp.Split(" "))[0]
	Remove-Item 'Temp.txt'
	.\config untrust-node -t $installParams.configPassword -i $NodeID
	.\config delete-node -t $installParams.configPassword -i $NodeID
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
	stageExit($MyInvocation.MyCommand)
}

Function ChangeNodeConfig() {
	stageEnter($MyInvocation.MyCommand)
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
	stageExit($MyInvocation.MyCommand)
}

Function ChangeServerConfig() {
	stageEnter($MyInvocation.MyCommand)
	
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
        stageExit($MyInvocation.MyCommand)
		Exit
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


Import-Module Logger
$global:logger = Get-Logger($LoggerNames.Install)

Function Main() {
	InitiateLogs
	ServiceVersion
	InputParameters
    StopNetAnServer $($installParams.serviceNetAnNode)
	UntrustDeleteNode
	StopNetAnServer $($installParams.serviceNetAnServer)
	ChangeNodeConfig
	ChangeServerConfig
	StartServer
	StartNodeManager
	$logger.logInfo("FQDN Switched From $($installParams.ServerBackupFQDN) `n to $($installParams.hostAndDomain)", $True)
	$logger.logInfo("Completed !!", $True)
}

Main

