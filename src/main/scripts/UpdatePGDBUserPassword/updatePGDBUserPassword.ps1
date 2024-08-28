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
# Name    : updatePDGBUSerPassword.ps1
# Date    : 10/10/2022
# Purpose : Script purpose is to update postgresql database user password and platform password(only appilicable in 'netanserver' db user). 
#
#---------------------------------------------------------------------------------
Import-Module Logger
$global:logger = Get-Logger($LoggerNames.Install)


$loc = Get-Location
$drive = (Get-ChildItem Env:SystemDrive).value
$installParams = @{}
$DB = 'netanserver_db'
$SERVER = 'localhost'
$USER = 'netanserver'
$SQL_SERVICE = "postgresql-x64-" +(((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).MajorVersion) | measure -Maximum).Maximum
$password = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable NetAnVar)).GetNetworkCredential().Password
$restoreResourcesPath = "C:\Ericsson\NetAnServer\RestoreDataResources\"
[xml]$xmlObj= Get-Content -Path "$($restoreResourcesPath)\version\supported_NetAnPlatform_versions.xml"
$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")
foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'y') {
            $version = $platformVersionString.'version'
        }
}
$installParams.Add('currver', $version)
$Version = $version.Replace(".","")
$dbDriverClass = "org.postgresql.Driver"
$dbUser = "netanserver"
$dbURL = "jdbc:postgresql://localhost:5432/netanserver_db"
$spotfirebin = "C:\Ericsson\NetAnServer\Server\" + $installParams.currver + "\tomcat\spotfire-bin\"
$configToolLogfile = "$ADHOC_LOG_DIR\$(get-date -Format 'yyyyMMdd_HHmmss')_configTool.log"
$PERM_CONFIG_LOGFILE = "C:\Ericsson\NetAnServer\Logs\ConfigTool_bootstrap.log"
$global:checkusernetan = $false
$global:setnetanvar = $false
$ADHOC_LOG_DIR = "C:\Ericsson\NetAnServer\Logs"
$installParams.Add('installDir', $drive + "\Ericsson\NetAnServer")
$installParams.Add('logDir', $installParams.installDir + "\Logs")
$installParams.Add('setLogName', 'PGDBpasswordudpate.log')
$install_date = get-date -format "yyyyMMdd"
$initialboot = "C:\Ericsson\NetAnServer\Server\" + $installParams.currver + "\tomcat\webapps\spotfire\WEB-INF\bootstrap.xml"
$Destination_boot = "C:\Ericsson\NetAnServer\Server\" + $installParams.currver +"\tomcat\webapps\spotfire\WEB-INF\" + $install_date + "_bootstrap.xml"
$initial_conf = "C:\Ericsson\NetAnServer\Server\" + $installParams.currver + "\tomcat\spotfire-bin\configuration.xml"
$Destination_conf = "C:\Ericsson\NetAnServer\Server\" + $installParams.currver + "\tomcat\spotfire-bin" + $install_date + "_configuration.xml"
$actiondbURL = "jdbc:postgresql://localhost:5432/netanserveractionlog_db"
$installParams.Add('dbDriverClass', $dbDriverClass)
$installParams.Add('dbURL', $dbURL)
$installParams.Add('dbUser', "$dbUser")
$installParams.Add('spotfirebin', $spotfirebin)
$installParams.Add('actiondbURL', $actiondbURL)


Function InitiateLogs() {
    $creationMessage = $null
    

    if ( -not (Test-FileExists($installParams.logDir))) {
        New-Item $installParams.logDir -ItemType directory | Out-Null
        $creationMessage = "Creating new log directory $($installParams.logDir)"
        
    }
    
    $logger.setLogDirectory($installParams.logDir)
    $logger.setLogName($installParams.setLogName)
    $logger.timestamp = get-date -Format 'yyyyMMdd_HHmmss'
 
    $logger.logInfo("Starting the Postgresql User Password Update Process.", $True)

    $currentLogName = "$($installParams.logDir)\$($logger.timestamp)_$($installParams.setLogName)"
    if($creationMessage) {
        $logger.logInfo($creationMessage + "`n", $true)
    }
        
    $logger.logInfo("Postgres User Password Update Log Created  $currentLogName`n", $True)
   

}

Function customRead-host($text) {
    Write-Host $text -ForegroundColor White -NoNewline
    Read-Host
}

Function CheckUserExists() {
    stageEnter($MyInvocation.MyCommand)
    $counter = 1
    $query = "select usename as username from pg_shadow order by usename;"
    $Userexists = $false

    while (($Userexists -ne $true) -and ($counter -lt 4)) {
    if($counter -gt 0) {
	$logger.logInfo("********************Attempt $($counter) of 3********************", $True)
    $usercheck = customRead-host("`nEnter Postgresql User whose password you want to update:`n")
    $result = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
    if ($result[0]) {
        $output = $result[1]
            if($output.username.Contains($usercheck)) {
                $Userexists = $true
                $logger.logInfo("User '$($usercheck)' exists. Proceeding to next stage.`n", $True)
                }
            else {
                $logger.logInfo("The User '$($usercheck)' does not exist , Please re-enter correct username, Please Verify and Re-try.", $True)
                $counter = $counter + 1
                }
        }  
        else {
        $logger.logInfo("Error occurred with command $($result[1])", $true)
        Exit 1
    }	}
    if($counter -gt 3)
	{
		Write-Host("`n")
		$logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
		$logger.logInfo("Please verify the Username and Re-run the script.", $True)
		Exit
	}


}
    $installParams.Add('usercheck', $usercheck)
    stageExit($MyInvocation.MyCommand)
}

Function hide-password($text) {

      Write-Host $text -ForegroundColor White -NoNewline
      $EncryptedPass=Read-Host -AsSecureString
      $unencryptedpassword = (New-Object System.Management.Automation.PSCredential 'N/A', $EncryptedPass).GetNetworkCredential().Password
      return $unencryptedpassword
}

function CheckPassword {
    stageEnter($MyInvocation.MyCommand)
    $counter = 1
    $Passcheck = $false


    while (($Passcheck -ne $true) -and ($counter -lt 4)) {
    if($counter -gt 0) {

    $logger.logInfo("********************Attempt $($counter) of 3********************", $True)

    $oldpass = hide-Password("`nEnter Current Password for Postgresql user '$($installParams.usercheck)':`n")
    
    $checkpassresult = TestConnection -Database $DB -Username $installParams.usercheck -Password $oldpass -ServerInstance $SERVER
   if($Passcheck -eq $false){
    if($checkpassresult -eq $true){
        $Passcheck = $true
        $logger.logInfo("Password Verified for user '$($installParams.usercheck)'", $True)  
        }
    else {
        $logger.logInfo("Entered Password is incorrect , Plese re-check entered password.", $True)
        $counter = $counter + 1
            }
        }

    else {
    $logFile.logError("Error occurred with command`n$($checkpassresult[1])", $True)
    Exit 1
}
}
if($counter -gt 3){
    Write-Host("`n")
    $logger.logInfo("Maximum Incorrect Attempts Reached!!", $True)
    $logger.logInfo("Please verify the Username entered and re-run the script.", $True)
    Exit
} }

    $installParams.Add('oldpass', $oldpass)  
    stageExit($MyInvocation.MyCommand)    
  
}

Function TestConnection() {
    param(
        [parameter(mandatory=$True)]
        [string] $database,
        [parameter(mandatory=$True)]
        [string] $username,
        [parameter(mandatory=$True)]
        [string] $password,
        [parameter(mandatory=$True)]
        [string] $serverInstance
		
    )
    $SQL_SERVICE = "postgresql-x64-" + (((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).MajorVersion) | measure -Maximum).Maximum
	
    $isRunning = Test-ServiceRunning "$($SQL_SERVICE)"

    if (-not $isRunning) {
        return @($False,"SQL Service $($SQL_SERVICE) is not running. Exiting")
        Exit
    }
	$driver = @((Get-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers" | Select-Object -ExpandProperty Property) | Where-Object {$_ -like 'postgresql*unicode*'})
	if ($driver.count -eq 0) {
        return @($False,"PostgreSQL ODBC driver is not installed. Exiting")
        Exit
    }
    try {
		$conn = New-Object System.Data.Odbc.OdbcConnection
		$conn.ConnectionString = "Driver={" + $driver[0] + "};Server=" + $serverInstance + ";Port=5432;Database=" + $database + ";Uid=" + $username + ";Pwd=" + $password + ";"
		$conn.open()
		return $True
    } catch {
        return $False
    } 
    finally {
        $conn.close()
    }
}

Function InputDbpassword() {

    stageEnter($MyInvocation.MyCommand)
	$counter = 1
	$PassMatch = 'n'
    $logger.logInfo("`nStarting Postgres password udpate")
	
    while (($PassMatch -ne 'y') -and ($counter -lt 4)) {
	$logger.logInfo("********************Attempt $($counter) of 3********************", $True)
	
    $newpass = Fetch-Password("`nPlease Enter new Password for '$($installParams.usercheck)' user:`n")
	if($installParams.oldpass -eq $newpass)
	{
		$logger.logInfo("Same Password is already configured for '$($installParams.usercheck)' user `n", $true)
		$PassMatch = 'n'
		$counter = $counter + 1
	}
	else
	{
		$renewpass = hide-Password("Confirm Password:`n")
		$PassMatch = confirm-password $newpass $renewpass
		$counter = $counter + 1
		}
	}

	if($PassMatch -ne 'y'){
		$logger.logInfo("Maximum Attempts Reached!!", $True)
		$logger.logInfo("Please verify the Password entered and re-run the script.", $True)
		Exit
		}
    
    $installParams.Add('newpass', $newpass)
    stageExit($MyInvocation.MyCommand)
}

Function confirm-password([string]$FirstPass,[string]$SecondPass) {

    if (($FirstPass -ceq $SecondPass)) {
        return 'y'
    } else {
        Write-host "`nPassword doesn't match.`n"
        return 'n'
    }
}

Function Fetch-Password($userInput) {

    $password = hide-password $userInput
    while (!(Test-Password($password))) {
        $password = hide-password "The supplied password does not meet the minimum complexity requirements. Please refer to the Network Analytics Server System Adminstrator Guide for information on password policy. `nPlease Re-Enter new Password for '$($installParams.usercheck)' user:`n"
    }
    return $password
}


function VerifyUser()  {

    stageEnter($MyInvocation.MyCommand)
    $logger.logInfo("Verifying if user entered is 'netanserver'", $true)
    Start-Sleep -s 1
    if($installParams.usercheck -eq 'netanserver'){

        $global:checkusernetan = $true

        $logger.logInfo("User entered is 'netansever'", $true)
        

    }
    else {
        $logger.logInfo("User entered is other than 'netanserver'", $True)

    }

    stageExit($MyInvocation.MyCommand)

}  
   
Function Updatedbpassword(){
stageEnter($MyInvocation.MyCommand)
$logger.logInfo("Updating password for user '$($installParams.usercheck)'", $True)  
$query = "ALTER USER $($installParams.usercheck) with password '$($installParams.newpass)';"
$result = Invoke-UtilitiesSQL -Database $DB -Username $installParams.usercheck -Password $installParams.oldpass -ServerInstance $SERVER -Query $query -Action fetch
Start-Sleep -s 1
$isSuccesfull = $result[0]
if ($isSuccesfull) {
    $logger.logInfo("Password Update Query Executed", $True)
    VerifyUpdatedPassword
} else {
    $logger.logError("Error while updating password, Failed with message:`n $($result[1])", $True)
    Exit
}

stageExit($MyInvocation.MyCommand)

}

function VerifyUpdatedPassword {


    $checkpassresult = TestConnection -Database $DB -Username $installParams.usercheck -Password $installParams.newpass -ServerInstance $SERVER
 
    if($checkpassresult -eq $true)
    {
        $logger.logInfo("Password Updated Successfully for user '$($installParams.usercheck)'", $true)
     
    }
    else {
        $logger.logInfo("`nPasswrod Udpate failed, Please Re-try.", $true)
     Exit 1
    }
    
   
 }


Function UpdateBootStrap() {

    stageEnter($MyInvocation.MyCommand)
	$logger.logInfo("Starting Update of Boostrap.xml Configuration", $True)
    $logger.logInfo("Taking backup of existing bootstrap file", $true)
    Copy-Item -Path $initialboot -Destination $Destination_boot -Force
    StopService Tss$Version

    $logger.logInfo("Configuring bootstrap ", $True)
    $bootstrapConfigStages = @('bootstrap')
    $isUpdated = Update-Deployment $map $bootstrapConfigStages

    if( -not $isUpdated) {
        $logger.logError($MyInvocation, "Error while updating bootstrap.xml of Network Analytics Server", $True)
        RestorePassword
    }else{
        $logger.logInfo("Bootstrap.xml update of Network Analytics Server completed", $True)
        $logger.logInfo("Updating 'NetAnVar' Enivornment Variable", $True)
        Set-EnvVariable $($installParams.newpass) "NetAnVar"
        $logger.logInfo("'NetAnVar' Enivornment Variable update completed", $True)
        $global:setnetanvar = $true
        $logger.logInfo("Removing bootstarp backup file", $True)
        if((Test-Path($Destination_boot))){
            Remove-Item $Destination_boot -Recurse
            $logger.logInfo("Bootstrap backup file removal completed", $True)
        } 
               
    }

    stageExit($MyInvocation.MyCommand)
}

Function Updateactiondb() {

    stageEnter($MyInvocation.MyCommand)
   
    Start-Sleep -s 1
    $logger.logInfo("Update of actiondb logger configuring started", $True)
    $bootstrapConfigStages = @('config-action-log-database-logger')
    $isUpdated = Update-Deployment $map $bootstrapConfigStages

    if( -not $isUpdated) {
        $logger.logError($MyInvocation, "Error while updating action_db configuration Network Analytics Server", $True)
        RestoreConfig
        RestorePassword
    } 
    else{
        $logger.logInfo("Update of actiondb logger configuring completed", $True)
    }     
    

   
    stageExit($MyInvocation.MyCommand)
}

Function ExportConfig() {

    stageEnter($MyInvocation.MyCommand)
    $logger.logInfo("Taking backup of existing configuation file", $true)
    Copy-Item -Path $initial_conf -Destination $Destination_conf -Force
    Start-Sleep -s 1
  

    $logger.logInfo("Export of Network Analytics Server configuration Started", $True)
    $bootstrapConfigStages = @('export-config')
    $isUpdated = Update-Deployment $map $bootstrapConfigStages

    if( -not $isUpdated) {
        $logger.logError($MyInvocation, "Error while exporting Network Analytics Server configuration ", $True)
        RestorePassword
    } 
    else{
        $logger.logInfo("Export of Network Analytics Server configuration completed", $True)
    }      
    

  
    stageExit($MyInvocation.MyCommand)
}

Function ImportConfig() {

    stageEnter($MyInvocation.MyCommand)
   
   
    Start-Sleep -s 1
    $logger.logInfo("Import of Network Analytics Server configuration started", $True)
    $bootstrapConfigStages = @('import-config')
    $isUpdated = Update-Deployment $map $bootstrapConfigStages

    if( -not $isUpdated) {
        $logger.logError($MyInvocation, "Error while importing Network Analytics Server", $True)
        RestoreConfig
        RestorePassword   
    } 
    else{
        $logger.logInfo("Import of Network Analytics Server configuration completed", $True)
        if((Test-Path($Destination_conf))){
            Remove-Item $Destination_conf -Recurse
            $logger.logInfo("Configuration backup file removal completed.", $True)
        } 
    }       
    StartService Tss$Version
    Start-Sleep -s 10
    stageExit($MyInvocation.MyCommand)
}

    Function RestoreConfig {

        stageEnter($MyInvocation.MyCommand)
        Start-Sleep -s 1
        $logger.logInfo("Restoring configuration back to original started", $True)
        Copy-Item -Path $Destination_conf -Destination $initial_conf -Force
        $logger.logInfo("Restoring configuration back to original completed", $True)
        stageExit($MyInvocation.MyCommand)
    }

    Function RestorePassword {
        stageEnter($MyInvocation.MyCommand)
        $logger.logInfo("Restoring Bootstrap back to original configuration", $True)

        Copy-Item -Path $Destination_boot -Destination $initialboot -Force
        
        $logger.logInfo("Restoring Postgresql Passwrod for user '$($installParams.usercheck)'", $true)  
            
        $query = "ALTER USER $($installParams.usercheck) with password '$($installParams.oldpass)';"
        $result = Invoke-UtilitiesSQL -Database $DB -Username $installParams.usercheck -Password $installParams.newpass -ServerInstance $SERVER -Query $query -Action fetch
        
        $isSuccesfull = $result[0]
        
        if ($isSuccesfull) {
            $logger.logInfo("Password restore Query Executed." ,$true)
            $logger.logInfo("Password restored Successfully." ,$true)
            
        } else {
            $logger.logError("Error while restoring password, Failed with message`n $($result[1])", $true)
        }

        if($global:setnetanvar -eq $true){
        $logger.logInfo("Restoring 'NetAnvar' Enivornment Variable" ,$true)
        Set-EnvVariable $($installParams.oldpass) "NetAnVar"
        $logger.logInfo("'NetAnvar' Enivornment Variable restore completed." ,$true)
        }
        
        StartService Tss$Version
        $logger.logInfo("Updating Postgre db User password failed , please re-try", $True)
        stageExit($MyInvocation.MyCommand)
        Exit 1

    }



    Function FollowInstruction {
        stageEnter($MyInvocation.MyCommand)
        $logger.logInfo("Postgre DB user 'netanserver' and platform password is updated with the new password.", $true)
        $logger.logInfo("Please update Datasource in NetAn Analytics manully, follow instruction provided in Network Analytics Server, System Administrator Guide docuement.", $true)
        $logger.logInfo("Please use updated Platform Password for connecting NetAN database in Network Analytics Server Features.", $true)
        stageExit($MyInvocation.MyCommand)
    }

    Function StopService($service) {
       
        
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
                    
                    Exit
                }
            }
    
        } else {
            $logger.logError($MyInvocation, "Service $($service) not found.
                Please check server install was executed correctly")
          
            Exit
        }
        
       
    }
    
    
    
    Function StartService($service) {
    
        $logger.logInfo("Preparing to Start NetAn Server", $True)
        $serviceExists = Test-ServiceExists $($service)
        $logger.logInfo("Service $($service) found: $serviceExists", $True)
        if ($serviceExists) {
            
            Set-Service $($service) -StartupType Automatic
            $isRunning = Test-ServiceRunning $($service)
    
            if ($isRunning) {
                $logger.logInfo("NetAn Server is already running....", $True)
            } else {
    
                try {
                    $logger.logInfo("Starting service....", $True)
                    Start-Service -Name $($service) -ErrorAction stop -WarningAction SilentlyContinue
                    while(!$isRunning){
                    Start-Sleep -s 25
                    $isRunning = Test-ServiceRunning $($service)
                    $logger.logInfo("Service $($service) is Running: $isRunning", $True)
    
                    }
                } catch {
                    $errorMessage = $_.Exception.Message
                    $logger.logError($MyInvocation, "Could not start service. `n $errorMessage", $True)
                }
            }
    
          
    
        } else {
            $logger.logError($MyInvocation, "Service $($installParams.serviceNetAnServer) not found.
                Please check server install was executed correctly")
           
            Exit
        }
    }


    


    Function Update-Deployment() {
        param (
            [hashtable] $map,
            [array] $stages
        )
    
        foreach ($stage in $stages) {
            if ($stage) {
                $arguments = "bootstrap -f -n -c $($installParams.dbDriverClass) -d $($installParams.dbURL) -u $($installParams.dbUser) -p $($installParams.newpass) -t $($installParams.newpass)"
                $arguments_lg = "config-action-log-database-logger --database-url=$($installParams.actiondbURL) --driver-class=$($installParams.dbDriverClass) -u $($installParams.dbUser) -p $($installParams.newpass) --log-local-time=true --pruning-period=168"
                $argument_im = "import-config -t $($installParams.newpass) -c `"Configupdate`""
                $arguments_ex = "export-config -f -t $($installParams.newpass)"
                $logger.logInfo("Executing Stage $stage", $true)
                
                if ($stage -eq 'bootstrap')
               { $successful = Use-ConfigTool $arguments $installParams $configToolLogfile
    
                if ($successful) {
                    $logger.logInfo("$stage updation executed successfully", $true)
                    continue
                } else {
                    $logger.logError($MyInvocation, "Error while executing Stage $stage", $True)
                    return $False
                }}
                if ($stage -eq 'config-action-log-database-logger')
                { $successful = Use-ConfigTool $arguments_lg $installParams $configToolLogfile
     
                 if ($successful) {
                     $logger.logInfo("$stage updation executed successfully", $true)
                     continue
                 } else {
                     $logger.logError($MyInvocation, "Error while executing Stage $stage", $True)
                     return $False
                 }}
                 if ($stage -eq 'export-config')
               { $successful = Use-ConfigTool $arguments_ex $installParams $configToolLogfile
    
                if ($successful) {
                    $logger.logInfo("$stage updation executed successfully", $true)
                    continue
                } else {
                    $logger.logError($MyInvocation, "Error while executing Stage $stage", $True)
                    return $False
                }}
                if ($stage -eq 'import-config')
               { $successful = Use-ConfigTool $argument_im $installParams $configToolLogfile
    
                if ($successful) {
                    $logger.logInfo("$stage updation executed successfully", $true)
                    continue
                } else {
                    $logger.logError($MyInvocation, "Error while executing Stage $stage", $True)
                    return $False
                }}

                    }
        }
        return $True
    }

    Function Use-ConfigTool() {
        param(
            [string] $command,
            [hashtable] $map,
            [string] $logFile = $null
        )
    
        #location setting as config.bat creates file in bin directory
    
        $loc = Get-Location
        Set-Location $($installParams.spotfirebin)

        $configTool = $installParams.spotfirebin + "config.bat"
        $logger.logInfo("Starting $configTool process")
    
        try {
            if ($logFile) {
                $cfgProcess = Start-Process $configTool -ArgumentList $command -Wait -PassThru -NoNewWindow -RedirectStandardOutput $logFile
                cat $logFile >> $PERM_CONFIG_LOGFILE -ea SilentlyContinue
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
            return $False
        } else {
            $logger.logInfo("Configuration Command Successful: Exit Code " + $cfgProcess.ExitCode)
            return $True
        }
    }

    Function stageEnter([string]$myText) {
        $Script:stage=$Script:stage+1
        $logger.logInfo("------------------------------------------------------", $True)
        $logger.logInfo("|         Entering Stage $($Script:stage) - $myText", $True)
        $logger.logInfo("|", $True) 
    }
    
    Function stageExit([string]$myText) {
        $logger.logInfo("|", $True)
        $logger.logInfo("|         Exiting Stage $($Script:stage) - $myText", $True)
        $logger.logInfo("------------------------------------------------------`n", $True)
    }


Function Main() {
    InitiateLogs
	CheckUserExists
    CheckPassword
    InputDbpassword
    VerifyUser
   if($global:checkusernetan -eq $true){
        UpdateDbpassword
        UpdateBootStrap
        ExportConfig
        Updateactiondb
        ImportConfig
        FollowInstruction
      }
       if($global:checkusernetan -eq $false){
            UpdateDbpassword }
        
    
}

Main