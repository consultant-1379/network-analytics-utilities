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
# Name    : DefinedUsers.psm1
# Date    : 18/08/2020
# Purpose : Queries the database and returns the number of the each
#           users per user group: Business Analyst, Business Author, Consumer, Other
#
# Usage   : Create-Databases $installParams
#

$loc = Get-Location
Import-Module NetAnServerUtility

#    Returns all Consumer users where users are not 
#    also members of the Business Author or analyst groups
#
$consumerQuery = "SELECT count (*) as Consumers 
                FROM (
                SELECT 
                    g.group_name as `"GROUP`"
                FROM users u
                    INNER JOIN group_members gm
                    ON gm.member_user_id = u.user_id 
                    INNER JOIN groups g
                    ON gm.group_id = g.group_id
                    WHERE g.group_name = `'Consumer`'
                        AND u.user_name NOT IN (
                    SELECT 
                    u.user_name as `"USERNAME`"
                FROM users u
                    INNER JOIN group_members gm
                    ON gm.member_user_id = u.user_id 
                    INNER JOIN groups g
                    ON gm.group_id = g.group_id
                    WHERE g.group_name = `'Business Author`'
                    )
                    AND u.user_name NOT IN (
                    SELECT 
                    u.user_name as `"USERNAME`"
                FROM users u
                    INNER JOIN group_members gm
                    ON gm.member_user_id = u.user_id 
                    INNER JOIN groups g
                    ON gm.group_id = g.group_id
                    WHERE g.group_name = `'Business Analyst`'
                    )
                    ) consumers;"


#    Returns all Business Author users where users are not
#    also members of the analyst group
$authorQuery = "SELECT count(*)  as BusinessAuthor from (
            SELECT 
                    g.group_name as `"GROUP`"
                FROM users u
                    INNER JOIN group_members gm
                    ON gm.member_user_id = u.user_id 
                    INNER JOIN groups g
                    ON gm.group_id = g.group_id
                    WHERE g.group_name = `'Business Author`'
                    AND u.user_name NOT IN (
                    SELECT 
                    u.user_name as `"USERNAME`"
                FROM users u
                    INNER JOIN group_members gm
                    ON gm.member_user_id = u.user_id 
                    INNER JOIN groups g
                    ON gm.group_id = g.group_id
                    WHERE g.group_name = `'Business Analyst`'
                    )
                    )   authors;"


#
#    Returns all Analyst users
$analystQuery = "SELECT count(*) as BusinessAnalyst from (
            SELECT 
                    g.group_name as `"GROUP`"
                FROM users u
                    INNER JOIN group_members gm
                    ON gm.member_user_id = u.user_id 
                    INNER JOIN groups g
                    ON gm.group_id = g.group_id
                    WHERE g.group_name = `'Business Analyst`'
                    )   analysts;"

#
#    Returns all other users
$othersQuery = "SELECT count (*) as Others 
                FROM (
                SELECT 
                    g.group_name as `"GROUP`"
                FROM users u
                    INNER JOIN group_members gm
                    ON gm.member_user_id = u.user_id 
                    INNER JOIN groups g
                    ON gm.group_id = g.group_id
                WHERE u.user_name NOT IN (
                    SELECT 
                    u.user_name as `"USERNAME`"
                FROM users u
                    INNER JOIN group_members gm
                    ON gm.member_user_id = u.user_id 
                    INNER JOIN groups g
                    ON gm.group_id = g.group_id
                WHERE g.group_name = `'Business Author`'
                    )
                AND u.user_name NOT IN (
                    SELECT 
                    u.user_name as `"USERNAME`"
                FROM users u
                    INNER JOIN group_members gm
                    ON gm.member_user_id = u.user_id 
                    INNER JOIN groups g
                    ON gm.group_id = g.group_id
                WHERE g.group_name = `'Business Analyst`'
                    )
                    AND u.user_name NOT IN (
                    SELECT 
                    u.user_name as `"USERNAME`"
                FROM users u
                    INNER JOIN group_members gm
                    ON gm.member_user_id = u.user_id 
                    INNER JOIN groups g
                    ON gm.group_id = g.group_id
                WHERE g.group_name = `'Consumer`'
                    )
                    ) consumers;"


### Function: Get-DefinedUsers ###
#
#    Returns a count of all users by group type.
#
# Return Values:
#       
# Throws:
#       None
#
Function Get-DefinedUsers {
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
    $sqlQueries = ($consumerQuery, $authorQuery, $analystQuery, $othersQuery)
    $sqlResults =@()

    Foreach ($sqlQuery in $sqlQueries){
        Try {
            $result = Invoke-UtilitiesSQL -database $database -username $username -password $password -serverInstance $serverInstance -query $sqlQuery -Action fetch
            $sqlResults += $result[1]
        } Catch {
            return @($False, "$_.Exception.Message")    
        }
    }
    
    Set-Location $loc
    $definedHash = DefinedUsersToHashTable $sqlResults
    return $definedHash

}

#
# This function converts the DataRow results into a formatted OrderedDictionary
# Returns OrderedDictionary
#
Function DefinedUsersToHashTable{
    param(
        [Array]$userData
    )
    $TIMESTAMP = "TimeStamp ="
    $logTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss')
    $unFormtable= New-Object System.Collections.Specialized.OrderedDictionary
    $formatted = $userData | Format-List | Out-String 
    $formatted = $formatted -replace(" :", "=")
    $sumTable = ConvertFrom-StringData -StringData $formatted
    $total = ($sumTable.Values | Measure-Object -Sum).Sum
    $formatted = $TIMESTAMP+$logTime+"`n" +$formatted +"Total = $total"
    $unFormtable = ConvertFrom-StringData -StringData $formatted
    
    #Format to the order required
    $formattedTable = New-Object System.Collections.Specialized.OrderedDictionary
    $formattedTable.Add( 'TIMESTAMP',$unFormtable.Get_Item('TimeStamp'))
    $formattedTable.Add( 'ANALYST',$unFormtable.Get_Item('BusinessAnalyst'))
    $formattedTable.Add( 'AUTHOR',$unFormtable.Get_Item('BusinessAuthor'))
    $formattedTable.Add( 'CONSUMER',$unFormtable.Get_Item('Consumers'))
    $formattedTable.Add( 'OTHER',$unFormtable.Get_Item('Others'))
    $formattedTable.Add( 'TOTAL',$unFormtable.Get_Item('Total'))

    return $formattedTable  

}