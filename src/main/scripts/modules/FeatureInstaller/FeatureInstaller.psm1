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
# Name    : FeatureInstaller.psm1
# Date    : 20/08/2020
# Purpose : Module Used for Installation of Network Analytics Features
#

Import-Module Logger -DisableNameChecking
Import-Module NetAnServerUtility -DisableNameChecking
Import-Module RepDBUtilities -DisableNameChecking
Import-Module NetAnServerConfig -DisableNameChecking
Import-Module ZipUnZip -DisableNameChecking
Import-Module SearchReplace -DisableNameChecking
Import-Module ManageUsersUtility -DisableNameChecking

$CUSTOM_LIBRARY = "Custom Library"
$ERICSSON_LIBRARY = "Ericsson Library"
$DB = 'netanserver_db'
$SERVER = 'localhost'
$USER = 'netanserver'
$SQL_SERVICE = "postgresql-x64-" +(((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).MajorVersion) | measure -Maximum).Maximum


#stores all temp directories created during feature install
[System.Collections.ArrayList]$TmpDirArrayList = @()

$XML_SCHEMA = @('product_id', 
                'feature_name', 
                'release', 
                'system_area', 
                'datasource_guid', 
                'rstate', 
                'build', 
                'library_path')

$restoreResourcesPath = "C:\Ericsson\NetAnServer\RestoreDataResources\"
[xml]$xmlObj = Get-Content "$($restoreResourcesPath)\version\supported_NetAnPlatform_versions.xml"
$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")

foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'y') {
            $version = $platformVersionString.'version'
        }
}
$DRIVE = (Get-ChildItem Env:SystemDrive).value
$NETANSERV_HOME = "$($DRIVE)\Ericsson\NetAnServer"
$TOMCAT = "$($NETANSERV_HOME)\Server\$($version)\tomcat"
$DEFAULT_FOLDER_DIR = "$($NETANSERV_HOME)\feature_installation\resources\folder"
$TEMP_DIR_PATH = "$($NETANSERV_HOME)\feature_installation\resources"
$FEATURE_LOG_DIR = "$($NETANSERV_HOME)\Logs\feature_installation"
$TEMP_CONFIG_LOG_FILE = "$($NETANSERV_HOME)\Logs\feature_installation\config.temp.log"

if ( -not (Test-Path $FEATURE_LOG_DIR)) {
    New-Item $FEATURE_LOG_DIR -Type Directory | Out-Null
}


$script:analysisExe = "Analysis.part0.exe"
$script:infoPackageExe = "InformationPackage.part0.exe"
$script:featureReleaseFilename = "feature-release.xml"

$global:logger = Get-Logger("feature-installer")
$logger.setLogDirectory($FEATURE_LOG_DIR)
$logger.timestamp = 'feature'
$logger.setLogname('installer.log')


Function Install-Feature() {
        param(
        [string] $featurePackage,
        [switch] $FORCE
    )
        <#
        .SYNOPSIS
        Install-Feature installs features for use on the Network Analytics Server platform
        .DESCRIPTION
        This function installs Network Analytics Server features on the Network Analytics Server platform.
        The parameter to this function is the feature package to install.
        This feature package MUST be the the full absolute path to the package.

        .EXAMPLE
        Install-Feature C:\Users\NetAnServer\Desktop\feature_name.zip 

        .EXAMPLE
        Install-Feature -featurePackage C:\Users\NetAnServer\Desktop\feature_name.zip 
        
        .PARAMETER featurePackage
        The absolute path to the feature package to install
    #>

    Import-Module FeatureInstaller -Force -DisableNameChecking
    $logger.logInfo("Install-Feature called")


    ##############################################################################
    ##                            Gather User Details                           ##
    ##############################################################################
    $logger.logInfo("Gathering user details")
    $userDetails = Get-UserDetails
    if($userDetails.username -eq $null) {
        $logger.logError($MyInvocation, "Error in retrieving platform credentials", $True)
        return 
    }
    $logger.logInfo("User details collection complete")

    
    ##############################################################################
    ##                          Validate Feature Package                        ##
    ##############################################################################
    $logger.logInfo("Extracting feature package $($featurePackage)", $True)
    $featurePackageResult = Read-FeaturePackage $featurePackage

    if (-not $featurePackageResult[0]) {
        $logger.logError($MyInvocation, $featurePackageResult[1], $True)
        return
    }
    $logger.logInfo("Feature package extracted", $True)

    $featurePackageContents = $featurePackageResult[1]


    ##############################################################################
    ##                          Parse Feature Release XML                       ##
    ##############################################################################
    $xmlFile = $featurePackageContents.Keys | findstr "feature-release*"
    $logger.logInfo("Reading contents of $($xmlFile)", $True)
    $featureReleaseDetails = Read-FeatureReleaseXml $featurePackageContents[$xmlFile]

    if ( -not $featureReleaseDetails[0]) {
        $logger.logError($MyInvocation, $featureReleaseDetails[1])
        return
    }

    [hashtable]$featureInfo = $featureReleaseDetails[1]    


    ##############################################################################
    ##             Test Should Feature be installed - netAnServer_repdb         ##
    ##############################################################################
    $featureName = $featureInfo['feature_name']
    $productId = $featureInfo['product_id']
    $buildNumber = $featureInfo['build']
    $rState = $featureInfo['rstate']
    $password = (New-Object System.Management.Automation.PSCredential 'N/A', $userDetails['password']).GetNetworkCredential().Password

    $logger.logInfo("Attempting to install feature...", $True)
    $logger.logInfo("Feature-Name: $($featureName)", $True)
    $logger.logInfo("Product-Id: $($productId)", $True)
    $logger.logInfo("Release: $($rState)", $True)
    $logger.logInfo("Build: $($buildNumber)", $True)

    if (-not $FORCE) {
        $logger.logInfo("Testing feature version against installed versions", $True)
        $shouldInstallFeature = Test-ShouldFeatureBeInstalled -productNumber $productId -build $buildNumber -password $password
        $shouldInstall = $shouldInstallFeature[0]
        $previousInstallationRecord = $shouldInstallFeature[1]
				
        if ($previousInstallationRecord) {
            $existingBuild = $($previousInstallationRecord).trim()
        }

        if ($shouldInstall) {
            if ($previousInstallationRecord) {
                $logger.logInfo("Existing feature found....", $True)
                $logger.logInfo("Build: $($existingBuild)", $True)
            } else {
                $logger.logInfo("No previous installation detected", $True)
            }
       
        } else {
            if ($previousInstallationRecord -contains "Error") {
                $logger.logError($MyInvocation, $previousInstallationRecord, $True)
                return
            }

            if ($previousInstallationRecord) {
                $logger.logWarning("This feature will not be installed. Build: $($existingBuild) is already installed", $True)
                return
            } 
        }
        
    } else {
        $logger.logWarning("Feature installation executed with -Force", $True)
    }



    ##############################################################################
    ##                    Un-Cover Licenced Executables                         ##
    ##############################################################################  

    $licenceManagerIpAddress = Test-LicenceManagerIP

    if ( -not $licenceManagerIpAddress[0]) {
        $logger.logWarning("$($licenceManagerIpAddress[1]) before proceeding with feature installation", $True)
        return
    }

    $logger.logInfo("Extracting media against licence manager on host: $($licenceManagerIpAddress[1])", $True)

    # Extract Analysis exe
    $UncoveredZipList = Unprotect-FeaturePackageContents $featurePackageContents
    
    if( -not $UncoveredZipList[0]) {
        $logger.logWarning("Media extraction failed. Please ensure the correct licence for $($featureName) $($productId) is installed on licence server $($licenceManagerIpAddress[1])", $True)
        return
    }

    $logger.logInfo("Media extraction complete", $True)
    ##############################################################################
    ##                    Update GUID in Information Package                    ##
    ############################################################################## 
    #### Prompt User for Datasource Selection #### 
    $dataSourceMap = Get-Datasource $password
    
    if(-Not $datasourceMap) {
        return 
    }

    try {
        $dsGUid = Confirm-DatasourceSelection $datasourceMap
    } catch {
        $logger.logInfo("$($_.Exception.Message)", $True)
        return         
    }
    
    $stagingArea = Get-Directory "feature-extract\staging"

    $logger.logInfo("Mapping information package to selected datasource", $True)
    #unzip information package
    $tempInformationPackageExtractionDir = "$((Get-Item $UncoveredZipList[1].Item('InformationPackage.part0.zip')).Directory.FullName)" + "/tmp-unzip"     
    $unzipped = Unzip-File "$($UncoveredZipList[1]['InformationPackage.part0.zip'])" $tempInformationPackageExtractionDir

    #exit it not unzipped
    if(-not $unzipped[0]) {
        $logger.logWarning($unzipped[1], $True)
        return
    }

    #re-map datasource GUID 
    $replaced = SearchReplace $tempInformationPackageExtractionDir $featureInfo['datasource_guid'] $dsGUid

    if(-not $replaced) {
        $logger.logWarning("Update of GUID failed in information package.", $True)
        return
    }

    #zip GUID updated files
    Zip-Dir $tempInformationPackageExtractionDir "$($UncoveredZipList[1]['InformationPackage.part0.zip'])"
    $logger.logInfo("Mapping of datasource complete", $true)

    ##############################################################################
    ##                    Create & Import Library Structure                     ##
    ############################################################################## 
    $logger.logInfo("Creating library structure $($featureInfo['library_path'])", $True)
    $isLibCreated = Add-LibraryStructure $($featureInfo['library_path']) $userDetails
	
	if (-not $isLibCreated) {
        $logger.logWarning("Library Structure $($featureInfo['library_path']) not created.", $True)
        return
    }
	
	if ($featureName.Trim() -eq "PM-Explorer") {
		$platformPassword=(New-Object System.Management.Automation.PSCredential 'N/A', $userDetails['password']).GetNetworkCredential().Password
		$logger.logInfo("Checking if folder for PM-Explorer is present in Custom Library", $True)
		$params = @{}
		$params.spotfirebin = "$($TOMCAT)\spotfire-bin\"
		$folderPath = "`"/Custom Library/PMEX Reports`""
		$reportPath = "`"$($NETANSERV_HOME)\Logs\feature_installation\Temp.txt`""
		$permissionPath = "$($NETANSERV_HOME)\Logs\feature_installation\Temp.txt"
		$PMEX_folder = "PMEX Reports"
		$pmexFolderQuery = "select item_id from lib_items where title ='PMEX Reports' and parent_id =(select item_id from lib_items where title ='Custom Library' and parent_id = (select item_id from lib_items where parent_id is null))"
		$folderUpdate = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $pmexFolderQuery -Action fetch
		$folderID = $folderUpdate[1].item_id
		if([string]::IsNullOrEmpty($folderID))
		{
			$username=Get-AdminUserName $password
			$command = "create-library-folder -t "+$platformPassword+" -l "+$folderPath+" -u "+$username
			$logger.logInfo("Folder $($PMEX_folder) Not Present in Custom Library", $True)
			$logger.logInfo("Creating Folder $($PMEX_folder) in Custom Library", $True)
			$folderCreate = Use-ConfigTool $command $params $TEMP_CONFIG_LOG_FILE
			
			if ($folderCreate[0]) {
				$response += "Folder $($PMEX_folder) created in Custom Library"
			} 
			else {
				$response += "$($folderCreate[1])"
			}
			$logger.logInfo("$($response)", $True)
		}
		$command = "show-library-permissions -t "+$platformPassword+" -l "+$folderPath+" -p "+$reportPath+" -f True"
		$folderUpdate = Use-ConfigTool $command $params $TEMP_CONFIG_LOG_FILE
		$businessAuthorQuery = "select group_id from groups where group_name = 'Business Author'"
		$businessAnalystQuery = "select group_id from groups where group_name = 'Business Analyst'"
		$everyoneQuery = "select group_id from groups where group_name = 'Everyone'"
		$result1 = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $businessAuthorQuery -Action fetch
		$businessAuthorID = $result1[1].group_id
		$result2 = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $businessAnalystQuery -Action fetch
		$businessAnalystID = $result2[1].group_id
		$pmexFolderQuery = "select item_id from lib_items where title ='PMEX Reports' and parent_id =(select item_id from lib_items where title ='Custom Library' and parent_id = (select item_id from lib_items where parent_id is null))"
		$result3 = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $pmexFolderQuery -Action fetch
		$pmexFolderID = $result3[1].item_id
		$result4 = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $everyoneQuery -Action fetch
		$everyoneID = $result4[1].group_id

		$logger.logInfo("Folder $($PMEX_folder) Already Present in Custom Library", $True)
		$logger.logInfo("Checking Permissions on Folder $($PMEX_folder) in Custom Library", $True)
		$logger.logInfo("Checking Permissions for Business Analyst Group", $True)
		$search="Business Analyst"
		$permissions = "READ","WRITE","EXECUTE"
		$BusinessAnalyst = (cat $permissionPath) -cmatch $search |ForEach-Object {($_ -split ';')[-1]}
		if(($BusinessAnalyst.count -lt 3) -and (-not ([string]::IsNullOrEmpty($businessAnalystID))))
		{
			$logger.logInfo("Setting Permissions for Business Analyst Group", $True)
			$groupPermissions = New-Object System.Collections.Generic.List[System.Object]
			if($BusinessAnalyst.count -eq 0)
			{
				$BusinessAnalyst=""
			}
			Compare-Object $permissions $BusinessAnalyst | Where-Object { $_.SideIndicator -eq '<=' } | Foreach-Object { 
			
				if($_.InputObject -eq "READ")
				{
					$query = "INSERT INTO lib_access(item_id, group_id, permission) VALUES ('$($pmexFolderID)', '$businessAnalystID','R');"
					$obj = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
					$groupPermissions.Add("Read")
				}
				elseif($_.InputObject -eq "WRITE")
				{
					$query = "INSERT INTO lib_access(item_id, group_id, permission) VALUES ('$($pmexFolderID)', '$businessAnalystID','W');"
					$obj = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
					$groupPermissions.Add("Write")
				}
				elseif($_.InputObject -eq "EXECUTE")
				{
					$query = "INSERT INTO lib_access(item_id, group_id, permission) VALUES ('$($pmexFolderID)', '$businessAnalystID','X');"
					$obj = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
					$groupPermissions.Add("Execute")
				}
			}
			[string]$csv = $null
			$csv = $groupPermissions -join ","
			$logger.logInfo("$($csv) Permissions Added for Business Analyst Group", $True)
		}
		else {
			$logger.logInfo("Required Permissions Already Set for Business Analyst Group", $True)
		}
		
		$logger.logInfo("Checking Permissions for Business Author Group", $True)
		$search="Business Author"
		$permissions = "READ","WRITE","EXECUTE"
		$BusinessAuthor = (cat $permissionPath) -cmatch $search |ForEach-Object {($_ -split ';')[-1]}
		if(($BusinessAuthor.count -lt 3) -and (-not ([string]::IsNullOrEmpty($businessAuthorID))))
		{
			$logger.logInfo("Setting Permissions for Business Author Group", $True)
			$groupPermissions = New-Object System.Collections.Generic.List[System.Object]
			if($BusinessAuthor.count -eq 0)
			{
				$BusinessAuthor=""
			}
			Compare-Object $permissions $BusinessAuthor | Where-Object { $_.SideIndicator -eq '<=' } | Foreach-Object { 
				if($_.InputObject -eq "READ")
				{
					$query = "INSERT INTO lib_access(item_id, group_id, permission) VALUES ('$($pmexFolderID)', '$($businessAuthorID)','R');"
					$obj = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
					$groupPermissions.Add("Read")
				}
				elseif($_.InputObject -eq "WRITE")
				{
					$query = "INSERT INTO lib_access(item_id, group_id, permission) VALUES ('$($pmexFolderID)', '$($businessAuthorID)','W');"
					$obj = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
					$groupPermissions.Add("Write")
				}
				elseif($_.InputObject -eq "EXECUTE")
				{
					$query = "INSERT INTO lib_access(item_id, group_id, permission) VALUES ('$($pmexFolderID)', '$($businessAuthorID)','X');"
					$obj = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
					$groupPermissions.Add("Execute")
				}
			}
			[string]$csv = $null
			$csv = $groupPermissions -join ","
			$logger.logInfo("$($csv) Permissions Added for Business Author Group", $True)
		}
		else {
			$logger.logInfo("Required Permissions Already Set for Business Author Group", $True)
		}
		$logger.logInfo("Checking Permissions for Everyone Group", $True)
		$search="Everyone"
		$permissions = "READ","EXECUTE"
		$Everyone = (cat $permissionPath) -cmatch $search |ForEach-Object {($_ -split ';')[-1]}
		if(($Everyone.count -lt 2) -and (-not ([string]::IsNullOrEmpty($everyoneID))))
		{
			$logger.logInfo("Setting Permissions for Everyone Group", $True)
			$groupPermissions = New-Object System.Collections.Generic.List[System.Object]
			if($Everyone.count -eq 0)
			{
				$Everyone=""
			}
			Compare-Object $permissions $Everyone | Where-Object { $_.SideIndicator -eq '<=' } | Foreach-Object { 
				if($_.InputObject -eq "READ")
				{
					$query = "INSERT INTO lib_access(item_id, group_id, permission) VALUES ('$($pmexFolderID)', '$($everyoneID)','R');"
					$obj = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
					$groupPermissions.Add("Read")
				}
				elseif($_.InputObject -eq "EXECUTE")
				{
					$query = "INSERT INTO lib_access(item_id, group_id, permission) VALUES ('$($pmexFolderID)', '$($everyoneID)','X');"
					$obj = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
					$groupPermissions.Add("Execute")
				}
				
			}
			[string]$csv = $null
			$csv = $groupPermissions -join ","
			$logger.logInfo("$($csv) Permissions Added for Everyone Group", $True)
		}
		else {
			$logger.logInfo("Required Permissions Already Set for Everyone Group", $True)
		}
		$logger.logInfo("Permissions on Folder $($PMEX_folder) in Custom Library Completed", $True)
	}
    $logger.logInfo("Library structure creation complete", $True)
    ##############################################################################
    ##                    Import Feature Package Contents                       ##
    ############################################################################## 
    $logger.loginfo("Installing Information Package", $True)
    $isInformationPacakgeImported = Import-LibraryElement -element $($UncoveredZipList[1]['InformationPackage.part0.zip']) -username $userDetails.username -password $password -destination $($featureInfo['library_path'])

    if(-not $isInformationPacakgeImported) {
        $logger.logWarning("Information Package import was unsuccessful", $True)
        return
    }
    $logger.logInfo("Information Package installation complete", $True)

    $logger.logInfo("Installing Analyses", $True)
    $isAnalysisImported = Import-LibraryElement -element $($UncoveredZipList[1]['Analysis.part0.zip']) -username $userDetails.username -password $password -destination $($featureInfo['library_path'])

    if(-not $isInformationPacakgeImported) {
        $logger.logWarning("Analysis import was unsuccessful", $True)
        return
    }
    $logger.logInfo("Analyses installation complete", $True)


    ##############################################################################
    ##                    Update Feature Version info in RepDB                  ##
    ############################################################################## 
    $logger.logInfo("Updating feature version information", $True)
    $isUpdated = Add-FeatureRecord $featureInfo $password

    if (-not $isUpdated) {
        $logger.logError($MyInvocation, "failed to store version information", $True)
    } else {
        $logger.logInfo("Feature version information update complete", $True)        
    } 
	  
    ##############################################################################
    ##                         Cleanup temp directories                         ##
    ############################################################################## 
    foreach ($dir in $tmpDirArrayList) {
        Remove-Item $dir -Force -Recurse -ErrorAction SilentlyContinue
    }

	##############################################################################
    ##                    Trust untrusted scripts and data functions            ##
    ##############################################################################
	$logger.logInfo("Updating trust status", $False)
	$params = @{}
	$params.spotfirebin = "$($TOMCAT)\spotfire-bin\"   
	$command = "find-analysis-scripts -t " + $password + " -d true -s true -q true -p `"" + $($featureInfo['library_path']) + "`" -n"
	$trustUpdate = Use-ConfigTool $command $params $TEMP_CONFIG_LOG_FILE
	if(-not $trustUpdate) {
        $logger.logWarning("Trust update was unsuccessful", $True)
        return
    }
    $logger.logInfo("Feature installation complete", $True)
	return $true
}

### Function:   Get-UserDetails ###
#
#   Gathers user details for platform changes
#
# Arguments:
#      [none]
#
# Return Values:
#       [hashtable]
# Throws: None
#
Function Get-UserDetails() {
    $envVariable = "NetAnVar"
	$password = Get-EnvVariable $envVariable
	$username = (Get-Users -all |% { if($_.Group -eq "Administrator" -and $_.USERNAME -ne "scheduledupdates") {return $_} } | Select-Object -first 1).USERNAME
	    return @{'username' = $username; 'password' = $password}
}



Function Get-Datasource() {
    param(
        [String]$password
    )   
    $query = "create temp table tbl as (
					select a.item_id as guid, a.title as title, a.parent_id as parentid, a.item_type as typeid from
					(select i.title, i.item_id, i.item_type, i.parent_id, it.label from lib_items as i
					inner join lib_item_types it
					on i.item_type = it.type_id) as a where a.label ='folder' or a.label = 'datasource'
                );
 
			with recursive cte 
					as (
                        select guid, title, typeid, cast((title) as varchar(1000)) as path
                        from tbl
                        where title ='root'
                        union all
                        select t.guid, t.title, t.typeid,
                        cast((a.path || '/' || t.title) as varchar(1000)) as path
                        from tbl as t
                        join cte as a
                        on t.parentid = a.guid
                   )
           
			select title as title, guid as item_id, path from cte where typeid=(select type_id from lib_item_types where label='datasource') and path like '%Ericsson Library%Data Sources%'"
    
    $logger.logInfo("Checking for existing Datasources", $True)
      
    $result = Invoke-UtilitiesSQL -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch  
 
    if ($result[0]) {
        $output = $result[1]
	
        if ($output.title -ne $null){
            $logger.logInfo("Existing datasources found", $True)
            $VAL = 1
            $datasourceMap = @{}
            
            $output | % {                
                $datasource = New-Object psobject
                Add-Member -in $datasource NoteProperty 'title' $($_.title)
                Add-Member -in $datasource NoteProperty 'item_id' $($_.item_id)
                Add-Member -in $datasource NoteProperty 'Path' $($_.path)        
                $dataSourceMap.Add($VAL, $datasource)
                $VAL++
            }

            return $datasourceMap
        } else {
            $logger.logWarning("No datasource exists. Please refer to the Network Analytics Server System Administration Guide " +
                "for instructions on datasource setup before proceeding with feature installation." , $True)  
            return $False
        }
    }
}

Function Confirm-DatasourceSelection(){
    param(
        [hashtable] $datasourceMap
        )

    $selectedGuid=$null
    $confirmation = ""
    $options = @("y","n","x", "X", "Y", "N")
    
    while($confirmation -ne "y") {
        $confirmation = ""
        Write-host "`nThe following datasource(s) are available:`n" -ForegroundColor Green
        $datasourceMap.Keys | Sort | % {
            $title = ($datasourceMap.Item($_).title)
            $title = ($title).PadRight(15)
            $path = ($datasourceMap.Item($_).Path)
            $path = $path -Replace ".*root", ""

            Write-host  "[$($_)]:", "$($title)", "$($path)" -ForegroundColor Green   
        }

        Write-Host "`n"

        Write-Host "`nPlease enter the required datasource number to map to feature and press <enter>:  " -ForegroundColor Green -NoNewline
        $dsSelected = Read-Host 
        $isValid=$True
       
        try {
           $dsSelected =[Int32]$dsSelected
        } catch {
            $isValid = $False
        }

        if( -Not $isValid -or (-Not $datasourceMap.containsKey($dsSelected)) ) {
            Write-host "Number entered is not valid" -ForegroundColor Yellow
        } else {
            $selectedGuid = $dataSourceMap.Item($dsSelected).item_id 
            Write-Host "`nThe datasource selected is: $($dataSourceMap.Item($dsSelected).title)" -ForegroundColor Green
            Write-Host "`n`nPlease confirm the selected datasource to proceed with feature installation`n" -ForegroundColor Green -NoNewLine
            Write-Host "`Please note that confirming the datasource will start the installation." -ForegroundColor Yellow 
            Write-Host "The installation will overwrite previously installed versions of this feature." -ForegroundColor Yellow
            
            while( -not ($options.Contains($confirmation))) {
                Write-Host "`n`nPlease enter one of the following options and press <enter>:" -ForegroundColor Green 
                Write-Host "`nY - confirm datasource and proceed with installation" -ForegroundColor Green 
                Write-Host "N - select an alternative datasource" -ForegroundColor Green
                Write-Host "X - exit the installation process`n" -ForegroundColor Green
                $confirmation = Read-host 
            }

            if($confirmation -eq "x") {
                throw "user exiting installation process"
            }        
        }
    }
    
    return $selectedGuid
}


### Function:   Read-FeaturePackage ###
#
#   Extracts and validates the contents of the feature package
#
# Arguments:
#      [string] $featurePackage - the zipped feature package file
#      
# Return Values:
#       [list] 
#       [0] [boolean] successful 
#       [1] [hashtable] / [string] result or errormessage
# Throws: None
#
Function Read-FeaturePackage() {
    param(
        [string] $featurePackage
    )

    # Test Error Conditions
    $fileExists = Test-FileExists $featurePackage

    if( -not $fileExists) {
        if($featurePackage) {
            return @($False, "The feature package provided does not exist. $($featurePackage)")
        }

        return @($False, "A feature package must be provided.")
    }

    $featurePackageInfo = Get-Item $featurePackage

    $ext = ( $featurePackageInfo | Select Extension)
    $isZipFile = ($ext.Extension -eq ".zip")

    if( -not $isZipFile) {
        return @($False, "The feature package provided is invalid. It must be a zipped file.`n$featurePackage")
    }

    # Create a temporary extraction directory
    $featureExtractDir = Get-Directory "feature-extract"

    if( -not $featureExtractDir[0]) {
        return @($False, "$($featureExtractDir[1])")
    }
    

    $appShell = New-Object -com shell.application 
    $zipFile = $appShell.Namespace("$($featurePackageInfo.Fullname)")
    $featurePackageFiles = @{}

    
    # extract feature package
    $temp = $zipFile.Items() | where { (split-path $_.Path -leaf) -clike "*xml" }

    if($temp) {
        $script:featureReleaseFilename = ($temp | split-path -leaf) 
    } 

    $REQUIRED_CONTENTS = $script:analysisExe, $script:infoPackageExe, $script:featureReleaseFilename

    $zipFile.Items() | % {
        $filename = Split-path -path $($_.PATH) -leaf
        if(-not ($REQUIRED_CONTENTS.Contains("$filename" ))) {
            return @($False, "$_.Name is not a supported feature package file")
        }
        

        $appShell.Namespace($($featureExtractDir[1])).CopyHere($_)
        $featurePackageFiles.Add($filename, "$($featureExtractDir[1])\$($filename)")
    } 

    # return false if any file is missing
    if($featurePackageFiles.Count -lt 3) {
        $message = "The feature package provided is invalid. The following file(s) are missing:"

        [array] $extractedFiles = $featurePackageFiles.Keys
        $missingFiles = Compare-Object  $extractedFiles $REQUIRED_CONTENTS
        $missingFiles | % { $message += "`n$($_.InputObject)"}
        return @($False, $message)
    }

    return @($True, $featurePackageFiles)
}


### Function:   Read-FeatureReleaseXml ###
#
#   Reads the feature-relase.xml file and builds a hashtable of all required 
#   parameters for the installation of the feature
#
# Arguments:
#      [string] $featureReleaseXmlFile - the feature-release.xml file
#      
# Return Values:
#       [list] 
#       [0] [boolean] successful 
#       [1] [hashtable] / [string] result or errormessage
# Throws: None
#
Function Read-FeatureReleaseXml() {
    param(
        [string] $featureReleaseXmlFile
    )

    if ( -not (Test-FileExists $featureReleaseXmlFile)) {
        return @($False, "$($featureReleaseXmlFile) could not be found")
    }
	
	#Update XML file
	(Get-Content $featureReleaseXmlFile) | Foreach-Object {
    $_ -replace 'product-id', 'product_id' `
       -replace 'feature-name', 'feature_name' `
       -replace 'system-area', 'system_area' `
       -replace 'datasource-guid', 'datasource_guid' `
       -replace 'ericsson-library', 'ericsson_library' 
    } | Set-Content $featureReleaseXmlFile
	
    #Read XML File
    [xml]$xmlObj = Get-Content $featureReleaseXmlFile
    $hashXml = @{}
    $xmlObj.SelectNodes("//text()") | foreach { $hashXml[$_.ParentNode.ToString()] = $_.Value }
    

    #Get RState
    $rstate = $featureReleaseXmlFile.Split(".")[-2]

    if( -not ($rstate -match "^r")) {
        return @($False, "$rstate is not a valid r-state")
    }

    $guid = $hashXml.'datasource_guid'
    $guidLength = $guid.Length
    
    if($guidLength -lt 36) {
        return @($False, "the provided GUID in the feature-release.xml file is invalid.")
    }
    
    $hashXml.RSTATE = $rstate -replace '^([A-Z]{1}?\d+?[A-Z])\d.*', '$1'

    #Get BUILD Number
    $hashXml.BUILD = $rstate

    #Remove spaces or characters from Product Number
    $hashXml.'product_id' = $hashXml.'product_id' -replace '[-, ,/,_,\\]', ''
    $hashXml.'product_id' = ($hashXml.'product_id').ToUpper()
    #Create the Installation Library Path
    $libPath = "/"

    if ($hashXml.'ericsson_library') {
        if ($hashXml.'ericsson_library' -eq "TRUE") {
            $libPath +=  "$($ericsson_library)"
        } else {
            $libPath += "$($custom_library)" 
        }    
    } else {
        $libPath += "$($custom_library)" 
    }

    $libPath += "/$($hashXml.'system_area')/$($hashXml.'feature_name')"
   
    $hashXml.'library_path' = $libPath


    #Verify all required keys are present and non null
    $isValid = Test-MapForKeys $hashXml $XML_SCHEMA

    if($isValid[0]) {
        return @($True, $hashXml)
    } else {
        return @($False, $isValid[1])
    }    
}


### Function:   Unprotect-FeaturePackageContents ###
#
#   Extracts the licenced executables
#
# Arguments:
#      [hashtable] $featurePackageFiles - a hashtable with the key valued of 
#               the executable names. i.e. Analysis.part0.exe and InformationPackage.part0.exe
#      
# Return Values:
#       [list] 
#       [0] [boolean] successful 
#       [1] [hashtable] / [string] result or errormessage where result it the path to the extraced 
#               zip files. The keys to which are Analysis.part0.zip and InformationPackage.part0.zip
# Throws: None
#
Function Unprotect-FeaturePackageContents() {
    param(
        [hashtable] $featurePackageFiles
    )

    Function Extract-Exe() {
        param(
            [string] $exeFile,
            [string] $extractDir
        )

        $timeout = 40000 #40 seconds
        $extractionProcess = Start-Process $exeFile -ArgumentList "/T:$($extractDir) /q:a" -PassThru

        if (-not $extractionProcess.WaitForExit($timeout)) {
            if ( -not $extractionProcess.HasExited) {
                $extractionProcess.Kill()
                return $false
            }
        }

        if ( -not $extractionProcess.ExitCode -eq 0) {
            return $False
        } 

        return $True
    }

    $analysisExe = $featurePackageFiles.Item($script:analysisExe)
    $infoPackageExe = $featurePackageFiles.Item($script:infoPackageExe)
    $featurePackageItems = @($analysisExe, $infoPackageExe)  

    $extractedHashTable = @{}
    $extractionResult = @($true, $extractedHashTable)

    ForEach ($executable in $featurePackageItems) { 
        $exeName = "$((Get-Item $executable).Name)"
        $extractLocation = (Get-Item $executable).Directory.Fullname
        $isExtracted = Extract-Exe $executable $extractLocation
        
        if( -not $isExtracted) {
            $errorMessage = "There was a problem in extracting the licenced media: $exeName.`nPlease check your Sentinel licence server is running and that the correct licence is installed for this feature."
            $extractionResult = @($False, $errorMessage)
            break
        }

        $zipFilePath = $executable -replace ".exe", ".zip"
        $zipFilename = $exeName -replace ".exe", ".zip"
        $extractedHashTable.Add($zipFilename, $zipFilePath)
    }

    return $extractionResult
}

### Function:   Test-LicenceManagerIP ###
#
#   Tests if the $env:LSFORCEHOST variable is set
#
# Arguments:
#      none
# Return Values:
#       [list] 
#       [0] [boolean] successful 
#       [1] [string] ipaddress or failure message
#
# Throws: None
#
Function Test-LicenceManagerIP() {

    $lsForceHost = $env:LSFORCEHOST
    
	if ($lsForceHost -eq $null) {
        return @($False, "Please set the LSFORCEHOST environment variable to the IP address of host where Sentinel licence manager is running")
    }

    return @($True, $lsForceHost)
}



### Function:   Build-LibraryPackage ###
#
#   Creates a Network Analytics Server Folder element ready for import by config utility.
#   The library once imported will be named as the $foldername parameter
#
# Arguments:
#      [string] $foldername - The name of the new folder element
#      
# Return Values:
#       [list] 
#       [0] [boolean] successful 
#       [1] [string] package name - the zipped file name e.g. file.part0.zip
#       [2] [string] absolute path to package
#
# Throws: None
#
Function Invoke-LibraryPackageCreation() {
    param (
        [string] $foldername
    )

    $metaDataFile = Get-FolderMetaDataFile
    $buildDir = Get-Directory -dirname "build"
    $stageDir = Get-Directory -dirname "stage"

    if( -not $buildDir[0] -or -not $stageDir[0]) {
        return @($False, "Error creating Directories:`n$($buildDir[1])`n$($stageDir[1])")
    }

    if( -not $metaDataFile[0]) {
        return @($False, "$($metaDataFile[1])")
    }

    $tempBuildDir = $buildDir[1]
    $tempStageDir = $stageDir[1]

    [xml]$metaXml = gc $metaDataFile[1]
    $libraryElementXMLSchema = $metaXml.'library-item'
    $folderXmlSchema = $metaXml.'library-item'.children.'library-item'

    $libraryElementXMLSchema.created = "2016-10-13T17:00:00.000+00:00"
    $libraryElementXMLSchema.modified = "2016-10-13T17:00:00.000+00:00"

    $folderXmlSchema.title = "$($foldername)"
    $folderXmlSchema.'created-by' = "Installer"
    $folderXmlSchema.'modified-by' = "Installer"
    $folderXmlSchema.created = "2016-10-13T17:00:00.000Z"
    $folderXmlSchema.modified = "2016-10-13T17:00:00.000Z"
    $folderXmlSchema.accessed = "2016-10-13T17:00:00.000Z"

    $outFile = "$($tempBuildDir)\meta-data.xml"

    try {
        $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
        $sw = New-Object System.IO.StreamWriter($outFile, $false, $utf8WithoutBom)
        $metaXMl.Save($sw)
    } catch {
        return @($False, "Error Saving meta-data.xml file")        
    } finally {
        $sw.Close()
    }

    echo $null >> "$($tempBuildDir)\lastfileindicator"
    echo $null >> "$($tempBuildDir)\expectlastfileindicator"

    #zip all files
    $foldername = $foldername -replace " ",""
    $zipFileName = "$($folderName).part0.zip"
    $absolutePath = "$($tempStageDir)\$($zipFileName)"

    Add-Type -assembly "system.io.compression.filesystem"
    [io.compression.zipfile]::CreateFromDirectory($tempBuildDir, $absolutePath)
    
    return @($True, $zipFileName, $absolutePath)
}

### Function:   Get-FolderMetaDataFile ###
#
#   Returns a template meta-data.xml of a library folder element
#
# Arguments:
#      [none]
#      
# Return Values:
#       [list] [0] boolean [1] [string] 
# Throws: None
#
Function Get-FolderMetaDataFile() {
    
    $metaDataFile = "$($DEFAULT_FOLDER_DIR)\meta-data.xml"
    
    if (Test-FileExists $metaDataFile) {
        return @($True, $metaDataFile)
    } else {
        return @($False, "The required meta-data.xml was not found at $($metaDataFile)")
    }
}


### Function:   Get-Directory ###
#
#   Creates a new instance of the named directory. Deletes recursively the directory if it 
#   already exists. The named directory will be created in the following path:
#       C:\Ericsson\NetAnServer\feature_installation\resources
#
# Arguments:
#      [string] $dirname - The name of the directory to create
#      
# Return Values:
#       [list] [0] boolean [1] [string] 
# Throws: None
#
Function Get-Directory() {
    param(
        [string] $dirname
    )

    $dir = "$($TEMP_DIR_PATH)\$($dirname)"
    $TmpDirArrayList.Add($dir) | Out-Null

    if(Test-Path $dir){
        Remove-Item $dir -Force -Recurse
    }
    
    try {
        New-Item $dir -type directory -ErrorAction Stop | Out-Null
        return @($True, $dir)
    } catch {
        return @($False, "Error creating $dir")
    }
}


### Function:   Import-LibraryElement ###
#
#   Prompts the user for a Network Analytics Server Administrator Username
#   and the Network Analytics Server Platform Password.
#
# Arguments:
#      [string] $element - The element to import (e.g. information package, Analysis Package)
#      [string] $username - The Network Analytics Server Admin username
#      [string] $password - The Network Analytics Server Platform password
#      [string] $destination (optional) - The location to import the element to
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Import-LibraryElement() {
    param(
        [Parameter(Mandatory=$true)]
        [string] $element,
        [Parameter(Mandatory=$true)]
        [string] $username,
        [Parameter(Mandatory=$true)]
        [string] $password,
        [string] $destination = $null,
        [switch] $FOLDER
    )
    
    #required parameters for Get-Arguments and Use-ConfigTool
    $params = @{}
    $params.libraryLocation = $element   #absolute path of zip to install
    $params.administrator = $username    #Network Analytics Server Administrator
    $params.configToolPassword = $password   #Network Analytics Server Platform Password
    $params.spotfirebin = "$($TOMCAT)\spotfire-bin\"   #Tomcat bin directory
	
	

    #NetAnServerConfig.Get-Arguments
    if ($FOLDER) {
        $configToolParams = "import-library-content -t $($password) -p $($element) -m KEEP_BOTH -u $($username)"
    } else {
        $configToolParams = "import-library-content -t $($password) -p $($element) -m KEEP_NEW -u $($username)"
    }
    if ($destination) {
        $configToolParams = "$($configToolParams) -l `"$($destination)`""  
    }
    
    #NetAnServerConfig.Use-ConfigTool
    $isImported = Use-ConfigTool $configToolParams $params $TEMP_CONFIG_LOG_FILE
    return $isImported
}

### Function:  Test-ChildExists ###
#
#    Tests if the folder Child-Parent already exists
#    This function will return false if Child of the Parent doesn't exists else true. 
#
# Arguments:
#       [string] $child
#       [string] $parentGUID
#        [string] $password
# Return Values:
#       [boolean]
# Throws: None
#
Function Test-ChildExists() {
    param(
        [string] $child,
        [string] $parentGUID,
        [string] $password
    )
 
    $query= "select count(*) as count  from lib_items where title='$child' and parent_id ='$parentGUID'"
	
	
    $result= Invoke-UtilitiesSQL  -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
	
    $logger.logInfo("Response for Query is: $($result[1].count)")
    
    if ($result[0]) {
        if ($result[1].count -eq 1 ) {
            $logger.logInfo("$child Folder exists with parent folder $parent", $false)
            return $TRUE;
        }
        else {
        $logger.logInfo("$child Folder for parent folder $parent does not exist", $false) 
        return $FALSE; 
        }
    }
    else {
        $logger.logInfo("Failed to execute Query $query with response $($result[1])")
        return $False
    }
}
### Function:  Get-ChildGUID ###
#
#        This function will return Child GUID for passed parent-child. 
#
# Arguments:
#       [string] $child
#       [string] $parent
#        [string] $password
# Return Values:
#       [array]
# Throws: None
#
Function Get-ChildGUID() {
    param(
        [string] $child,
        [string] $parentGUID,
        [string] $password
    )
        
    $query= "select item_id from lib_items where title='$child' and parent_id ='$parentGUID'"
    $response = Invoke-UtilitiesSQL  -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
    
    if ($response[0]) {
        $childGUID=$($response[1].item_id)
        $logger.logInfo("GUID for folder $child with parent folder $parent is $childGUID", $False)
        return @($True, $childGUID)
    }
    else {
        $logger.logInfo("Unable to get GUID for $child folder with parent folder $parent with Query Response $response",$False)
        return @($False, $response[1])
    }
}

### Function: Get-PermRootGUID ###
#
#   This function returns GUID of ROOT folder. 
#
# Arguments:
#  
#        [string] $password
# Return Values:
#        [array]
#
Function Get-PermRootGUID(){
    param(
        [string] $password
    )
    $query = "select item_id from lib_items where parent_id is NULL and title='root'" 
    $response = Invoke-UtilitiesSQL  -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
	
	
    if ($response[0]) {
       $permGUID=$($response[1].item_id)
       return @($True, $permGUID)
    }
     else {
        $logger.logError($MyInvocation,"Unable to get GUID for root folder with Query Response $($response[1])",$False)
        return @($False, $response[1])
    }
}

### Function: Get-FolderITEMType ###
#
#   This function returns GUID of folder ITEM Type. 
#
# Arguments:
#  
# Return Values:
#        [String]
#
Function Get-FolderITEMType() {
    param(
        [string] $password
    )
    $query = "select type_id from lib_item_types where label='folder'" 
    $response = Invoke-UtilitiesSQL  -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action fetch
    
    if ($response[0]) {
       $folderTypeID=$($response[1].type_id)
       return @($True, $folderTypeID)
    }
    else {
        $logger.logError($MyInvocation,"Unable to get GUID for folder type with Query Response $($response[1])",$False)
        return @($False, $response[1])
    }
}

 
### Function: Set-Parent ###
#
#   This function sets parent GUID of Child folder created at root level. 
#
# Arguments:
#  [string] childGUID
#  [string] parentGUID
# Return Values:
#        [boolean]
#
Function Set-Parent(){
    param (
        [string] $childGUID,
        [string] $parentGUID,
        [string] $password
     )
    $query = "update lib_current_items set parent_id='$parentGUID' where item_id='$childGUID'" 
    $response = Invoke-UtilitiesSQL  -Database $DB -Username $USER -Password $password -ServerInstance $SERVER -Query $query -Action insert
    
    if ($response[0]) {
        $logger.logInfo("parent_id set for $childGUID",$FALSE)
        return $True
    }
    else {
        $logger.logError($MyInvocation,"Failed to set parent_id",$FALSE)
        return $False
    }
}

Function Add-LibraryStructure(){
    param (
        [String] $LIB_FOLDER,
        [hashtable] $userDetails
    )
    $parent="root"
    $root="root"
    $username=$userDetails.username
    $password=(New-Object System.Management.Automation.PSCredential 'N/A', $userDetails['password']).GetNetworkCredential().Password
    $LIB_ITEMS=$LIB_FOLDER.split('/',[StringSplitOptions]::RemoveEmptyEntries)
    $parentGUID=''

    $parentGUIDResults = Get-PermRootGUID $password
	    if ($parentGUIDResults[0]) {
        $parentGUID=$parentGUIDResults[1]
    } else {
        return @($False,"Unable to get root GUID with error $parentGUIDResults[1]")
    }	  
    foreach($child in $LIB_ITEMS) {
	
        $childExists = Test-ChildExists $child $parentGUID $password
		

        if($childExists) {
            $result= Get-ChildGUID  $child $parentGUID $password

            if($result[0]) {
                $parentGUID=$result[1]
            } else {
                return @($False,"Unable to get ChildGUID with error $result[1]")
            }
         } else {
            $folderpath = Invoke-LibraryPackageCreation $child
			 
                     
            if($folderpath[0]) {
                $childcreated = Import-LibraryElement -element $folderpath[2] -username $username -password $password -FOLDER
                
                if($childcreated[0]) {
                    $result = Get-ChildGUID $child $parentGUIDResults[1] $password
                    
                    if($result[0]) {
                        $setparent = Set-Parent $result[1] $parentGUID $password
                        if($setparent) {
                            $parentGUID=$result[1]
                        } else {
                            return @($False,"Failed to Set  parent")
                        }
                    } else {
                        return @($False,"Failed to get ChildGUID with error $($result[1])")
                    }
                } else {
                    return @($False,"Failed to Import Package for Folder $child with error $($childcreated[1])")
                }
            } else {
                return @($False,"Failed to Create Folder Package for $child with error $($folderpath[1])")
            }
          }

          $parent=$child
    }
    return $TRUE
} 

   
### Function: Test-ShouldFeatureBeInstalled ###
#
#   Tests if a feature is previously installed.
#   This function uses the rstate and the product number as criteria to test if a feature is installed.
#   If rstate parameter is greater than existing rstate, returns $True, else $False.
#      
# Arguments:
#   [string] $productNumber,
#   [string] $rstate,
#   [string] $password
#
# Return Values:
#   [list]
#
Function Test-ShouldFeatureBeInstalled() {
    param(
        [string] $productNumber,
        [string] $build,
        [string] $password
    )

    $product_number = $productNumber -replace '[-, ,/,_,\\]', ''
    $product_number = $product_number.ToUpper()

    $result = Test-IsFeatureInstalled -productNumber $product_number -password $password
    
    if ($result[0]) {
        $existingBuild = $result[1].build
		
        $isGreaterThan = Test-BuildIsGreaterThan $build $existingBuild 

        if ($isGreaterThan) {
            return @($True, $result[1].build)
        }
    }
    return @($False, $result[1].build)
}    

