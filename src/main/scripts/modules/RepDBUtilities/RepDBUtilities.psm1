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
# Name    : InsertUserDataDB.psm1
# Date    : 20/08/2020
# Purpose : To insert data regarding number and types of users on Network Analytics
#           Server to the netAnServer_repdb database for audit usage.
#          
# Usage   : Insert-UserDatatoDB $usersData $password $table
#
$loc = Get-Location
Import-Module Logger
Import-Module NetAnServerUtility
Set-Location $loc

##### Logging SetUp #####
$DRIVE = (Get-ChildItem Env:SystemDrive).value
$REPDBUTIL_LOG_DIR = "$DRIVE\Ericsson\NetAnServer\Logs\rep_db"
$trDir = "C:\temp_tr\userAudit\"

if ( -not (Test-Path $REPDBUTIL_LOG_DIR )) {
    New-Item $REPDBUTIL_LOG_DIR -Type Directory | Out-Null
}


$logger = Get-Logger("RepDBUtilities")
$logger.timestamp = ""
$logger.setLogDirectory($REPDBUTIL_LOG_DIR)

$USER_RECORD_FIELDS = @(
    'timestamp',
    'analyst',
    'author',
    'consumer',
    'other',
    'total'
)

$FEATURE_RECORD_FIELDS = @(
    'feature_name',
    'product_id',
    'release',
    'rstate',
    'build',
    'library_path'
)

$PLATFORM_RECORD_FIELDS = @(
    'product_id',
    'product_name',
    'release',
    'rstate',
    'build',
    'status',
    'install_date'
)

$DB = 'netanserver_repdb'
$SERVER = 'localhost'
$USER = 'netanserver'

$FEATURE_STATUS_REMOVED = 'REMOVED'
$FEATURE_STATUS_INSTALLED = 'INSTALLED'
$PLATFORM_STATUS_ACTIVE = 'ACTIVE'
$PLATFORM_STATUS_REMOVED = 'REMOVED'

##tables
$NETWORK_ANALYTICS_PLATFORM_TABLE = "network_analytics_platform"
$FEATURE_TABLE = 'network_analytics_feature'

### Function: Insert-UserDatatoDB ###
#
#    Inserts user data into either the concurrent_users or the defined_users
#    table in  the netanserver_repdb
#
# Arguments:
#       [hashtable] $usersData
#       [string] $password
#       [string] $table
# Return Values:
#       [boolean] [string]
# Throws:
#       None
#
Function Insert-UserDatatoDB() {
    param(
       [hashtable]$usersData,
       [string] $password,
       [string] $table
    )

   $query = "INSERT INTO $($table) " +
                    "($($USER_RECORD_FIELDS[0]), " + 
                    "$($USER_RECORD_FIELDS[1]), " + 
                    "$($USER_RECORD_FIELDS[2]), " +
                    "$($USER_RECORD_FIELDS[3]), " + 
                    "$($USER_RECORD_FIELDS[4]), " + 
                    "$($USER_RECORD_FIELDS[5])) " +
            "VALUES " + 
                "('$($usersData['TIMESTAMP'])'," +
                "'$($usersData['ANALYST'])', " + 
                "'$($usersData['AUTHOR'])', " + 
                "'$($usersData['CONSUMER'])', " + 
                "'$($usersData['OTHER'])', " + 
                "'$($usersData['TOTAL'])')" 
  
    $insertUserData = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action insert


    return $insertUserData   

 }

### Function: Add-PlatformVersionToDB ###
#
#    Inserts paltform version data to the network_analytics_platform
#    table in the netAnServer_repdb
#
# Arguments:
#       [hashtable] $platformData
#       [string] $password
# Return Values:
#       [boolean] [string] / SQL object
# Throws:
#       None
#
Function Add-PlatformVersionToDB() {
    param(
       [hashtable]$platformData,
       [string] $password
    )

   $query = "INSERT INTO $($NETWORK_ANALYTICS_PLATFORM_TABLE) " +
                    "($($PLATFORM_RECORD_FIELDS[0]), " +
                    "$($PLATFORM_RECORD_FIELDS[1]), " +
                    "$($PLATFORM_RECORD_FIELDS[2]), " +
                    "$($PLATFORM_RECORD_FIELDS[3]), " +
                    "$($PLATFORM_RECORD_FIELDS[4]), " +
                    "$($PLATFORM_RECORD_FIELDS[5])) " +
            "VALUES " +
                "('$($platformData['product_id'])'," +
                "'$($platformData['product_name'])'," +
                "'$($platformData['release'])', " +
                "'$($platformData['rstate'])', " +
                "'$($platformData['build'])', " +
                "'ACTIVE')"

    $insertPlatformData = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action insert

    return $insertPlatformData
 }

### Function: Get-PlatformVersionFromDB ###
#
# Get all contents from the network_analytics_platform table
#
# Arguments:
#       [string] $password
# Return Values:
#       [boolean] [string] / SQL object
# Throws:
#       None
Function Get-PlatformVersionsFromDB() {
    param(
        [string]$password,
        [boolean] $showFullHistory
    )
    $where = ""
    $query = "SELECT $($PLATFORM_RECORD_FIELDS[0]) AS `"PRODUCT-ID`", " +
                    "$($PLATFORM_RECORD_FIELDS[1]) AS `"PRODUCT-NAME`", " +
                    "$($PLATFORM_RECORD_FIELDS[2]) AS `"RELEASE`", " +
                    "$($PLATFORM_RECORD_FIELDS[3]) AS `"RSTATE`", " +
                    "$($PLATFORM_RECORD_FIELDS[4]) AS `"BUILD`", " +
                    "$($PLATFORM_RECORD_FIELDS[5]) AS `"STATUS`", " +
                    "install_date::timestamp(0) AS `"INSTALL-DATE`" FROM $($NETWORK_ANALYTICS_PLATFORM_TABLE) "

    if ( ! ($showFullHistory) ) {
        $query += "WHERE status = '$($PLATFORM_STATUS_ACTIVE)' ORDER BY install_date DESC"
    } else {
        $query += "ORDER BY install_date DESC"
    }
	
    $result = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
	return $result
}


 ### Function: Write-UserAuditToFile###
#
#   Creates 2 files from the repDb user tables DefinedUsers_<date>.csv and ConcurrentUsers_<date>.csv
#   in "C:\temp_tr\userAudit\" 
#      
# Arguments:
#       [none]
#
# Return Values:
#   [None]
#
Function Write-UserAuditToFile {
   
    $definedUserTab = 'defined_users'
    $concurrentUserTab = 'concurrent_users'
    $currentTimeStamp = $(get-date -Format 'yyyyMMdd')


    while (($password -eq $null) -or ($password -eq "")) {
        Write-Host "Please enter the Network Analytics Server platform password:`n" -ForegroundColor Green  
        $password = Read-Host 
    }

    #Get and Write defined and concurrent Users to file 
    $definedUserQuery = "SELECT * FROM $($definedUserTab) WHERE timestamp::date > CURRENT_DATE + INTERVAL '-1 year'"
    $concurrentQuery = "SELECT * FROM $($concurrentUserTab) WHERE timestamp::date > CURRENT_DATE + INTERVAL '-1 year'"

    Try {
        $definedResult = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $definedUserQuery -Action fetch
        $concurrentResult = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $concurrentQuery -Action fetch
        } Catch {
            $logger.logError($MyInvocation, $definedResult[0])
            $logger.logError($MyInvocation, $concurrentResult[0])
        }

    If (($definedResult[0]) -and ($concurrentResult[0])){
        Try {

            If ( -not (Test-Path $trDir)) {
                New-Item $trDir -Type Directory | Out-Null
            }
            
            $definedResult[1] | Export-Csv $trDir'DefinedUsers_'$currentTimeStamp'.csv' -NoTypeInformation
            $concurrentResult[1] | Export-Csv $trDir'ConcurrentUsers_'$currentTimeStamp'.csv' -NoTypeInformation
            Write-Host "User Audit files created in: $trDir" -ForegroundColor Green
            Set-Location $loc
        } Catch {
            $logger.logError($MyInvocation, 'Error writing user audit to file.')        
        }
    } Else {
        If (!$definedResult[0]) {
            Write-Host "Error retrieving data from database. $($definedResult[1])." -ForegroundColor Red
            $logger.logError($MyInvocation, 'Error reading data from RepDb')
            Set-Location $loc
        } Elseif (!$concurrentResult[0]){
            Write-Host "Error retrieving data from database. $($concurrentResult[1])." -ForegroundColor Red
            $logger.logError($MyInvocation, $concurrentResult[1]) 
            Set-Location $loc
        } Else {
             Write-Host "Error retrieving data from database." -ForegroundColor Red
            $logger.logError($MyInvocation, "Error retrieving data from database.") 
            Set-Location $loc
        }
        
    }
}


### Function: Add-FeatureRecord ###
#
#   Adds a feature record to the 'network_analytics_feature' table in the
#   netAnServer_repdb database. This Function updates a previously "INSTALLED"
#   feature (by product_id) to "REMOVED" and inserts a new record based on the hashtable
#   that it is passed.
#
#   For a record to be inserted it must pass the Test-Record Criteria See Function Test-Record.
#
#   !!! This Function does not validate build numbers. If this function is called with an older
#   build number in the $record hashtable, this older build number will be inserted as the latest
#   'INSTALLED' record. !!!
#
#   Please see function Test-ShouldFeatureBeInstalled
#
#
# Arguments:
#   [hashtable]$fileName,
#   [string] $password
#
# Return Values:
#   [boolean]$true|$false
#
Function Add-FeatureRecord() {
    param(
        [hashtable] $record,
        [string] $password
    )

    $logger.logInfo("Inserting Record $record")
    $isValidRecord = Test-Record -record $record

    if (!$isValidRecord[0]) {
        $logger.logError($MyInvocation, "Invalid Record for $($isValidRecord[1]) " +
            "$($record.Keys) $($record.Values)")
        return $False
    }

    $record['status'] = $FEATURE_STATUS_INSTALLED
    $oldFeatureRecord = Get-InstalledFeatureRecord -product_number $record['product_id'] -password $password

    if ($oldFeatureRecord) {
        $oldFeatureRecord['status'] = $FEATURE_STATUS_REMOVED
        $logger.logInfo("Updating previous feature $($oldFeatureRecord['feature_name']) " +
            "$($oldFeatureRecord['product_id']) to '$($oldFeatureRecord['status'])'")

        Update-FeatureStatus -record $oldFeatureRecord -password $password
    }

    Add-NewFeatureRecord -record $record -password $password
    return $True
}


### Function: Test-Record ###
#
#   Tests a hashtable to ensure that all required keys are present for insertion into the
#   'NETWORK_ANALYTICS_FEATURE' table.
#
# Arguments:
#        [hashtable] $record
#
# Return Values:
#        [list]
#
Function Test-Record() {
    param(
        [hashtable] $record
    )
    return $(Test-MapForKeys -map $record -requiredKeys $FEATURE_RECORD_FIELDS)
}


### Function: Get-InstalledFeatureRecord ###
#
#   This function returns the record which matches the product number and has a
#   status set to 'INSTALLED'. This method should only ever return a single record.
#
# Arguments:
#        [string] $product_number,
#        [string] $password
#
# Return Values:
#        [hashtable]
#
Function Get-InstalledFeatureRecord() {
    param(
        [string] $product_number,
        [string] $password
    )

    $product_number = $product_number -replace '[-, ,/,_,\\]', ''
    $query = "SELECT * FROM $($FEATURE_TABLE) WHERE $($FEATURE_RECORD_FIELDS[1]) = '$($product_number)' AND status = '$($FEATURE_STATUS_INSTALLED)'"
    $result = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch

    $isSuccesfull = $result[0]

    if ($isSuccesfull) {
        $hash = @{}

        if ($result[1].Rows.Count -ne 0) {
            foreach ($column in $result[1].Columns) {
                $colName = $column.ColumnName
                $hash.Add($colName, $result[1].($colName))
            }

            $result[1] = $hash
            return $result[1]
        }
    } else {
        $logger.logError($MyInvocation, "Previous Feature install detection failed with message:`n $($result[1])")
    }
}


### Function: Update-FeatureStatus ###
#
#   This function updates the status field of a record in the 'NETWORK_ANALYTICS_FEATURE' table and
#   sets the status to 'INSTALLED'.
#
# Arguments:
#        [hashtable] $record,
#        [string] $password
#
# Return Values:
#        none
#
Function Update-FeatureStatus() {
    param(
        [hashtable] $record,
        [string] $password
    )

    $query = "UPDATE $($FEATURE_TABLE) SET " +
             "status='$($record['status'])' " +
             "WHERE $($FEATURE_RECORD_FIELDS[1])='$($record['product_id'])' AND " +
             "$($FEATURE_RECORD_FIELDS[4])='$($record['build'])' "

    $result = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action insert
    $isSuccesfull = $result[0]

    if ($isSuccesfull) {
        $logger.logInfo("Feature Status updated: $($record['product_id']) $($record['build']) status = $($record['status'])")
        return
    } else {
        $logger.logError($MyInvocation, "Previous Feature install detection failed with message:`n $($result[1])")
    }
}

### Function: Update-PlatformStatus ###
#
#   This function updates the status field of a record in the 'NETWORK_ANALYTICS_PLATFORM' table and
#   sets the status to 'REMOVED'.
#
# Arguments:
#        [object] $record,
#        [string] $password
#
# Return Values:
#        boolean
#
Function Update-PlatformStatus() {
    param(
        [object] $record,
        [string] $password
    )

    $query = "UPDATE $($NETWORK_ANALYTICS_PLATFORM_TABLE) SET " +
             "status='$($PLATFORM_STATUS_REMOVED)' " +
             "WHERE $($PLATFORM_RECORD_FIELDS[0])='$($record.'product_id')' AND " +
             "$($PLATFORM_RECORD_FIELDS[4])='$($record.build)' "


    $result = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action insert
    $isSuccesfull = $result[0]
    if ($isSuccesfull) {
        $logger.logInfo("Platform Status for $(($record.'product_id').trim()) $(($record.build).trim()) is updated to $($PLATFORM_STATUS_REMOVED)")
        return $isSuccesfull

    } else {
        $logger.logError($MyInvocation, "Previous Feature install detection failed:`n $($result[1])")
        return $isSuccesfull

    }
}


### Function: Add-NewFeatureRecord ###
#
#   This function inserts a new record in the 'NETWORK_ANALYTICS_FEATURE' table.
#
# Arguments:
#        [hashtable] $record,
#        [string] $password
#
# Return Values:
#        none
#
Function Add-NewFeatureRecord() {
    param(
        [hashtable] $record,
        [string] $password
    )

    $record['product_id'] = $record['product_id'] -replace '[-, ,/,_,\\]', ''
    $record['build'] = $record['build'] -replace '[-, ,/,_,\\]', ''

    $query = "INSERT INTO $($FEATURE_TABLE) " +
                    "($($FEATURE_RECORD_FIELDS[0]), " +
                    "$($FEATURE_RECORD_FIELDS[1]), " +
                    "$($FEATURE_RECORD_FIELDS[2]), " +
                    "$($FEATURE_RECORD_FIELDS[3]), " +
                    "$($FEATURE_RECORD_FIELDS[4]), " +
                    "status, " +
                    "$($FEATURE_RECORD_FIELDS[5])) " +
            "VALUES " +
                "('$($record['feature_name'])', " +
                "'$($record['product_id'])', " +
                "'$($record['release'])', " +
                "'$($record['rstate'])', " +
                "'$($record['build'])', " +
                "'$($record['status'])', " +
                "'$($record['library_path'])')"

    $result = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action insert
    $isSuccesfull = $result[0]

    if ($isSuccesfull) {
        $logger.logInfo("Feature Record inserted: $($record['product_id']) $($record['build']) status = $($record['status'])")
        return
    } else {
        $logger.logError($MyInvocation, "Error inserting record $($record.Values). Failed with message:`n $($result[1])")
    }
}

### Function: Test-ShouldFeatureBeInstalled ###
#
#   Tests if a feature is previously installed.
#   This function uses the build number and the product number as criteria to test if a feature is installed and returns the RSTATE
#   if it is installed.
#
# Arguments:
#   [string] $productNumber,
#   [string] $password
#
# Return Values:
#   [list] $result
#
Function Test-IsFeatureInstalled() {
    param(
        [string] $productNumber,
        [string] $password
    )

    $query = "SELECT $($FEATURE_RECORD_FIELDS[4]) FROM $($FEATURE_TABLE) WHERE $($FEATURE_RECORD_FIELDS[1]) = '$($productNumber)' AND status = '$($FEATURE_STATUS_INSTALLED)'"
    $result = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
    return $result
}


### Function: Test-IsPlatformInstalled ###
#
#
# Arguments:
#       [string] $productNumber
#       [string] $password
# Return Values:
#       [List]
# Throws:
#       None
Function Test-IsPlatformInstalled() {
    param(
        [string] $productNumber,
        [string] $password
    )   

    $query = "SELECT $($PLATFORM_RECORD_FIELDS[0]), $($PLATFORM_RECORD_FIELDS[4])  FROM $($NETWORK_ANALYTICS_PLATFORM_TABLE) WHERE $($PLATFORM_RECORD_FIELDS[0]) = '$($productNumber)' AND status = '$($PLATFORM_STATUS_ACTIVE)'"

    $result = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch 
    
     if($result[1]){
        $logger.logInfo("The Netanserver platform is already installed", $False)
        return $result
    }
    $logger.logInfo("The Netanserver platform is not installed", $False)
    return @($False, $result[1])
}


### Function: Get-InstalledFeatures ###
#
#   Returns a list or a single data row containing feature history
#   from the 'NETWORK_ANALYTICS_FEATURE' table.
#
# Arguments:
#       [switch] $ALL - returns full version history
#
# Return Values:
#   [System.Data.DataRow]
#
Function Get-Features() {
    <#
        .SYNOPSIS
        Get-Features displays information of installed features on the Network Analytics Server platform
        .DESCRIPTION
        The function returns all currently installed features on the platform
        as well as a full history of previously installed version of the feature.

        If the -FULL_HISTORY switch is used, a full history of all features will be returned.
        if the switch is ommited, it will return a list of installed features.

        .EXAMPLE
        Get-Features

        FEATURE-NAME : Ericsson-LTE-Call-Failure-Analysis
        PRODUCT-ID   : CNAXXXXXXXX
        RELEASE      : 16A
        RSTATE       : R2A
        BUILD        : R2A06
        STATUS       : INSTALLED
        LIBRARY-PATH : /Ericsson Library/LTE/Ericsson-LTE-Call-Failure-Analysis
        INSTALL-DATE : YYYY-MM-DD HH:MM:SS

        .EXAMPLE
        Get-Features -FULL_HISTORY

        FEATURE-NAME : Ericsson-LTE-Call-Failure-Analysis
        PRODUCT-ID   : CNAXXXXXXXX
        RELEASE      : 16A
        RSTATE       : R2A
        BUILD        : R2A06
        STATUS       : REMOVED
        LIBRARY-PATH : /Ericsson Library/LTE/Ericsson-LTE-Call-Failure-Analysis
        INSTALL-DATE : YYYY-MM-DD HH:MM:SS

        FEATURE-NAME : Ericsson-LTE-Call-Failure-Analysis
        PRODUCT-ID   : CNAXXXXXXXX
        RELEASE      : 16A
        RSTATE       : R2A
        BUILD        : R2A07
        STATUS       : INSTALLED
        LIBRARY-PATH : /Ericsson Library/LTE/Ericsson-LTE-Call-Failure-Analysis
        INSTALL-DATE : YYYY-MM-DD HH:MM:SS


        .PARAMETER FULL_HISTORY
        A switch to optionally return a full history of installed features on the platform
    #>
    param (
        [switch] $FULL_HISTORY
    )
    $envVariable = "NetAnVar"
    $password = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password

    $query = "SELECT $($FEATURE_RECORD_FIELDS[0]) AS `"FEATURE-NAME`", " +
            "$($FEATURE_RECORD_FIELDS[1]) AS `"PRODUCT-ID`", " +
            "$($FEATURE_RECORD_FIELDS[2]) AS `"RELEASE`", " +
            "$($FEATURE_RECORD_FIELDS[3]) AS `"RSTATE`", " +
            "$($FEATURE_RECORD_FIELDS[4]) AS `"BUILD`", " +
            "status AS `"STATUS`", " +
            "$($FEATURE_RECORD_FIELDS[5]) AS `"LIBRARY-PATH`", " +
            "install_date::timestamp(0) AS `"INSTALL-DATE`" FROM $($FEATURE_TABLE) "

    if(-not $FULL_HISTORY) {
        $query += "WHERE status = '$($FEATURE_STATUS_INSTALLED)' ORDER BY install_date DESC"
    } else {
        $query += "ORDER BY install_date DESC"
    }

    $result = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch

    if ($result[0]) {
        return $result[1]
    } else {
        Write-Host "Error occurred with command`n$($result[1])" -ForegroundColor Red
    }
}
