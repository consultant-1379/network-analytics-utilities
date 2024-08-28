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
# Name    : ManageUsersUtility.psm1
# Date    : 13/08/2020
# Purpose : Utility for Management of Network Analytics Server users

Import-Module -DisableNameChecking NetAnServerUtility -Force
Import-Module -DisableNameChecking NetAnServerConfig -Force
Import-Module Logger

$drive = (Get-ChildItem Env:SystemDrive).value

# check if manager users is being used from media or after when the install/upgrade is finished
$media_resources_path = "C:\Ericsson\tmp\Resources\version\"

if( (Test-Path($media_resources_path))){
       $version_strings_xml = "$($media_resources_path)\supported_NetAnPlatform_versions.xml"    
    }
else{
    $restoreResourcesPath = "C:\Ericsson\NetAnServer\RestoreDataResources\"
    $version_strings_xml = "$($restoreResourcesPath)\version\supported_NetAnPlatform_versions.xml"   
}
[xml]$xmlObj = Get-Content $version_strings_xml 

$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")

foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'y') {
            $version = $platformVersionString.'version'
        }
}


$NETANSERV_HOME = "$($drive)\Ericsson\NetAnServer"
$global:map = @{}
$global:map.Add('spotfirebin', $NETANSERV_HOME+"\Server\$($version)\tomcat\spotfire-bin\")
$GROUP_LIST = @('Consumer', 'Business Author', 'Business Analyst')
$SERVER_INSTANCE = "localhost"
$DB_USER = "netanserver"
$SQL_SERVICE = "postgresql-x64-" +(((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).MajorVersion) | measure -Maximum).Maximum
$DATABASE = "netanserver_db"
$SQL_TIMEOUT = 60
$ADHOC_LOG_DIR = "$($NETANSERV_HOME)\Logs\AdhocEnabler"
$global:configToolAdhocLogfile = "$ADHOC_LOG_DIR\$(get-date -Format 'yyyyMMdd_HHmmss')_configTool.log"
$DEFAULT_FOLDER_DIR = "$($NETANSERV_HOME)\Features\Ad-HocEnabler\resources\folder"
$TEMP_DIR_PATH = "$($NETANSERV_HOME)\Features\Ad-HocEnabler\resources"
$global:logger = Get-Logger("ManagerUsersUtilities")
$logDir = "$($drive)\Ericsson\NetAnServer\Logs\ManageUserUtilities"

if( -not (Test-Path $logDir)) {
    New-Item -Type Directory $logDir
}

$logger.setLogDirectory($logDir)
$logger.timestamp = 'Manage'
$logger.setLogname('UserUtilities.log')


$TOMCAT = "$($NETANSERV_HOME)\Server\$($version)\tomcat"

$businessAuthorLicenseList= @(
 '"Spotfire.Dxp.WebAnalyzer"',
 '"Spotfire.Dxp.Metrics"',
 '"Spotfire.Dxp.EnterprisePlayer" -f "openFile,saveDXPFile,saveToLibrary"'
 )
 $businessAnalystLicenseList=@(
 '"Spotfire.Dxp.Extensions"',
 '"Spotfire.Dxp.Professional"',
 '"Spotfire.Dxp.InformationModeler"',
 '"Spotfire.Dxp.EnterprisePlayer" -f "undoRedo"'
 '"Spotfire.Dxp.Administrator" -f "libraryAdministration"'
 )

$global:configToolnewLogfile = "$ADHOC_LOG_DIR\$(get-date -Format 'yyyyMMdd_HHmmss')_configTool.log"

### Function: hide-password ###
#
#    Write text to screen and hides the password.
#
# Arguments:
#       [string] $text - the text to hide from screen
#
# Return Values:
#       [string]
# Throws:
#       [none]
#
Function hide-password($text) {

      Write-Host $text -ForegroundColor White -NoNewline
      $EncryptedPass=Read-Host -AsSecureString
      $unencryptedpassword = (New-Object System.Management.Automation.PSCredential 'N/A', $EncryptedPass).GetNetworkCredential().Password
      return $unencryptedpassword
  }


### Function: confirm-password ###
#
#    Checks if password entered by user matches.
#
# Arguments:
#       [string] $FirstPass - password entered by user
#       [string] $SecondPass - re-entered password
# Return Values:
#       [string]
# Throws:
#       [none]
#
Function confirm-password([string]$FirstPass,[string]$SecondPass) {

    if (($FirstPass -ceq $SecondPass)) {
        return 'y'
    } else {
        Write-host "`nPassword doesn't match.`n"
        return 'n'
    }
}


### Function: customRead-host ###
#
#    Write text to screen and Read-Host.
#
# Arguments:
#       [string] $text - the text to write to screen
#
# Return Values:
#       None
# Throws:
#       [none]
#
Function customRead-host($text) {
    Write-Host $text -ForegroundColor White -NoNewline
    Read-Host
}


### Function: Fetch-Password ###
#
#    Check password syntax as listed in the Network Analytics Server Installation Instructions.
#
# Arguments:
#       [string] $password - the password to validate
#
# Return Values:
#       [string]
# Throws:
#       [none]
#
Function Fetch-Password($userInput) {

    $password = hide-password $userInput
    while (!(Test-Password($password))) {
        $password = hide-password "The supplied password does not meet the minimum complexity requirements. Please refer to the Network Analytics Server Installation Instructions for information on password policy and`nRe-enter the $userInput"
    }
    return $password
}

Function Fetch-passUser($userInput) {

    $Input = "Enter the " + $userInput
    $password = hide-password $Input
    while (!(Test-Password($password))) {
        $password = hide-password "The supplied password does not meet the minimum complexity requirements. Please refer to the Network Analytics Server Installation Instructions for information on password policy and`nRe-enter the $userInput"
    }
    return $password
}


### Function: Get-Users ###
#
#    Lists all the users on the Network Analytics Server Platform
#    That are members of the Consumer, Business Author or Business Analyst groups.
#    If the -all switch is used it will return all users on the platform.
#
# Arguments:
#       [string] $platformPassword - the Network Analytics Server platform password
#       [switch] $all - optionally returns all users of the Network Analytics Server Platform
# Return Values:
#       None
# Throws:
#       [none]
#
Function Get-Users() {
    <#
        .SYNOPSIS
        Get-Users lists all created users on the Network Analytics Server platform
        and their corresponding group.
        .DESCRIPTION
        The function returns all members of the 'Consumer' user group.
        If the Network Analytics Server Adhoc Enabler package is installed it will also list users of the
        'Business Author' and 'Business Analyst' groups.

        If the -all switch is used, all users installed on the Network Analytics Server
        Platform will be returned.
        .EXAMPLE
        Get-Users

        USERNAME             GROUPNAME
        ------------------------------
        userone              Consumer

        .EXAMPLE
        Get-Users -all

        USERNAME             GROUPNAME
        ------------------------------
        userone              Consumer
        .PARAMETER all
        A switch to optionally return all users from all groups on the Network Analytics Server Platform
    #>

    param(
        [parameter(mandatory=$false)]
        [switch] $all
    )

    $platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable "NetAnVar")).GetNetworkCredential().Password
    $isAdmin = Test-ShellIsAdmin

    if(-not $isAdmin) {
        Write-Warning "You must be an Administrator to execute this command. Open PowerShell console as Administrator"
        break
    }

    try {
        if ($all) {
            return (Invoke-ListUsers -pp $platformPassword -all)[1]
        } else {
            return (Invoke-ListUsers -pp $platformPassword)[1]
        }

    } catch {
        return "$($_.Exception.Message)"
    }
}


### Function: Invoke-ListUsers ###
#
#    Lists all the users on the Network Analytics Server Platform
#    That are members of the Consumer, Business Author or Business Analyst groups
#
# Arguments:
#       [string] $platformPassword - the Network Analytics Server platform password
# Return Values:
#       None
# Throws:
#       Exception
#
Function Invoke-ListUsers() {
    param(
        [alias("pp")]
        [string] $platformPassword,
        [switch] $all
    )


    if ($all) {
        $sqlQuery = "SELECT u.USER_NAME as `"USERNAME`", g.GROUP_NAME as `"GROUP`" FROM USERS u INNER JOIN GROUP_MEMBERS gm ON gm.MEMBER_USER_ID = u.USER_ID INNER JOIN GROUPS g ON gm.GROUP_ID = g.GROUP_ID where u.PASSWORD is not null"
	} else {
        $sqlQuery = "SELECT u.USER_NAME as `"USERNAME`", g.GROUP_NAME as `"GROUP`" FROM USERS u INNER JOIN GROUP_MEMBERS gm ON gm.MEMBER_USER_ID = u.USER_ID INNER JOIN GROUPS g ON gm.GROUP_ID = g.GROUP_ID where u.PASSWORD is not null and g.GROUP_NAME = `'Consumer`'"
	}
	$result = Invoke-UtilitiesSQL -Database $DATABASE -Username $DB_USER -Password $platformPassword -ServerInstance $SERVER_INSTANCE -Query $sqlQuery -Action fetch
	$result
}


### Function:  Add-ConsumerUser ###
#
#   Creates a new user and adds them to the Consumer group
#
# Arguments:
#       [string] $username - the user to create
#
# Return Values:
#       [none]
# Throws:
#       None
#
function Add-ConsumerUser() {
    <#
        .SYNOPSIS
        Creates a Consumer user.
        .DESCRIPTION
        Creates a new user and adds them to the 'Consumer' user group.
        Note: if the user already exists, Promote-UserToGroup cmdlet should be used.
        Please see: Get-Help Promote-UserToGroup
        .EXAMPLE
        Add-ConsumerUser -username <username>
        .EXAMPLE
        Add-ConsumerUser -u <username>
        .EXAMPLE
        Add-ConsumerUser  <username>
        .PARAMETER userName
        The username for the new Consumer user user
    #>
    param(
        [parameter(mandatory=$true, HelpMessage="Enter the Consumer user username")]
        [alias("u")]
        [string] $userName
    )

    $GROUP_NAME = "Consumer"
    Import-Module -DisableNameChecking ManageUsersUtility -Force
    $platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable "NetAnVar")).GetNetworkCredential().Password

     while ($PassMatchedConsumer -ne 'y') {
            $ConsumerPassword = Fetch-passUser("Consumer user Password:`n")
            $reConsumerPassword = hide-password("Confirm the Consumer user Password:`n")
            $PassMatchedConsumer = confirm-password $ConsumerPassword $reConsumerPassword
        }$PassMatchedConsumer = 'n'

    try {
        $exists = Test-RequiredGroupExist -groupName $GROUP_NAME -platformPassword $platformPassword
    } catch {
        return "$($_.Exception.Message)"
    }

    if (-not $exists) {
        Write-Host "the required group '$($GROUP_NAME)' does not exist in Network Analytics Server."
        return
    }

    $isAdded = Add-User -username $userName -password $ConsumerPassword -groupname $GROUP_NAME -platformPassword $platformPassword

    $response = ""
    if ($isAdded[0]) {
        $response + "The Consumer user $($username) was successfully created"
    } else {
        $response + "Error creating Consumer user $($username) `n$($isAdded[1])"
    }

    return $response
}

Function Delete-ExternalGroups() {
	
	$isAdmin = Test-ShellIsAdmin

    if(-not $isAdmin) {
        Write-Warning "You must be an Administrator to execute this command. Open PowerShell console as Administrator"
        break
    }
	
	$platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable "NetAnVar")).GetNetworkCredential().Password
	
	$sqlCount = "select count(g.GROUP_NAME) as `"Count`" from groups g where EXTERNAL_ID is not null and connected = true"
	$resultCount = Invoke-UtilitiesSQL -Database $DATABASE -Username $DB_USER -Password $platformPassword -ServerInstance $SERVER_INSTANCE -Query $sqlCount -Action fetch
	$rowCount = $resultCount[1].Count
	$attemptcount=1
	
	if($rowCount -gt 0) {
		while(($PassMatchedplat -ne 'y')-and ($attemptcount -lt 4)) {
			write-host("********************Attempt $($attemptcount) of 3********************")
				$platformPasswordSecured = read-host -AsSecureString("Network Analytics Server Platform Password:`n")
				$platformPasswordInput = (New-Object PSCredential 0, $platformPasswordSecured ).GetNetworkCredential().Password
				Write-Host("`n")
				if($platformPasswordInput -eq $platformPassword) {
					write-host("Password Verified Successfully !!")
					Write-Host("`n")
					$PassMatchedplat = 'y'
				}
				else{
					Write-Warning("Incorrect Platform Password Entered.")
					Write-Host("`n")
					$attemptcount++
				}
				if($attemptcount -gt 3) {
					Write-Warning("Maximum Incorrect Attempts Reached!!")
					write-host("Please verify Network Analytics Server Platform Password and Re-run the script.")
					Write-Host("`n")
					Break
				}
			
			}
	}
	

	if(($rowCount -gt 0) -and ($PassMatchedplat -eq 'y')) {
		write-host "$($rowCount) External Groups found that can be Deleted.. "
		write-host""
		$sqlQuery = "select ROW_NUMBER() OVER() AS num_row,g.GROUP_NAME as `"GROUP`" from groups g where EXTERNAL_ID is not null and connected = true"
		$result = Invoke-UtilitiesSQL -Database $DATABASE -Username $DB_USER -Password $platformPassword -ServerInstance $SERVER_INSTANCE -Query $sqlQuery -Action fetch
		write-host("SI.No"+"     "+"Group Name")
		write-host("--------------------------")
		
		$j=0
		while($j -lt $rowCount){
			if($rowCount -eq 1) {
				$result.num_row[$j].ToString()+"         "+$result.Group
			}
			else {
				$result.num_row[$j].ToString()+"         "+$result.Group[$j].ToString()
			}
			$j++
		}
		
		$attempt=1
		while($attempt -lt 4) {
			write-host""
			write-host("********************Attempt $($attempt) of 3********************")
		
		$input = $(Write-Host "`nPlease Enter :: ";write-host -fore Yellow ("all")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Delete All the External Groups ");write-host -fore Yellow ("Group Numbers")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Delete Specific External Groups");write-host -fore Yellow ("n")-NoNewline;write-host(" to ")-NoNewline;write-host -fore Yellow ("Skip");write-host(":")-NoNewline; Read-Host)
		if($input -eq 'all') {
			$sqlQuery = "update groups set connected = false where EXTERNAL_ID is not null"
			$result = Invoke-UtilitiesSQL -Database $DATABASE -Username $DB_USER -Password $platformPassword -ServerInstance $SERVER_INSTANCE -Query $sqlQuery -Action fetch
			if($result) {
				write-host "All External Groups Disabled Successfully"
				$sqlQuery = "DELETE from GROUPS where EXTERNAL_ID is not null and CONNECTED = false"
				$result = Invoke-UtilitiesSQL -Database $DATABASE -Username $DB_USER -Password $platformPassword -ServerInstance $SERVER_INSTANCE -Query $sqlQuery -Action fetch
				if($result) {
					write-host "All External Groups Deleted Successfully"
					break
				}
				else {
					write-host "Failed to Delete External Groups"
					break
				}
			}
			else {
				write-host "Failed to Disable External Groups"
				break
			}
		}
		elseif(($input -match "^\d+$") -or ($input -match ",[0-9]+")) {
			$userInput = @()
			$selectedGroups = New-Object System.Collections.Generic.List[System.Object]
			$counter =0
			$placeHolder =0
			if($input -match ",") {
				$userInput = $input -split ","
			}
			else {
				$userInput = $input
			}
			if(($userInput | Measure-Object -Maximum).Maximum -gt $rowCount) {
				write-host""
				write-Warning("Invalid Input Provided.")
				write-host("Please Enter Valid Inputs and Try Again.")
				write-host""
				Break
			}
			else {
				for($counter =0;$counter -lt $userInput.count;$counter++)
				{
					if($rowCount -eq 1) {
						$selectedGroups.Add($result.Group)
					}
					else {
						$placeHolder = ($userInput[$counter].toString()) -1
						$selectedGroups.Add($result.Group[$placeHolder])
					}
				}
				if($selectedGroups.count -eq 1) {
					$groupsToDelete = $selectedGroups[0]
					$sqlQuery = "update groups set connected = false where EXTERNAL_ID is not null and group_name = `'"+$selectedGroups[0]+"`'"
				}
				else {
					$groupsToDelete = '"{0}"' -f ($selectedGroups -join '","')
					$counter=0
					for($counter =0;$counter -lt $selectedGroups.count;$counter++)
					{
						if($counter -eq ($selectedGroups.count-1)) {
							$a = $a + "Group_name = `'"+$selectedGroups[$counter]+"`'"
						}
						else {
							$a = $a + "Group_name = `'"+$selectedGroups[$counter]+"`' or "
						}
					}
					
					$sqlQuery = "update groups set connected = false where EXTERNAL_ID is not null and ("+$a+")"
				}
				$result = Invoke-UtilitiesSQL -Database $DATABASE -Username $DB_USER -Password $platformPassword -ServerInstance $SERVER_INSTANCE -Query $sqlQuery -Action fetch
				if($result) {
					write-host "Selected External Groups Disabled Successfully"
					if($selectedGroups.count -eq 1) {
						$groupsToDelete = $selectedGroups[0]

						$sqlQuery = "DELETE from GROUPS where EXTERNAL_ID is not null and CONNECTED = false and group_name = `'"+$selectedGroups[0]+"`'"
					}
					else {
						$sqlQuery = "DELETE from GROUPS where EXTERNAL_ID is not null and CONNECTED = false and ("+$a+")"
					}
					$result = Invoke-UtilitiesSQL -Database $DATABASE -Username $DB_USER -Password $platformPassword -ServerInstance $SERVER_INSTANCE -Query $sqlQuery -Action fetch
					if($result) {
						write-host "Selected External Groups Deleted Successfully"
						break
					}
					else {
						write-host "Failed to Delete Selected External Groups"
						break
					}
				}
				else {
					write-host "Failed to Disable Selected External Groups"
					break
				}
			}
		
		}
		elseif($input -eq 'n') {
			write-host "Skipping to Delete External Groups"
			break
		}else {
			write-warning "Invalid Input Received."
			$attempt=$attempt+1
			if($attempt -gt 3) {
				write-host("")
				Write-Warning("Maximum Incorrect Attempts Reached!!")
				write-host("Please Re-run the script and provide valid Inputs.")
				Write-Host("`n")
				Break
			}
		}
	}
	
	}
	elseif($rowCount -le 0) {
		write-host "No External Groups found that can be Deleted.. "
		break
	}
	else {
		break
	}
}


### Function:  Add-User ###
#
#   Function adds users
#
# Arguments:
#       [string] $userName,
#       [string] $password,
#       [string] $groupName,
#       [string] $platformPassword
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Add-User() {

    param(
            [Parameter(Mandatory=$true)]  [string] $userName,
            [Parameter(Mandatory=$true)]  [string] $password,
            [Parameter(Mandatory=$true)]  [string] $groupName,
            [Parameter(Mandatory=$true)]  [string] $platformPassword
    )

    $isAdmin = Test-ShellIsAdmin

    if(-not $isAdmin) {
        Write-Warning "You must be an Administrator to execute this command. Open PowerShell console as Administrator"
        break
    }

    $params = @($userName, $password, $platformPassword)
    foreach($p in $params){
        if ($p.Contains(' ')){
            return @($False,"Parameter value cannot be an empty string")
        }
    }

    #check if user exists
    try {
        $users = Invoke-ListUsers -pp $platformPassword -all
        $userExists = $users[1] | Where-Object { $_.USERNAME -eq $userName}
    } catch {
        return @($false, "$($_.Exception.Message)")
    }


    If($userExists){
        return @($False, "The User $userName already exists")
    }

    $localmap = $global:map.Clone()
    $localmap.Add('username', $userName)
    $localmap.Add('userPassword', $password)
    $localmap.Add('platformPassword', $platformPassword)
    $localmap.Add('groupname', "$groupName")
    $localmap.Add('configToolPassword', $platformPassword)


    #create user

    $userArguments =  Get-Arguments create-genericuser  $localmap
    If($userArguments){
        $createUser = Use-ConfigTool $userArguments  $localmap
        If($createUser -ne $True){
            return @($False, "Error creating user $($localmap.userName)")
        }
    } Else {
        return @($False,"Command arguments not returned")
    }

    Add-UserToGroup $($localmap.userName) $($localmap.groupname) $($localmap.platformPassword)

}

### Function:  Add-UserToGroup ###
#
#   Function adds a user to a group.
#   The user and group must both exist.
#
# Arguments:
#       [string] $userName,
#       [string] $groupName,
#       [string] $platformPassword
#
# Return Values:
#       [boolean]
# Throws: None
#
 Function Add-UserToGroup(){
    param(
        [string] $userName,
        [string] $groupName,
        [string] $platformPassword
    )

    $groupmap = $global:map.Clone()
    $groupmap.Add('username', $userName)
    $groupmap.Add('platformPassword', $platformPassword)
    $groupmap.Add('groupname', "$groupName")
    $groupmap.Add('configToolPassword', $platformPassword)

    $groupArguments =  Get-Arguments add-member $groupmap

    If($groupArguments) {
        $addToGroup = Use-ConfigTool $groupArguments $groupmap
        If($addToGroup) {
            return $True
        } Else {
            return @($False, "Error adding user $( $groupmap.username) to $($groupmap.groupname)")
        }
    } Else {
        return @($False, "Command arguments not returned to add $($groupmap.username) to $($groupmap.groupname)")
    }
}


### Function:  Add-BusinessAuthor ###
#
#   Creates a new user and adds them to the Business Author group
#
# Arguments:
#       [string] $username - the user to create
#
# Return Values:
#       [none]
# Throws:
#       None
#
function Add-BusinessAuthor() {
    <#
        .SYNOPSIS
        Creates a Business Autor user.
        .DESCRIPTION
        Creates a new user and adds them to the 'Business Author' user group.
        Note: if the user already exists, Promote-UserToGroup cmdlet should be used.
        Please see Get-Help Promote-UserToGroup
        .EXAMPLE
        Add-BusinessAuthor -username <username>
        .EXAMPLE
        Add-BusinessAuthor -u <username>
        .EXAMPLE
        Add-BusinessAuthor  <username>
        .PARAMETER userName
        The username for the new Business Author user
    #>
    param(
        [parameter(mandatory=$true, HelpMessage="Enter the Business Author username")]
        [alias("u")]
        [string] $userName
     )


    $envVariable = "NetAnVar"
    $platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
    $GROUP_NAME = "Business Author"

    while ($PassMatchedAuthor -ne 'y') {
            $AuthorPassword = Fetch-passUser("Business Author password:`n")
            $reAuthorPassword = hide-password("Confirm the Business Author password:`n")
            $PassMatchedAuthor = confirm-password $AuthorPassword $reAuthorPassword
        }$PassMatchedAuthor = 'n'

    try {
        $exists = Test-RequiredGroupExist -groupName $GROUP_NAME -platformPassword $platformPassword
    } catch {
        return "$($_.Exception.Message)"
    }

    if (-not $exists) {
        Write-Host "the required group '$($GROUP_NAME)' does not exist in Network Analytics Server."
        return
    }

    $isAdded = Add-User -username $userName -password $Authorpassword -groupname $GROUP_NAME -platformPassword $platformPassword

    $response = ""
    if ($isAdded[0]) {
        $response += "The Business Author $($username) was successfully created "
    } else {
        $response += "Error creating Business Author $($username) `n$($isAdded[1])"
    }
    if ($isAdded[0]) {
    $isFolderCreated=Add-Folder $username $platformPassword
    if ($isFolderCreated[0]) {
        $response += "`nFolder for Business Author $($username) created in Custom Library"
        } else {
            $response += "`n$($isFolderCreated[1])"

            }
    }

    Write-Host $response
}



### Function:  Add-BusinessAnalyst ###
#
#   Creates a new user and adds them to the Business Analyst group
#
# Arguments:
#       [string] $username - the user to create
#
# Return Values:
#       [none]
# Throws:
#       None
#
function Add-BusinessAnalyst() {
    <#
        .SYNOPSIS
        Creates a Business Analyst user.
        .DESCRIPTION
        Creates a new user and adds them to the 'Business Analyst' user group.
        Note: if the user already exists, Promote-UserToGroup cmdlet should be used.
        Please see: Get-Help Promote-UserToGroup
        .EXAMPLE
        Add-BusinessAnalyst -username <username>
        .EXAMPLE
        Add-BusinessAnalyst -u <username>
        .EXAMPLE
        Add-BusinessAnalyst  <username>
        .PARAMETER userName
        The username for the new Business Analyst user
    #>
    param(
        [parameter(mandatory=$true, HelpMessage="Enter the Business Analyst username")]
        [alias("u")]
        [string] $userName
     )
 
    $envVariable = "NetAnVar"
    $platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
    $GROUP_NAME = "Business Analyst"

    while ($PassMatchedAnalyst -ne 'y') {
            $AnalystPassword = Fetch-passUser("Business Analyst password:`n")
            $reAnalystPassword = hide-password("Confirm the Business Analyst password:`n")
            $PassMatchedAnalyst = confirm-password $AnalystPassword $reAnalystPassword
        }$PassMatchedAnalyst = 'n'

    try {
        $exists = Test-RequiredGroupExist -groupName $GROUP_NAME -platformPassword $platformPassword
    } catch {
        return "$($_.Exception.Message)"
    }

    if (-not $exists) {
        Write-Host "the required group '$($GROUP_NAME)' does not exist in Network Analytics Server."
        return
    }

    $isAdded = Add-User -username $userName -password $Analystpassword -groupname $GROUP_NAME -platformPassword $platformPassword

    $response = ""
    if ($isAdded[0]) {
        $response += "The Business Analyst $($username) was successfully created"
    } else {
        $response += "Error creating Business Analyst $($username) `n$($isAdded[1])"
    }
    if ($isAdded[0]) {
    $isFolderCreated=Add-Folder $username $platformPassword
    if ($isFolderCreated[0]) {
        $response += "`nFolder for Business Analyst $($username) created in Custom Library"
        } else {
                $response += "`n$($isFolderCreated[1])"
            }
    }
    Write-Host $response
}


### Function: Invoke-PromoteUserToGroup ###
#
#    Promotes a currently existing user to the specified group
#
# Arguments:
#       [switch] $BusinessAuthor | $BusinessAnalyst
#       [string] $Username
#
# Return Values:
#       [none]
# Throws:
#       None
#
Function Invoke-PromoteUserToGroup() {
    <#
        .SYNOPSIS
        Promotes a user to another group
        .DESCRIPTION
        Promotes an existing user to either the 'Business Analyst' or 'Business Author' group.
        Once promoted a user will be present in both the original group and the newly added
        group.

        The following promotion paths are supported:

        Consumer -> Business Author
        Consumer -> Business Analyst
        Business Author -> Business Analyst

        Note:
        Business Analyst -> Business Author is not supported. The Business Analyst group contains all
        privileges provided by the Business Author group.

        .EXAMPLE
        Promote a user to the 'Business Author' Group
        Invoke-PromoteUserToGroup -BusinessAuthor -username <username>
        .EXAMPLE
        Promote a user to the 'Business Author' Group
        Invoke-PromoteUserToGroup -BusinessAuthor -u <username>
        .EXAMPLE
        Promote a user to the 'Business Analyst' Group
        Invoke-PromoteUserToGroup -BusinessAnalyst -username <username>
        .EXAMPLE
        Promote a user to the 'Business Analyst' Group
        Invoke-PromoteUserToGroup -BusinessAnalyst -u <username>
        .PARAMETER userName
        The username of the user to promote
    #>
    param(
        [parameter(mandatory=$false, HelpMessage="The 'Business Author' group ", Position=1)]
        [switch] $BusinessAuthor, 
        [parameter(mandatory=$false, HelpMessage="The 'Business Analyst' group ", Position=1)]
        [switch] $BusinessAnalyst,
        [parameter(mandatory=$true, HelpMessage="Enter the username who is being promoted ", Position=2)]
        [alias("u")]
        [string] $username
    )
    Import-Module ManageUsersUtility -Force -DisableNameChecking
    $group = ""

    if ($BusinessAuthor) {
        $group = "Business Author"
    }

    if ($BusinessAnalyst) {
        $group = "Business Analyst"
    }

    if ((-not $BusinessAnalyst) -and (-not $BusinessAuthor)) {
        Write-Host "You must supply the required switch: -BusinessAnalyst or -BusinessAuthor`nPlease see Get-Help Invoke-PromoteUserToGroup -Examples "
        return
    }

    if (($BusinessAnalyst) -and ($BusinessAuthor)) {
        Write-Host "You must supply a single required switch: -BusinessAnalyst or -BusinessAuthor`nPlease see Get-Help Invoke-PromoteUserToGroup -Examples "
        return
    }

    $envVariable = "NetAnVar"
    $platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
    $exists = Test-RequiredGroupExist -groupName $group -platformPassword $platformPassword

    if (-not $exists) {
        Write-Host "The required group '$($GROUP_NAME)' does not exist in Network Analytics Server."
        return
    }

    $user = (Invoke-ListUsers -pp $platformPassword -all)[1] | Where-Object { $_.USERNAME -eq $username }

    if ( -not $user) {
        Write-Host "User $username does not exist, please create this user before promoting attempting to promote them.`n"
        return
    }

    if ($user.GROUP.Contains($group)) {
        Write-Host "User $username is already a member of the group $group"
        return
    }

    ## If is not a promotion ##
    if (($user.GROUP -eq "Business Analyst") -and $BusinessAuthor) {
        Write-Host "User '$($username)' is already a member of the 'Business Analyst' group. The 'Business Analyst' group contains all privileges provided by the 'Business Author' group."
        return
    }
    $flag=0
    if (($user.GROUP.Contains("Consumer")) -and (-NOT(($user.GROUP.Contains("Business Author"))))) {

        $flag=1;

    }

    $isAdded = Add-UserToGroup -username $username -platformPassword $platformPassword -groupName $group

    if ($isAdded[0]) {
        Write-Host "User $username added to group $group"
    } else {
        return "$($isAdded[1])"
    }

    if(($flag -eq 1) -and ($isAdded[0])) {

        $isFolderCreated=Add-Folder $username $platformPassword
        if ($isFolderCreated[0]) {
            Write-Host "Folder for  $($username) created in Custom Library"
            } else {
                return "$($isFolderCreated[1])"
            }

    }

}


### Function:  Remove-User ###
#
#   Function removes a users from the Network Analytics Server platform
#
# Arguments:
#       [string] $Username
#
# Return Values:
#       [boolean]
# Throws: None
#
 Function Remove-User(){

    <#
        .SYNOPSIS
        Removes a Network Analytics Server User.
        .DESCRIPTION
        Removes a user from the Network Analytics Server. Once a user is removed they are
        fully deleted as a user from the application
        .EXAMPLE
        Remove-User <username>
        .EXAMPLE
        Remove-User -userName <username>
        .EXAMPLE
        Remove-User -u <username>
        .PARAMETER userName
        The username of user to be removed.
    #>
    param(
        [parameter(mandatory=$true, HelpMessage="Enter the new username to create")]
        [alias("u")]
        [string] $userName
    )

    $isAdmin = Test-ShellIsAdmin
    $platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable "NetAnVar")).GetNetworkCredential().Password

    if(-not $isAdmin) {
        Write-Warning "You must be an Administrator to execute this command. Open PowerShell console as Administrator"
        break
    }

    $params = @($userName, $platformPassword)
    foreach ($p in $params) {
        if($p.Contains(' ')) {
            return @($False,"Parameter value cannot be an empty string")
        }
    }

    #check if user exists
    try {
        $users = Invoke-ListUsers -pp $platformPassword -all
        $userExists = $users[1] | Where-Object { $_.USERNAME -eq $userName}
    } catch {
        return "$($_.Exception.Message)"
    }

    If(-not $userExists) {
        return "The User $userName does not exist"
    }

    $localmap = $global:map.Clone()
    $localmap.Add('username', $userName)
    $localmap.Add('platformPassword', $platformPassword)
    $localmap.Add('configToolPassword', $platformPassword)

    $arguments =  Get-Arguments delete-user $localmap
    If($arguments) {
        $deleteUser = Use-ConfigTool $arguments $localmap
        If( -not $deleteUser) {
            return @($False, "Error removing user $($localmap.userName)")
        }
    } Else {
        return @($False, "No Command returned for removing user $($localmap.userName)")
    }
 }


 ### Function:  Update-Password ###
 #
 #   Function updates a user password.
 #   The user must exist.
 #
 # Arguments:
 #       [string] $username
 #
 # Return Values:
 #       [boolean]
 # Throws: None
 #
  Function Update-Password(){
     <#
        .SYNOPSIS
        Updates a user password.
        .DESCRIPTION
        Updates an existing user's password.
        Please see: Get-Help Promote-UserToGroup
        .EXAMPLE
        Update-Password -username <username>
        .EXAMPLE
        Update-Password -u <username>
        .EXAMPLE
        Update-Password  <username>
        .PARAMETER username
        The username for the existing user
     #>
 	 param(
 	     [parameter(mandatory=$true, HelpMessage="Enter the username to update password for")]
 	     [alias("u")]
 	     [string] $username
     )

     $params = @($username)
     foreach($p in $params){
         if ($p.Contains(' ')){
             return @($False,"Parameter value cannot be an empty string")
         }
     }

     while ($PassMatcheduser -ne 'y') {
            $userPassword = Fetch-passUser("new user password:`n")
            $reuserPassword = hide-password("Confirm new user password:`n")
            $PassMatcheduser = confirm-password $userPassword $reuserPassword
        }$PassMatchedAnalyst = 'n'
	
     $userPassword = $userPassword.Replace('"','""')
     $platformPassword = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable "NetAnVar")).GetNetworkCredential().Password

 	 #check if user exists
     try {
         $users = Invoke-ListUsers -pp $platformPassword -all
         $userExists = $users[1] | Where-Object { $_.USERNAME -eq $username}
     } catch {
         return @($false, "$($_.Exception.Message)")
     }

 	 If(-not $userExists){
         return "The User $username does not exist"
     } Else {
         Write-Host "User '$($username)' exists. Proceeding with password update."
     }

     $passwordmap = $global:map.Clone()
     $passwordmap.Add('username', $username)
     $passwordmap.Add('platformPassword', $platformPassword)
     $passwordmap.Add('userPassword', $userPassword)
     $passwordmap.Add('configToolPassword', $platformPassword)

     $passwordArguments =  Get-Arguments set-user-password $passwordmap

     If($passwordArguments) {
         $updatePassword = Use-ConfigTool $passwordArguments $passwordmap
         If(!($updatePassword)) {
             return @($False, "Error updating the password for User $($passwordmap.username)")
         }
     } Else {
         return @($False, "Command arguments not returned to update password for User $($passwordmap.username)")
     }
 }


### Function:  Test-RequiredGroupExist ###
#
#   Function Tests if a group exists
#
# Arguments:
#       [string] $platformPassword
#
# Return Values:
#       [boolean]
# Throws: Exception
#
Function Test-RequiredGroupExist() {
    param(
        [string] $groupName,
        [string] $platformPassword
    )

    $query = "SELECT group_name AS `"GROUPNAME`" from groups WHERE group_name = `'" + $($groupName) + "`'"
    $result = Invoke-ManageUsersSqlCmd -query $query -platformPassword $platformPassword

    if( -not $result) {
        return $false
    }

    if($result[1].GROUPNAME -eq $groupName) {
        return $true
    } else {
        return $false
    }
}


### Function:  Invoke-ManageUsersSqlCmd ###
#
#   Invokes SQL cmd
#
# Arguments:
#       [string] $query
#       [string] $platformPassword
#
# Return Values:
#       [boolean]
# Throws: [None]
#
Function Invoke-ManageUsersSqlCmd() {
    param(
        [string] $query,
        [string] $platformPassword
    )

    $isSQLServiceRunning = Test-ServiceRunning "$($SQL_SERVICE)"

    if(-not $isSQLServiceRunning) {
        throw "Error. Please ensure that the PostgreSQL service is running`n$($_.Exception.Message)"
    }

    $currentLocation = Get-Location

    try {
        $result = Invoke-UtilitiesSQL -Database $DATABASE -Username $DB_USER -Password $platformPassword -ServerInstance $SERVER_INSTANCE -Query $query -Action fetch
		
        return $result
    } catch {
        $exceptionMessage = "$($_.Exception.Message)"

        if ($exceptionMessage.Contains("Login failed for user 'netanserver'")) {
            throw "The platform password supplied is incorrect"
        } else {
            throw "$($_.Exception.Message)"
        }

    } finally {
        Set-Location $currentLocation
    }
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

    $libraryElementXMLSchema.created = "2016-10-28T00:00:00.000+00:00"
    $libraryElementXMLSchema.modified = "2016-10-28T00:00:00.000+00:00"

    $libraryAcl= $metaXml.'library-item'.children.'library-item'.acl.permission.principal

    foreach ($acl in $libraryAcl) {
        if($acl.type -eq "user") {
            $acl.name ="$($foldername)@SPOTFIRE"
        }
        if($acl.type -eq "group") {
            $acl.name ="Consumer@SPOTFIRE"
        }

    }

    $folderXmlSchema.title = "$($foldername)"
    $folderXmlSchema.'created-by' = "Installer"
    $folderXmlSchema.'modified-by' = "Installer"
    $folderXmlSchema.created = "2016-10-28T00:00:00.000Z"
    $folderXmlSchema.modified = "2016-10-28T00:00:00.000Z"
    $folderXmlSchema.accessed = "2016-10-28T00:00:00.000Z"

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
#       C:\Ericsson\NetAnServer\FeatureInstaller\resources
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

### Function:   Invoke-ImportLibraryElement ###
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
Function Invoke-ImportLibraryElement() {
    param(
        [Parameter(Mandatory=$true)]
        [string] $element,
        [Parameter(Mandatory=$true)]
        [string] $username,
        [Parameter(Mandatory=$true)]
        [string] $password,
        [string] $conflict,
        [string] $destination = "/Custom Library"
    )

    #required parameters for Get-Arguments and Use-ConfigTool
    $localmap = $global:map.Clone()
    $localmap.Add('administrator', $userName) #Network Analytics Server Administrator
    $localmap.Add('libraryLocation',  $element) #absolute path of zip to install
    $localmap.Add('configToolPassword', $password) #Network Analytics Server Platform Password
    

    #NetAnServerConfig.Get-Arguments
     $configToolParams = "import-library-content -t $($localmap.configToolPassword) -p $($localmap.libraryLocation) -m $conflict -u $($localmap.administrator)"


    if(-not $configToolParams) {
        return @($False, "Error importing Library Element $element`n
            NetAnServerUtility.Get-Arguments returned $configToolParams")
    }

    if ($destination) {
        $configToolParams = "$($configToolParams) -l `"$($destination)`""
    }

    #NetAnServerConfig.Use-ConfigTool
    $isImported = Use-ConfigTool $configToolParams $localmap $configToolAdhocLogfile
    return $isImported
}

### Function:   Get-AdminUserName ###
#
#  Used to get Admin username
#
# Arguments:
#      [string] $password - Platform Password
#
# Return Values:
#       Username for admin
# Throws: None
#
Function Get-AdminUserName() {
    param(
        [Parameter(Mandatory=$true)]
        [string] $password
        )
    $adminName=Get-Users -all | % { if($_.Group -eq "Administrator") {return $_} } |Select-Object -first 1
    return $adminName.USERNAME
}

### Function:   Add-Folder ###
#
#   Prompts the user for a Network Analytics Server Administrator Username
#   and the Network Analytics Server Platform Password.
#
# Arguments:
#      [string] $foldername - Ad-hoc Username for which folder needs to be created in Custom Library
#      [string] $password - The Network Analytics Server Platform password
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Add-Folder() {
    param(
        [string] $folderName,
        [string] $password
        )

    $username=Get-AdminUserName $password
    $folderPath=Invoke-LibraryPackageCreation $folderName
    if($folderPath[0]) {
        $childcreated=Invoke-ImportLibraryElement -element $folderPath[2] -username $username -password $password -conflict "KEEP_BOTH"
        if($childcreated[0]) {
            return @($True,"Successfully created folder")
        }
    } else {
        return @($False,"Failed to Create Folder Package for $folderName with error $($folderPath[1])")
        }


}

### Function:  Add-Groups ###
#
#    Adds Business Author and Business Analyst Ad-HOC Groups
#
# Arguments:
#       [string] $groupstemplate
#       [string] $platformpassword
# Return Values:
#       [array]
# Throws: None
#
Function Add-Groups() {
    param(
        [string] $groupstemplate,
        [string] $platformpassword
    )

    $logger.logInfo("Add Groups called")

    if (-not (Test-FileExists $groupstemplate)) {

        return @($False, "The required file was not found at $($groupstemplate)")
    } else {

        #required parameters for Get-Arguments and Use-ConfigTool
        $params = @{}
        $params.netanserverGroups = $groupstemplate   #absolute path of groups file which needs to be imported.
        $params.configToolPassword = $platformpassword   #Network Analytics Server Platform Password
        $params.spotfirebin = "$($TOMCAT)\spotfire-bin\"   #Tomcat bin directory
        #NetAnServerConfig.Get-Arguments
        $configToolParams = Get-Arguments "import-groups" $params
        if(-not $configToolParams) {

            $logger.logError($MyInvocation, "NetAnServerUtility.Get-Arguments returned $configToolParams", $False)
            return @($False, "Error in importing Groups")
        }

        #NetAnServerConfig.Use-ConfigTool
        $isImported = Use-ConfigTool $configToolParams $params $global:configToolnewLogfile
        if(-not $isImported) {
            $logger.logError($MyInvocation, "NetAnServerUtility.Use-ConfigTool returned $configToolParams", $False)
            return @($False, "Error in importing Groups")

        }
        else {
            return @($True, "Import Successful")

        }
    }

}


### Function:  Set-Licence ###
#
#    Sets licence for  Business Author and Business Analyst Ad-HOC Groups
#
# Arguments:
#              [string] $platformpassword
# Return Values:
#       [array]
# Throws: None
#
Function Set-Licence(){
    param(
        [string] $platformpassword
	)

    $groupName= 'Business Author'
	$licenseConfigStages = @('set-license')
	$params = @{}
	$params.configToolPassword = $platformpassword   #Network Analytics Server Platform Password
	$params.spotfirebin = "$($TOMCAT)\spotfire-bin\"   #Tomcat bin directory
    $global:configToolLogfile = "$ADHOC_LOG_DIR\$(get-date -Format 'yyyyMMdd_HHmmss')_configTool.log"
	$isUpdated = Update-License $params $licenseConfigStages $businessAuthorLicenseList $groupName
		if ($isUpdated) {
            $logger.logInfo(" Business Author licence successfully set")

        } else {
            $logger.logError($MyInvocation, "Failed to set Business Author licence", $False)
            return @($False, "Failed to set Business Author licence")
        }
	$groupName= 'Business Analyst'
    $isUpdated = Update-License $params $licenseConfigStages $businessAnalystLicenseList $groupName

		if ($isUpdated) {
            $logger.logInfo(" Business Analyst licence successfully set")

        } else {
            $logger.logError($MyInvocation, "Failed to set Business Analyst licence", $False)
            return @($False, "Failed to set Business Analyst licence")

   }
   return @($TRUE, "Set Business Author and Business Analyst licence Successful")
   }