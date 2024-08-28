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
# Name    : FindDataSource.psm1
# Date    : 20/08/2020
# Purpose : To return existing datasource details.          
#
# Usage   : Check-DataSource $installParams
#           

$loc = Get-Location  

Import-Module -DisableNameChecking SqlPs
Import-Module Logger
Import-Module NetAnServerUtility

$logger = Get-Logger($LoggerNames.Install)
$SQL_TIMEOUT = 60            # 1 minute

function Check-DataSource() {
param(
        [Parameter(Mandatory=$true)]
        [hashtable]$installParams
    )

  $logger.logInfo("Checking for existing Datasources", $True)
  try{           
        $sqlQuery = "select title,item_id from lib_items where item_type=(select type_id from lib_item_types where label=`'datasource`')"
		$output = Invoke-UtilitiesSQL -Database $installParams.dbName -Username $installParams.dbUser -Password $installParams.dbPassword -ServerInstance $installParams.connectIdentifer -Query $sqlQuery -Action fetch
        Set-Location $loc
    } catch {
        Set-Location $loc
        $logger.logError($MyInvocation, " $_.Exception.Message" +" Please check entered password is correct for the NetAnServer database User " + $installParams.dbUser , $True) 
        return $False
		}
    
    if($output[1].title -ne $null){
        $logger.logInfo("Existing datasources found", $True)
        return $output[1]
    }else{
       $logger.logError($MyInvocation, " No datasource exists. Please create a datasource" , $True)  
       return $False
    }

}