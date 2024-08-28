# ********************************************************************
# Ericsson Radio Systems AB                                     Script
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
# Name    : FolderCreation.ps1
# Date    : 21/08/2020
# Purpose : Get users without folders in Database, create a folders for each user.
#


$database = 'netanserver_db'
$query="select distinct user_name
        from users u
        inner join group_members gm on gm.member_user_id = u.user_id
        inner join groups g on gm.group_id = g.group_id
        where user_name not in
            (select title
             from lib_items
             where item_type=
                 (select type_id
                  from lib_item_types
                  where display_name='folder'))
          and u.external_id is not null
          and g.group_name in ('netan-server-admin-access','netan-business-analyst-access','netan-business-author-access')"
$server = 'localhost'
$user = 'netanserver'
$envVariable = "NetAnVar"

Import-Module ManageAdhocUsers -DisableNameChecking
Import-Module NetAnServerUtility -DisableNameChecking

### Function:   Create-CustomLibFolder ###
#
# Queries the user database and identifies users without custom folders.
# Creates a folder for each user found.
#
# Arguments: None
#
# Return Values: None
#
# Throws: None
#
Function Create-CustomLibFolder(){
                $platformPassword =  (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password
                $results = Invoke-UtilitiesSQL -Database $database -Username $user -Password $platformPassword -ServerInstance $server -Query $query -Action fetch
                foreach ($result in $results[1].user_name){
					add-folder -folderName $result -password $platformPassword
				}
}
Create-CustomLibFolder