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
# Name    : AnalystInstaller.psm1
# Date    : 20/08/2020
# Purpose : Installs the Server Component of Network Analytic Server Deployment
#
# Usage   : Install-NetAnServerAnalyst [hashtable]$map
#


Import-Module NetAnServerUtility

$logger = Get-Logger( $LoggerNames.Install )

###### Map Keys #######
$analystLog = 'analystLog'
$analystsoftware = 'analystSoftware'
$hostAndDomainURL = 'hostAndDomainURL'

#10 minutes
$installTimeout = 900000


### Function: Install-NetAnServerAnalyst ###
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
Function Install-NetAnServerAnalyst {
    param(
        [hashtable] $map
    )

    $paramsValid = Approve-Params($map)

    if ($paramsValid) {

        if(Test-AnalystSoftwareInstalled $map) {
            $logger.logInfo("Network Analytics Analyst Previous Install Detected." +
                " Skipping install of Analyst", $True)
            return $True
        } else {
            return Install-AnalystSoftware $map
        }

    } else {
        $logger.logError($MyInvocation, "Parameters are not valid. Network" +
            " Analytics Analyst Failed", $True)
        return $False
    }
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

    $validParamKeys = @($analystLog, $analystsoftware)

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


### Function: Test-AnalystSoftwareInstalled ###
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
Function Test-AnalystSoftwareInstalled {

    param(
        [hashtable] $map
    )

    $logger.logInfo("Checking if Network Analytics Analyst is installed", $True)
    $analystInstalled = Get-WmiObject -Class Win32_Product | ForEach-Object{if ($_.Name -Match "TIBCO Spotfire Analyst") {return $true}}

    if ($analystInstalled) {
        $logger.logInfo("Network Analytics Analyst is installed", $True)
        return $True
    } else {
         $logger.logInfo("Network Analytics Analyst is not installed", $True)
        return $False
    }
}



### Function: Install-AnalystSoftware ###
#
#   Installs the Analyst Software.
#   Starts the process and will kill process in event of timeout
#
# Arguments:
#   [hashtable] $map
#
# Return Values:
#   [boolean]$true|$false
#
Function Install-AnalystSoftware {
    param(
        [hashtable] $map
    )
    $logger.logInfo("Installing Software for Network Analytics Analyst", $True)
    $analystSoftware = $map[$analystsoftware]
    $argumentList = Get-AnalystArguments $map
	$logger.logInfo("Start-Process -FilePath $analystSoftware -ArgumentList $argumentList -passthru")
    $installProcess = Start-Process -FilePath $analystSoftware -ArgumentList $argumentList -passthru

    if(-not $installProcess.WaitForExit($installTimeout)) {
        $logger.logError($MyInvocation, "Network Analytics Analyst Install has timed out. " +
            "Killing Process", $True)
        $installProcess.Kill()
        $logger.logError($MyInvocation, "Network Analytics Analyst Install Process Killed. " +
            "Exit Code $installProcess.ExitCode", $True)
    }

    if($installProcess.ExitCode -eq 0) {
        $logger.logInfo("Installation of Network Analytics Analyst Complete.", $True)
        return Test-AnalystSoftwareInstalled $map
    } else {
        $logger.logError($MyInvocation,"Installation of Network Analytics Analyst was Unsuccessfull. " +
            "Exited with code: $($installProcess.ExitCode)`nPlease inspect Analyst Install Log File " +
            "$($map[$analystLog])", $True)
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
Function Get-AnalystArguments {
    param(
        [hashtable] $map
    )

	$hostName = $map[$hostAndDomainURL]

    $argumentList = ""
    $argumentList += "-silent -log $($map[$analystLog])"
    $argumentList += " SERVERURL=$hostName"


    return $argumentList
}