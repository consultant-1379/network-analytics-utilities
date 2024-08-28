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
# Name    : ConfigureEnryptedPassword.ps1
# Date    : 03/08/2022
# Purpose : Module Used for Configure Enrypted Password in server.xml file.
#
#---------------------------------------------------------------------------------
$loc = Get-Location
$drive = (Get-ChildItem Env:SystemDrive).value
 
$installParams = @{}
$installParams.Add('currentPlatformVersion', $version)
$installParams.Add('installDir', $drive + "\Ericsson\NetAnServer")
$installParams.Add('logDir', $installParams.installDir + "\Logs")
$installParams.Add('setLogName', 'ConfigureEnryptedPassword.log')
$installParams.Add('resourcesDir', $installParams.installDir + "\RestoreDataResources")
$installParams.Add('platformVersionDir', $installParams.resourcesDir + "\version")
$installParams.Add('ConfigureEnryptedPasswordjarDir', $drive + "\Ericsson\tmp\PasswordEncryptionDecryption.jar")
$installParams.Add('connectorProtocol', "com.password.creation.CustomHttp11NioProtocol")
 
Function InitiateLogs {
    stageEnter($MyInvocation.MyCommand)
    $creationMessage = $null
 
    if ( -not (Test-FileExists($installParams.logDir))) {
        New-Item $installParams.logDir -ItemType directory | Out-Null
        $creationMessage = "Creating new log directory $($installParams.logDir)"
    }
 
    $logger.setLogDirectory($installParams.logDir)
    $logger.setLogName($installParams.setLogName)
 
    $logger.logInfo("Starting the Configure Enrypted Password Process for Ericsson Network Analytics Server.", $True)
 
    if ($creationMessage) {
        $logger.logInfo($creationMessage, $true)
    }
 
    $logger.logInfo("Log created $($installParams.logDir)\$($logger.timestamp)_$($installParams.setLogName)", $True)
    Set-Location $loc
    stageExit($MyInvocation.MyCommand)
}
 
#----------------------------------------------------------------------------------
#  This Function prompts the user for the necessary input parameters required to
#  Configure Enrypted Password:
#----------------------------------------------------------------------------------
Function InputParameters1() {
    stageEnter($MyInvocation.MyCommand)
     
    $certificatePassword = hide-password("`nNetwork Analytics Server Certificate Password:`n")
    $installParams.Add('certificatePassword', $certificatePassword)
     
    stageExit($MyInvocation.MyCommand)
}
 
Function ServiceVersion() {
    stageEnter($MyInvocation.MyCommand)
    $check = TestFolderpath "C:\Ericsson\NetAnServer\Server"
    if ($check -ne $false) {
        $rootFolder = "C:\Ericsson\NetAnServer\Server"
        $PlaylistPath = Get-ChildItem -Directory -Path "$rootFolder" | Sort-Object Desc
        foreach ($PLP in $PlaylistPath) {
            $NewDir = $PLP
        }
        $logger.logInfo("NetAN Version :: $($NewDir)", $True)
        if ($NewDir.Name -ne "7.11") {
            $folder = $NewDir.Name
            $vz = $NewDir.Name -replace '\.', ''
            $serviceList = @("Tss$($vz)", "WpNmRemote$($vz)")
            $serviceNetAnServer = $serviceList[0]
            $serviceNodeManager = $serviceList[1]
            $installParams.Add('folder', $folder)
            $installParams.Add('serviceNetAnServer', $serviceNetAnServer)
            $installParams.Add('serviceNetAnNode', $serviceNodeManager)
            $installParams.Add('TSSPath', "C:\Ericsson\NetAnServer\Server\" + $installParams.folder + "\tomcat\spotfire-bin")
            $installParams.Add('TSNMPath', "C:\Ericsson\NetAnServer\NodeManager\" + $installParams.folder + "\nm\config\nodemanager.properties")
            $installParams.Add('TSNMKeyStorePath', "C:\Ericsson\NetAnServer\NodeManager\" + $installParams.folder + "\nm\trust\keystore.p12")
            $installParams.Add('LibPath', "C:\Ericsson\NetAnServer\Server\" + $installParams.folder + "\tomcat\lib")
            $installParams.Add('serverXmlPath', "C:\Ericsson\NetAnServer\Server\" + $installParams.folder + "\tomcat\conf\server.xml")
            $installParams.Add('serverCertsPath', "C:\Ericsson\NetAnServer\Server\" + $installParams.folder + "\tomcat\certs\")
			$installParams.Add('JDKPath', "C:\Ericsson\NetAnServer\Server\" + $installParams.folder + "\jdk\bin")
			$installParams.Add('JAVA_HOME', "C:\Ericsson\NetAnServer\Server\" + $installParams.folder + "\jdk")
			
         
            stageExit($MyInvocation.MyCommand)
        }
        elseif ($NewDir.Name -eq "7.11") {
            $folder = $NewDir.Name
            $serviceList = @("Tss7110", "WpNmRemote7110")
            $serviceNetAnServer = $serviceList[0]
            $serviceNodeManager = $serviceList[1]
            $installParams.Add('folder', $folder)
            $installParams.Add('serviceNetAnServer', $serviceNetAnServer)
            $installParams.Add('serviceNetAnNode', $serviceNodeManager)
            $installParams.Add('TSSPath', "C:\Ericsson\NetAnServer\Server\" + $installParams.folder + "\tomcat\bin")
            $installParams.Add('TSNMPath', "C:\Ericsson\NetAnServer\NodeManager\" + $installParams.folder + "\nm\config\nodemanager.properties")
            $installParams.Add('TSNMKeyStorePath', "C:\Ericsson\NetAnServer\NodeManager\" + $installParams.folder + "\nm\trust\keystore.p12")
            stageExit($MyInvocation.MyCommand)
        }
        else {
            $logger.logError($MyInvocation, "Path does not exist", $True)
            stageExit($MyInvocation.MyCommand)
            Exit
        }
    }
    else {
        $logger.logError($MyInvocation, "Path does not exist:: " + "$($installParams.installDir)", $True)
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
    try {
        Test-Path -Path $path -PathType Leaf
        return Test-Path -Path $path -PathType Leaf
    }
    catch {
        $logger.logError($MyInvocation, "File Not Found or Path does not exist::" + $path, $True)
        Exit
    }
}
 
Function TestFolderpath($path) {
    try {
        Test-Path -Path $path
        return Test-Path -Path $path
    }
    catch {
        $logger.logError($MyInvocation, "File Not Found or Path does not exist::" + $path, $True)
        Exit
    }
}
  
Function Test-hostAndDomainURL([string]$value) {
    try {
        if (!$TestHostAndDomainStatus) {
            if (Test-Connection $value -Quiet -WarningAction SilentlyContinue) {
                return $True
            }
            else {
                $logger.logInfo("Could not resolve $($value)`n Please confirm that the correct host-and-domain has been entered and retry.`nIf issue persists please contact your local network administrator", $True)
                return $False
            }
        }
    }
    catch {
        $logger.logError($MyInvocation, "Could not resolve $($value). Please contact your local network administrator", $False)
        Exit
    }
 
}
 
Function stageEnter([string]$myText) {
    $Script:stage = $Script:stage + 1
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
        }
        else {
 
            try {
                $logger.logInfo("Stopping service....", $True)
                Stop-Service -Name "$($service)" -ErrorAction stop -WarningAction SilentlyContinue
                while ($isRunning) {
                    Start-Sleep -s 10
                    $isRunning = Test-ServiceRunning "$($service)"
                }
            }
            catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not stop service. `n $errorMessage", $True)
                stageExit($MyInvocation.MyCommand)
                Exit
            }
        }
 
    }
 else {
        $logger.logError($MyInvocation, "Service $($service) not found.
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
        }
        else {
 
            try {
                $logger.logInfo("Starting service....", $True)
                Start-Service -Name "$($installParams.serviceNetAnNode)" -ErrorAction stop -WarningAction SilentlyContinue
                while (!$isRunning) {
                    Start-Sleep -s 25
                    $isRunning = Test-ServiceRunning "$($installParams.serviceNetAnNode)"
                    $logger.logInfo("Service $($installParams.serviceNetAnNode) is Running: $isRunning", $True)
 
                }
            }
            catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not start service. `n $errorMessage", $True)
            }
        }
 
        stageExit($MyInvocation.MyCommand)
 
    }
 else {
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
        }
        else {
 
            try {
                $logger.logInfo("Starting service....", $True)
                Start-Service -Name "$($installParams.serviceNetAnServer)" -ErrorAction stop -WarningAction SilentlyContinue
                while (!$isRunning) {
                    Start-Sleep -s 25
                    $isRunning = Test-ServiceRunning "$($installParams.serviceNetAnServer)"
                    $logger.logInfo("Service $($installParams.serviceNetAnServer) is Running: $isRunning", $True)
 
                }
            }
            catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not start service. `n $errorMessage", $True)
            }
        }
 
        stageExit($MyInvocation.MyCommand)
 
    }
 else {
        $logger.logError($MyInvocation, "Service $($installParams.serviceNetAnServer) not found.
            Please check server install was executed correctly")
        stageExit($MyInvocation.MyCommand)
        Exit
    }
}
 
 
Function CopyConfigureEnryptedPasswordjar() {
    stageEnter($MyInvocation.MyCommand)
     
	 try {
           Copy-Item $installParams.ConfigureEnryptedPasswordjarDir -Destination $installParams.LibPath  -errorAction stop
    }
    catch {
        $logger.logInfo("Error while coping jar to location $($installParams.LibPath) , Please try again.", $True)
		stageExit($MyInvocation.MyCommand)
        Exit
    }
      
	
    stageExit($MyInvocation.MyCommand)
 
}
 
Function EncrptCertificatePassword() {
    stageEnter($MyInvocation.MyCommand)
     
    set-Location -Path $installParams.LibPath
     
	 [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $installParams.JAVA_HOME)
 [System.Environment]::SetEnvironmentVariable("Path", [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine) + ";$($env:JAVA_HOME)\bin")
    
	$encrptCertificatePassword = (java -cp ".;PasswordEncryptionDecryption.jar" com.password.creation.PasswordEncrypt $installParams.certificatePassword)
 
    Set-Location $loc
    $installParams.Add('encrptCertificatePassword', $encrptCertificatePassword)
     
    stageExit($MyInvocation.MyCommand)
 
}
 
 
Function UpdateCertificatePassword($encrptCertificatePassword) {
    stageEnter($MyInvocation.MyCommand)
     
    $serverxml = [xml](Get-Content $installParams.serverXmlPath)
    $keystore = $serverxml.Server.Service.Connector.SSLHostConfig.Certificate
    $keystore.SetAttribute("certificateKeystorePassword", $encrptCertificatePassword)
    $serverxml.Save($installParams.serverXmlPath)
     
    stageExit($MyInvocation.MyCommand)
 
}
 
Function UpdateConnectorProtocol($connectorProtocol) {
    stageEnter($MyInvocation.MyCommand)
     
    $serverxml = [xml](Get-Content $installParams.serverXmlPath)
    $connector = $serverxml.Server.Service.Connector
    $connector.SetAttribute("protocol", $connectorProtocol)
    $serverxml.Save($installParams.serverXmlPath)
     
    stageExit($MyInvocation.MyCommand)
 
}
 
 
Function ValidatePassword($encrptCertificatePassword) {
    stageEnter($MyInvocation.MyCommand)
     
    $serverxml = [xml](Get-Content $installParams.serverXmlPath)
    $certificateKeystoreFile = ([String]($serverxml.Server.Service.Connector.SSLHostConfig.Certificate.certificateKeystoreFile)).trim()
    $certificateKeystoreFileName = $installParams.serverCertsPath + $certificateKeystoreFile.Substring(8, $certificateKeystoreFile.Length - 8)
     
    $logger.logInfo("Certificate Keystore file path is $certificateKeystoreFileName ", $True)
    $sec_keypass = ConvertTo-SecureString $installParams.certificatePassword -AsPlainText -Force
     
     
    try {
        $cert = (Get-PfxData -Password $sec_keypass -FilePath $certificateKeystoreFileName)
    }
    catch [Exception] {
        $logger.logInfo("Incorrect Password Entered , Please try again with correct password.", $True)
    }
     
    if (!$cert) {
        Exit
    }
     
    stageExit($MyInvocation.MyCommand)
 
}
 

Function DecrptCertificatePassword() {
    stageEnter($MyInvocation.MyCommand)
     
     set-Location -Path $installParams.LibPath
     
	 [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $installParams.JAVA_HOME)
	 
     [System.Environment]::SetEnvironmentVariable("Path", [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine) + ";$($env:JAVA_HOME)\bin")
	   
	$decrptCertificatePassword = (java -cp ".;PasswordEncryptionDecryption.jar" com.password.creation.PasswordDecrypt $($installParams.certificateEncryptedPassword))
 
    Set-Location $loc
    $installParams.Add('decrptCertificatePassword', $decrptCertificatePassword)
	
     
    stageExit($MyInvocation.MyCommand)
 
}
 
 
 
#IsPasswordEncypted  read password from server.xml and execute the code
#IsPasswordNotEncypted  get password from user and excute the code
#IsPasswordEncyptedAndSame  not need to exute code
#IsPasswordEncyptedNotSame  get password from user and need to exute code
Function InputParameters() {
	
	stageEnter($MyInvocation.MyCommand)
	 
	$serverxml = [xml](Get-Content $installParams.serverXmlPath)
    $connector = $serverxml.Server.Service.Connector
	$connectorProtocol = $($connector.getAttribute("protocol")[0])
	
	$logger.logInfo("Certificate connectorProtocol is $connectorProtocol.", $True)
	
	if($connectorProtocol -eq $installParams.connectorProtocol){
		$logger.logInfo("Server.xml password is encypted.", $True)
		
		$keystore = $serverxml.Server.Service.Connector.SSLHostConfig.Certificate
        $certificateEncryptedPassword = $keystore.getAttribute("certificateKeystorePassword")
		
		$installParams.Add('certificateEncryptedPassword', $certificateEncryptedPassword)
		
		DecrptCertificatePassword
		
		$certificatePassword = hide-password("`nNetwork Analytics Server Certificate Password:`n")
			
		
		if($($installParams.decrptCertificatePassword) -eq $certificatePassword){
			 $logger.logInfo("Certificate encrypted password in server.xml and user entered password is same. User has already updated encrypted password in server.xml.", $True)
			 Exit
		}else{
			
			$logger.logInfo("Certificate encrypted password and user entered password is not same. Proceding with encypted password update procedure.", $True)
			$installParams.Add('certificatePassword', $certificatePassword)
		}
		
        
		
	}else{
		
		$logger.logInfo("Server.xml password is not encypted", $True)
		$keystore = $serverxml.Server.Service.Connector.SSLHostConfig.Certificate
		$certificatePlainTexPassword = $keystore.getAttribute("certificateKeystorePassword")
		$installParams.Add('certificatePassword', $certificatePlainTexPassword)
		CopyConfigureEnryptedPasswordjar
	}

   stageExit($MyInvocation.MyCommand)
}
 
Import-Module Logger
$global:logger = Get-Logger($LoggerNames.Install)
 
Function Main() {
   InitiateLogs
   ServiceVersion
   InputParameters
   ValidatePassword
   StopNetAnServer $($installParams.serviceNetAnServer)
   EncrptCertificatePassword
   UpdateCertificatePassword $($installParams.encrptCertificatePassword)
   UpdateConnectorProtocol $($installParams.connectorProtocol)
   StartServer
   $logger.logInfo("Passowrd Encyption Configuration is Completed !!", $True) 
   
}
 
Main