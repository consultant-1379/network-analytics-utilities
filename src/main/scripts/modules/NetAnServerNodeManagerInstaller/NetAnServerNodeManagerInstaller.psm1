# ********************************************************************
# Ericsson Inc.                                                 Module
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
# Name    : NetAnServerNodeManagerInstaller.psm1
# Date    : 20/08/2020
# Purpose : Installs the Server Component of Network Analytic Server Deployment
#
# Usage   : Install-NetAnServerNodeManager [hashtable]$map
#


Import-Module NetAnServerUtility

$logger = Get-Logger( $LoggerNames.Install )

###### Map Keys #######
$nodeManagerLog = 'nodeManagerLog'
$installDirectory = 'installNodeManagerDir'
$nodeRegistrationPort = 'nodeRegistrationPort'
$nodeCommunicationPort = 'nodeCommunicationPort'
$nodeBackendregistrationPort = 'serverRegistrationPort'
$nodeBackendCommunicationPort = 'serverCommunicationPort'
$serverName = $(hostname)
$nodeManagerHostName = $(hostname)
$nodeManagerSoftware = 'nodeManagerSoftware'
$nodeServiceName='nodeServiceName'

#10 minutes
$installTimeout = 600000

### Function: Install-NetAnServerNodeManager ###
#
#   Installs the Network Analytic Server Component.
#   Validates parameters and tests for previous install.
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Install-NetAnServerNodeManager {
    param(
        [hashtable] $map
    )

    $logger.logInfo("Starting install of Network Node Manager Component", $True)
    $paramsValid = Approve-Params($map)

    if ($paramsValid) {

        if(Test-NodeManagerSoftwareInstalled $map) {
            $logger.logInfo("Network Analytics Node Manager Previous Install Detected." +
                " Skipping install of Node Manager Component", $True)
            return $True
        } else {
            return Install-Software $map
        }

    } else {
        $logger.logError($MyInvocation, "Parameters are not valid. Network" +
            " Analytics Node Manager Component Failed", $True)
        return $False
    }
}

### Function: Get-NodeID ###
#
#   Returns the node ID of the node to be trusted
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Get-NodeID {
    param(
        [hashtable] $map
    )
	$db = $map.dbName
	$server = $map.connectIdentifer
	$user = $map.dbUser
	$password = $map.configToolPassword

    $logger.logInfo("Get node ID to be trusted", $False)
	$query = "select top 1 id from node_auth_request order by last_modified desc"

	 $result = Invoke-UtilitiesSQL -Database $db -Username $user -Password $password -ServerInstance $server  -Query $query Action -fetch
	 if($result[1].id){
		$nodeID = $result[1].id
        $logger.logInfo("Node ID found " + $nodeID, $True)
		return $nodeID
	 }else{
		$logger.logWarning("Node ID not found. Please wait...", $False)
		return $false
	 }
}

### Function: Get-NodeStatus ###
#
#   Returns after services on node are online.
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Get-NodeStatus {
    param(
        [hashtable] $map
    )


	$db = $map.dbName
	$server = $map.connectIdentifer
	$user = $map.dbUser
	$password = $map.configToolPassword
    $timeout = new-timespan -Minutes 15
    $status=$False

    $logger.logInfo("Wait for Services to come in running state", $False)
	$query = "select count(*) as count from node_services where service_type=1 and status=`'RUNNING`'"

    $result = Invoke-UtilitiesSQL -Database $db -Username $user -Password $password -ServerInstance $server  -Query $query -Action fetch
    $sw = [diagnostics.stopwatch]::StartNew()
    while($sw.elapsed -lt $timeout -and $status -eq $False ){
        $result = Invoke-UtilitiesSQL -Database $db -Username $user -Password $password -ServerInstance $server  -Query $query -Action fetch
	    if($result[1].count -ne 6){
            $logger.logInfo("wait for Services to come in running state", $False)
            Start-Sleep -s 10
            }
        else{
            $status=$True
        }

    }
	 return $status
}

### Function: Get-NodeIDToDelete ###
#
#   Returns the node ID of the node to be Deleted for Upgrade
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Get-NodeIDToDelete {
    param(
        [hashtable] $map
    )
	$db = $map.dbName
	$server = $map.connectIdentifer
	$user = $map.dbUser
	$password = $map.configToolPassword
    $logger.logInfo("Get node ID to be deleted", $False)
	$query = "select is_online from nodes where port='9443'"
	$result = Invoke-UtilitiesSQL -Database $db -Username $user -Password $password -ServerInstance $server  -Query $query -Action fetch
    $logger.logInfo("Node status before sleep " + $result[1].is_online, $False)
	while($result[1].is_online -ne 1){
	 Start-Sleep -s 10
	 $result = Invoke-UtilitiesSQL -Database $db -Username $user -Password $password -ServerInstance $server  -Query $query -Action fetch
     $logger.logInfo("Node status after sleep " + $result[1].is_online, $False)
	}
	#intention sleep so that next delete command is successful as sometimes this does fail even when status of server is online in database.
	Start-Sleep -s 30
	$query = "select id from nodes where port='9444' and is_online = 0"
	$result = Invoke-UtilitiesSQL -Database $db -Username $user -Password $password -ServerInstance $server  -Query $query -Action fetch
	 if($result[1].id){
		$nodeID = $result[1].id
        $logger.logInfo("Node ID found " + $nodeID, $False)
		return $nodeID
	 }else{
		$logger.logWarning("Node ID not found. Please wait...", $False)
		return $false
	 }
}
### Function: Trust-Node ###
#
#   Trusts Node.
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Trust-Node {
    param(
        [hashtable] $map
    )

	$nodeid = Get-NodeID $map
	if($nodeid){
		$arguments = Get-Arguments trust-node $map
		$arguments += $nodeid.ID
		$result = Use-ConfigTool $arguments $map $global:configToolLogfile
		if($result){
			$logger.logInfo("Node " +  $nodeid.ID  +" trusted successfully", $True)
			return $true
		}else{
			$logger.logInfo("Node " +  $nodeid.ID  +" not trusted successfully", $True)
			return $false
		}
	}else{
		return $false
    }
}
### Function: Delete-Node ###
#
#   Delete Node.
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Delete-Node {
    param(
        [hashtable] $map
    )

	$nodeid = Get-NodeIDtoDelete $map
	if($nodeid){
		$arguments = Get-Arguments delete-node $map
		$arguments += $nodeid

    while(!(Test-Path($map.installServerDir + "\nm\trust\keystore.p12"))) {
	    Start-Sleep -s 5
        $logger.logInfo("Waiting for keystore.p12", $False)
	    }

		$result = Use-ConfigTool $arguments $map $global:configToolLogfile
		if($result){
			$logger.logInfo("Node " +  $nodeid  +" deleted successfully", $False)
			return $true
		}else{
			$logger.logInfo("Node " +  $nodeid  +" not deleted successfully", $False)
			return $false
		}
	}else{
		$logger.logWarning("No Node Found for Deletion", $False)
		return $true
    }
}
### Function: Create-Services ###
#
#  Create-Services.
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Create-Services {
    param(
        [hashtable] $map
    )

    $logger.logInfo("Start procedure to create services", $True)

    Copy-Item -Path $($map.nodeManagerConfigFile) -Destination $($map.nodeManagerConfigDir) -Recurse -Force
}

### Function: Approve-Params ###
#
#   Validates the map parameters. Checks that all required
#   Parameters are present and not $null
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Approve-Params {
    param(
       [hashtable] $map
    )

    $validParamKeys = @($nodeManagerLog, $installDirectory, $nodeRegistrationPort, $nodeCommunicationPort, $nodeServiceName, $nodeManagerSoftware)

    if ($map) {
        foreach ($paramKey in $validParamKeys) {
            if (-not $map[$paramKey]) {
                $logger.logError($MyInvocation, "Invalid Parameters Passed. Parameter at " +
                    "key $paramKey not Found", $True)
                return $False
            }
        }

        $logger.logInfo("All Parameters validated successfully")
        return $True

    } else {
        $logger.logError($MyInvocation, "Incorrect Parameters Passed. Parameter Map is Null " +
            "Valued", $True)
        return $False
    }
}


### Function: Test-NodeManagerSoftwareInstalled ###
#
#   Verifies if Node Manager Software is previously installed.
#   Checks if the service (provided in map) exists.
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Test-NodeManagerSoftwareInstalled {

    param(
        [hashtable] $map
    )

    $logger.logInfo("Checking if Network Analytics Node Manager Component is installed", $True)
    $serviceExists = Test-ServiceExists $map[$nodeServiceName]
    if ($serviceExists) {
        $logger.logInfo("Network Analytics Node Manager Component is installed", $True)
        return $True
    } else {
         $logger.logInfo("Network Analytics Node Manager Component is not installed", $True)
        return $False
    }
}


### Function: Install-Software ###
#
#   Installs the Node Manager Software.
#   Starts the process and will kill process in event of timeout
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Install-Software {
    param(
        [hashtable] $map
    )
    $logger.logInfo("Installing Software for Network Analytics Node Manager Component", $True)
    $nodeManagerSoftware = $map[$nodeManagerSoftware]
    $argumentList = Get-NodeManagerArguments $map
	
    $logger.logInfo("Start-Process -FilePath $nodeManagerSoftware -ArgumentList $argumentList -passthru")
    $installProcess = Start-Process -FilePath $nodeManagerSoftware -ArgumentList $argumentList -passthru

    if(-not $installProcess.WaitForExit($installTimeout)) {
        $logger.logError($MyInvocation, "Network Analytics Node Manager Component Install has timed out. " +
            "Killing Process", $True)
        $installProcess.Kill()
    }

    if($installProcess.ExitCode -eq 0) {
        $logger.logInfo("Installation of Network Analytics Node Manager Software is Complete.", $True)
        return Test-NodeManagerSoftwareInstalled $map
    } else {
        $logger.logError($MyInvocation,"Installation of Network Analytics  Node Manager was Unsuccessfull. " +
            "Exited with code: $($installProcess.ExitCode)`nPlease inspect  Node Manager Install Log File " +
            "$($map[$nodeManagerLog])", $True)
        return $False
    }
}


### Function:  Get-NodeManagerArguments ###
#
#   Builds the list of parameters to be handed to start-process
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [list]$argumentList
#
Function Get-NodeManagerArguments {
    param(
        [hashtable] $map
    )

    $argumentList = ""

	$argumentList += " INSTALLDIR=$($map.installNodeManagerDir)"
    $argumentList += " NODEMANAGER_REGISTRATION_PORT=$($map[$nodeRegistrationPort]) "
    $argumentList += " NODEMANAGER_COMMUNICATION_PORT=$($map[$nodeCommunicationPort])"
    $argumentList += " SERVER_NAME=$serverName"
	$argumentList += " SERVER_BACKEND_REGISTRATION_PORT=$($map.serverRegistrationPort)"
    $argumentList += " SERVER_BACKEND_COMMUNICATION_PORT=$($map.serverCommunicationPort)"
    $argumentList += " NODEMANAGER_HOST_NAMES=$nodeManagerHostName "
	$argumentList += "NODEMANAGER_HOST=$serverName"
    $argumentList += " -silent -log $($map[$nodeManagerLog])"

    return $argumentList
}