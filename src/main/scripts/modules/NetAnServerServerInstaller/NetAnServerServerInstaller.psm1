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
# Name    : NetAnServerServerInstaller.psm1
# Date    : 20/08/2020
# Purpose : Installs the Server Component of Network Analytic Server Deployment
#
# Usage   : Install-NetAnServerServer [hashtable]$map
#


Import-Module NetAnServerUtility

$logger = Get-Logger( $LoggerNames.Install )

###### Map Keys #######
$serverLog = 'serverLog'
$installDirectory = 'installServerDir'
$serverPort = 'serverPort'
$serverRegistrationPort = 'serverRegistrationPort'
$serverCommunicationPort = 'serverCommunicationPort'
$serviceName = 'serviceNetAnServer'
$software = 'serverSoftware'
$installTimeout = 600000 #10 minutes



### Function: Install-NetAnServerServer ###
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
Function Install-NetAnServerServer {
    param(
        [hashtable] $map
    )

    $logger.logInfo("Starting install of Network Analytics Server Component", $True)
    $paramsValid = Approve-Params($map)

    if ($paramsValid) {

        if(Test-ServerSoftwareInstalled $map) {
            $logger.logInfo("Network Analytics Server Previous Install Detected." +
                " Skipping install of Server Component", $True)
            return $True
        } else {
            return Install-Software $map
        }

    } else {
        $logger.logError($MyInvocation, "Parameters are not valid. Network" +
            " Analytics Server Component Failed", $True)
        return $False
    }
}


### Function: Validate-Params ###
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

    $validParamKeys = @($serverLog, $installDirectory, $serverPort, $serviceName, $software)

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


### Function: Test-ServerSoftwareInstalled ###
#
#   Verifies if Server Software is previously installed.
#   Checks if the service (provided in map) exists.
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Test-ServerSoftwareInstalled {

    param(
        [hashtable] $map
    )

    $logger.logInfo("Checking if Network Analytics Server Component is installed", $True)
    $serviceExists = Test-ServiceExists $map[$serviceName]

    if ($serviceExists) {
        $logger.logInfo("Network Analytics Server Component is installed", $True)
        return $True
    } else {
         $logger.logInfo("Network Analytics Server Component is not installed", $True)
        return $False
    }
}


### Function: Install-Software ###
#
#   Installs the Server Software.
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
    $logger.logInfo("Installing Software for Network Analytics Server Component", $True)
    $serverSoftware = $map[$software]
    $argumentList = Get-Arguments $map
    $logger.logInfo("Start-Process -FilePath $serverSoftware -ArgumentList $argumentList -passthru")
    $installProcess = Start-Process -FilePath $serverSoftware -ArgumentList $argumentList -passthru

    if(-not $installProcess.WaitForExit($installTimeout)) {
        $logger.logError($MyInvocation, "Network Analytics Server Component Install has timed out. " +
            "Killing Process", $True)
        $installProcess.Kill()
        $logger.logError($MyInvocation, "Network Analytics Server Component Install Process Killed. " +
            "Exit Code $installProcess.ExitCode", $True)
    }

    if($installProcess.ExitCode -eq 0) {
        $logger.logInfo("Installation of Network Analytics Server Software Complete.", $True)

        return Test-ServerSoftWareInstalled $map
    } else {
        $logger.logError($MyInvocation,"Installation of Network Analytics Server was Unsuccessfull. " +
            "Exited with code: $($installProcess.ExitCode)`nPlease inspect Server Install Log File " +
            "$($map[$serverLog])", $True)
        return $False
    }
}


### Function: Build-Arguments ###
#
#   Builds the list of parameters to be handed to start-process
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [list]$argumentList
#
Function Get-Arguments {
    param(
        [hashtable] $map
    )
    $argumentList = ""
    #$argumentList += "/s /v""/qn /l*vx"
	$argumentList += " INSTALLDIR=$($map[$installDirectory])"
	$argumentList += " SPOTFIRE_WINDOWS_SERVICE=Create"
	$argumentList += " SERVER_FRONTEND_PORT=$($map[$serverPort])"
    $argumentList += " SERVER_BACKEND_REGISTRATION_PORT=$($map[$serverRegistrationPort])"
	$argumentList += " SERVER_BACKEND_COMMUNICATION_PORT=$($map[$serverCommunicationPort])"
	$argumentList += " NODEMANAGER_HOST_NAMES=localhost"
	$argumentList += " -silent -log $($map[$serverLog])"
    return $argumentList
}
### Function: Update-Server ###
#
#   This Function calls Upgrade tool
#
# Arguments:
#   None
#
# Return Values:
#   boolean
#
Function Update-Server {
    param(
        [hashtable] $map
    )


    $fromtext="<the location of the root directory of the TIBCO Spotfire Server you're upgrading from>"

    if (Test-Path ("C:\Ericsson\NetAnServer\Server\" + $map.previousPlatformVersion)) {
        $fromtextnew="C:\\Ericsson\\NetAnServer\\Server\\" + $map.previousPlatformVersion
    } else {
        $fromtextnew="C:\\Ericsson\\NetAnServer\\Server"
    }

    $upgradePath = 'C:\Ericsson\NetAnServer\Server\' + $map.currentPlatformVersion + '\tools\upgrade\'
    $upgradeTool= "$($upgradePath)\upgradetool.bat"

	(Get-Content "$($upgradePath)silent.properties").replace($fromtext, $fromtextnew) | Set-Content "$($upgradePath)\silent.properties" -Force
	Set-Location $upgradePath
	$logger.logInfo("Upgrading Software for Network Analytics Server Component", $True)
    $serverSoftware = $upgradeTool
    $argumentList = "-silent $($upgradePath)silent.properties"

    $logger.logInfo("Start-Process -FilePath $serverSoftware -ArgumentList $argumentList -passthru")
    $installProcess = Start-Process -FilePath $serverSoftware -ArgumentList $argumentList -passthru -Wait

    if(-not $installProcess.WaitForExit($installTimeout)) {
        $logger.logError($MyInvocation, "Network Analytics Server Component Upgrade has timed out. " +
            "Killing Process", $True)
        $installProcess.Kill()
        $logger.logError($MyInvocation, "Network Analytics Server Component Upgrade Process Killed. " +
            "Exit Code $installProcess.ExitCode", $True)
    }

    if($installProcess.ExitCode -eq 0) {
        $logger.logInfo("Upgrade of Network Analytics Server Software Complete.", $True)
        return $True
    } else {
        $logger.logError($MyInvocation,"Installation of Network Analytics Server was Unsuccessful. " +
            "Exited with code: $($installProcess.ExitCode)`nPlease inspect Server Install Log File " +
            "$($map[$serverLog])", $True)
        return $False
    }


}