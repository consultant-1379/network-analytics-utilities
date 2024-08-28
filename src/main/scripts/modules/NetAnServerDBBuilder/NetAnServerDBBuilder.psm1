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
# Name    : NetAnServerDBBuilder.psm1
# Date    : 20/08/2020
# Purpose : Create all required databases for the Network Analytics Platform and
#           Feature Installations
#
#
# Usage   : Create-Databases $installParams
#

$loc = Get-Location
Import-Module Logger
Import-Module NetAnServerUtility

$logger = Get-Logger($LoggerNames.Install)
$SQL_TIMEOUT = 60            # 1 minute
$PROCESS_TIMEOUT = 60000     # 1 minute (in milliseconds)

$requiredParamKeys = @(
	'createDBScript',
	'dbName',
    'connectIdentifer',
    'sqlAdminUser', 
    'sqlAdminPassword', 
    'dbUser', 
    'dbPassword', 
	'PSQL_PATH',
    'createDBLog',
    'repDbName',
    'repDbDumpFile',
    'createActionLogDBScript',
    'actionLogdbName',
    'createActionLogDBLog'
)

### Function: Create-Databases ###
#
#    Creates all required databases for the 
#    Network Analytics Server Platform and Feature Installation
#
# Arguments:
#       [hashtable] $map
# Return Values:
#       [boolean] 
# Throws:
#       None
#
Function Create-Databases() {
    param(
        [hashtable]$map 
    )
    
    #Validate required module parameters
    $logger.logInfo("Verifying parameters for NetAnServerDBBuilder.Create-Databases", $False)    
    $paramsValid = Approve-Params $map $requiredParamKeys
    
    if ( -not ($paramsValid[0])) {
        $logger.logError($MyInvocation, $paramsValid[1], $False)
        return $False
    }   

    $logger.logInfo($paramsValid[1], $False)
          
    
    #Check sql server is running
    $logger.logInfo("Verifying PostgreSQL instance is running.", $False) 
    $sqlServerState = Get-ServiceState("postgresql-x64-" +(((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).MajorVersion) | measure -Maximum).Maximum)

    if ( -not ($sqlServerState -eq 'Running')) {
        $logger.logError($MyInvocation, "PostgreSQL Server state: $sqlServerState", $False)
        return $False
    }



    $logger.logInfo("PostgreSQL Server $sqlServerState.", $True)


    #Install Databases
    $netAnServDBInstalled = Create-NetAnServerDB $map
    
    if ( -not $netAnServDBInstalled) {
        return $netAnServerDBInstalled
    }
    $netAnServDBInstalled = Create-NetAnServerActionDB $map
    
    if ( -not $netAnServDBInstalled) {
        return $netAnServerDBInstalled
    }

    $nasRepDBInstalled = Create-NetAnServerRepDB $map
    return $nasRepDBInstalled
}





### Function: Create-NetAnServerDB ###
#
#    Create the PostgreSQL NetAnServer database
#
# Arguments:
#       $installParams @{createDBScript, dbName, connectIdentifer, sqlAdminUser, sqlAdminPassword, dbUser, dbPassword, PSQL_PATH, createDBLog }
# Return Values:
#       [boolean]
# Throws:
#       None
#
Function Create-NetAnServerDB() {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$installParams 
    )

    $netAnServerDB = $installParams.dbName
    $dbInstalled = Check-DBInstalled $netAnServerDB $installParams

    if (-not $dbInstalled) {

        $logger.logInfo("Create PostgreSQL database $netAnServerDB started.", $True)

        if (Test-FileExists($installParams.createDBScript)) {
            $installArgs = "" + $installParams.connectIdentifer + " " + $installParams.sqlAdminPassword + " " + 
                            $installParams.dbName +" "+ $installParams.dbUser + " " + $installParams.dbPassword + " " + "`""+$installParams.PSQL_PATH +"`""
            $workingDir = Split-Path $installParams.createDBScript

            try {
                $process = Start-Process -FilePath $installParams.createDBScript -ArgumentList $installArgs -WorkingDirectory $workingDir -Wait -PassThru -RedirectStandardOutput $installParams.createDBLog -ErrorAction Stop
            } catch {
                $logger.logInfo($MyInvocation, "Error creating Database $netAnServerDB", $True)
                return $False
            }            
                    
            if ($process.ExitCode -eq 0) {
                $logger.logInfo("PostgreSQL database $netAnServerDB created successfully.", $True)
                Copy-LogFile $installParams
                return $True
            } else {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Creating the PostgreSQL database $netAnServerDB failed. $errorMessage", $True)
                return $False
            }
         } else { 
            $logger.logError($MyInvocation, "The create database batch file at location " + $installParams.createDBScript + " does not exist, please re-check the installation", $True)
            return $False
         }
    }
    
    $logger.logInfo("Database $netAnServerDB is already installed", $False)
    return $dbInstalled        
}

### Function: Create-NetAnServerActionDB ###
#
#    Create the PostgreSQL NetAnServer Actionlog  database
#
# Arguments:
#       $installParams @{createActionLogDBScript, actionLogdbName, connectIdentifer, sqlAdminUser, sqlAdminPassword, dbUser, dbPassword, PSQL_PATH, createActionLogDBScript }
# Return Values:
#       [boolean]
# Throws:
#       None
#
Function Create-NetAnServerActionDB() {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$installParams 
    )

    $netAnServerDB = $installParams.actionLogdbName
    $dbInstalled = Check-DBInstalled $netAnServerDB $installParams

    if (-not $dbInstalled) {

        $logger.logInfo("Create PostgreSQL database $netAnServerDB started.", $True)

        if (Test-FileExists($installParams.createActionLogDBScript)) {
            $installArgs = "" + $installParams.connectIdentifer + " " + $installParams.sqlAdminPassword + " " + 
                            $installParams.actionLogdbName +" "+ $installParams.dbUser + " " + $installParams.dbPassword + " " + "`""+$installParams.PSQL_PATH +"`""
            $workingDir = Split-Path $installParams.createActionLogDBScript

            try {
                $process = Start-Process -FilePath $installParams.createActionLogDBScript -ArgumentList $installArgs -WorkingDirectory $workingDir -Wait -PassThru -RedirectStandardOutput $installParams.createActionLogDBLog -ErrorAction Stop
            } catch {
                $logger.logInfo($MyInvocation, "Error creating Database $netAnServerDB", $True)
                return $False
            }            
                    
            if ($process.ExitCode -eq 0) {
                $logger.logInfo("PostgreSQL database $netAnServerDB created successfully.", $True)
                return $True
            } else {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Creating the PostgreSQL database $netAnServerDB failed. $errorMessage", $True)
                return $False
            }
         } else { 
            $logger.logError($MyInvocation, "The create database batch file at location " + $installParams.createActionLogDBScript + " does not exist, please re-check the installation", $True)
            return $False
         }
    }
    
    $logger.logInfo("Database $netAnServerDB is already installed", $False)
    return $dbInstalled        
}

### Function: Create-NetAnServerRepDB ###
#
#    Create the PostgreSQL NetAnServer RepDB database
#
# Arguments:
#       [hashtable]$map
# Return Values:
#       [boolean]
# Throws:
#       None
#
Function Create-NetAnServerRepDB() {
        param(
        [Parameter(Mandatory=$true)]
        [hashtable] $map 
    )

    
    $repDbDump = $map.repDbDumpFile
    $repDbName = $map.repDbName
    $saUser = $map.sqlAdminUser
    $saPassword = $map.sqlAdminPassword
    $serverInstance = $map.connectIdentifer

    $logger.LogInfo("Starting creation of $repDbName", $False)

    #Test sql dump file exists
    if ( -not (Test-FileExists $repDbDump)) {
        $logger.logError($MyInvocation, "RepDB SQL file $repDbDump cannot be found.", $True)
        return $False
    }

    #Test if database is previously installed
    $isInstalled = Check-DBInstalled $repDbName $map

    if ($isInstalled) {

        $logger.logInfo("Database $repDbName is already installed", $False)
        return $isInstalled
    } 

    #Create the database
    try {
        $logger.logInfo("Creating Database $repDbName", $True)
		$query = "create database " + $repDbName + ";"
		$output = Invoke-UtilitiesSQL postgres $saUser $saPassword $serverInstance $query insert
		$query = get-content $repDbDump | out-string
      	$output = Invoke-UtilitiesSQL $repDbName $saUser $saPassword $serverInstance $query insert 
        if ($?) {
            $logger.logInfo("Database $repDbName created successfully", $True)
            return $True
        }

    } catch {
        $logger.LogError($MyInvocation, "Error Creating the Network Analytics Server RepDB $_.Exception.Message", $True)
        return $False
    } finally {
        Set-Location $loc
    }
}


### Function: Check-DBInstalled ###
#
#    Check if the $databaseName is already exists.
#
# Arguments:
#       [string] $databaseName
#       [hashtable] $installParams
# Return Values:
#       [boolean]
# Throws:
#       None
#
Function Check-DBInstalled() {
    param(
        [string] $databaseName,
        [Parameter(Mandatory=$true)]
        [hashtable]$installParams
    )
    
    try {
        $logger.logInfo("Checking if the database $databaseName already exists", $True)
		$query = "select datname from pg_database where datistemplate = false;"
        $output = Invoke-UtilitiesSQL postgres $installParams.sqlAdminUser $installParams.sqlAdminPassword $installParams.connectIdentifer $query fetch

    } catch {
        $logger.logError($MyInvocation, " $_.Exception.Message Please check entered password " + 
            "is correct for PostgreSQL Server Administrator " + $installParams.sqlAdminUser , $True) 
        Exit
    }
 
    finally {
        Set-Location $loc
    }

    if ($output[1].datname.Contains($databaseName)) {
															   
        return $True
		$logger.logInfo("Database $databaseName exists", $True) 
     } else {
        $logger.logInfo("Database $databaseName does not exist", $True)
        return $False
     }
}




### Function: Copy-LogFile ###
#
#   Copies the created log generated from Network Analtics Server 
#   platfrom Database creation to the common installation log directory
#
# Arguments:
#   [hashtable] $installParams 
#  
# Return Values:
#   [boolean]$true|$false
#
Function Copy-LogFile(){
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$installParams
    )
    if (Test-FileExists($installParams.databaseLog)) {
        Copy-Item -Path $installParams.databaseLog -Destination $installParams.logDir -Force
        $logger.logInfo("Logfile log.txt moved to "+$installParams.logDir , $True)
        return $True
    } else {
        $logger.logError($MyInvocation, "Logfile "+ $installParams.databaseLog +" does not exist" , $True)
        return $False
    }
}



### Function: Approve-Params ###
#
#   Validates the map parameters. Checks that all required 
#   Parameters are present and not $null
#
# Arguments:
#   [hashtable] $map - map of all installation parameters
#   [list] $paramKeys - list of required parameters
#  
# Return Values:
#   [boolean]$true|$false
#
Function Approve-Params() {
    param(
       [hashtable] $map,
       [array] $paramKeys
    )
    $isValid = Test-MapForKeys $map $paramKeys
    return $isValid
}


