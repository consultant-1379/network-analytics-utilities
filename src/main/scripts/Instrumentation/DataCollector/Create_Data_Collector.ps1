# ********************************************************************
# Ericsson Radio Systems AB                                     SCRIPT
# ********************************************************************
#
#
# (c) Ericsson Inc. 2015 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Inc. The programs may be used and/or copied only with
# the written permission from Ericsson Inc. or in accordance with the
# terms and conditions stipulated in the agreement/contract under
# which the program(s) have been supplied.
#
# ********************************************************************
# Name    : Create_Data_Collector.ps1
# Date    : 07/21/2015
# Purpose : Starts/Creates Data Collector set for Network Analytics Server from template
#
# Usage   : Create_Data_Collector
#


Import-Module Logger

$name = 'Network_Analytics_Server_Data_Collector_Set'
$datacollectorset = new-Object -COM Pla.DataCollectorSet
$xmlPath = 'C:\Ericsson\NetAnServer\Scripts\Instrumentation\DataCollector\DataCollector_Template.xml'
$server = hostname
$runningStatus = 0

[xml] $docXml = Get-Content $xmlPath 
$logDir = $docXml.DataCollectorSet.OutputLocation
$dataCollectorLogDir = "C:\Ericsson\Instrumentation\DataCollectorLogs"
$sleepTime = 5
$logger = Get-Logger($LoggerNames.Install)


Function Main() {

    CheckLogDir
    SetStatus
    $logger.logInfo("Data collector set started successfully.", $false)
}


#-----------------------------------------------------------------------
#    Checks log directory and creates if non-existent
#-----------------------------------------------------------------------
Function CheckLogDir() {
    if((Test-Path $logDir) -eq 0) {
        mkdir $logDir | Out-Null ;
    }

    if((Test-Path $dataCollectorLogDir) -eq 0) {
        mkdir $dataCollectorLogDir | Out-Null ;
    }
    $logger.setLogDirectory($dataCollectorLogDir)
    $logger.setLogName('DataCollector_log.log')
}

### Function:  CreateCollectorSet ###
#
#    Creates Temp DataCollector Set
#
# Arguments:
#       None 
# Return Values:
#       [int]@status
# Throws: None
#
Function CreateCollectorSet() {

    try {

        $logger.logInfo("Checking status of data collector set.",$False)
        $datacollectorset = New-Object -COM Pla.DataCollectorSet
        $datacollectorset.Commit($name,$null,0x0003) | Out-Null
        $datacollectorset.Query($name,$server)
        $status = $datacollectorset.Status
        $logger.logInfo("Data collector set status: $($status).",$False)
        return $status

    }catch {

        $logger.logError($MyInvocation, $_.Exception, $true)
        $status = 4
        return $status
    }

}


### Function:  SetStatus ###
#
#    Finds and sets datacollector status
#
# Arguments:
#       None 
# Return Values:
#       None
# Throws: None
#

Function SetStatus {

    try {
        
        $status = CreateCollectorSet

        switch ($status) {
            0 {
                $logger.logInfo("Data collector set status: stopped.",$False)
                $runningStatus = $FALSE
            }
            1 {
                $logger.logInfo("Data collector set status: running.", $False)
                $runningStatus = $TRUE
            }
            2 {
                $logger.logInfo("Data collector set status: compiling.",$False)
                $runningStatus = $TRUE
            }
            3 {
                $logger.logInfo("Data collector set status: pending.",$False)
                $runningStatus = $TRUE
            }
            4 {
                $logger.logInfo("Data collector set status: unknown.",$False)
                $runningStatus = $FALSE
            }
            default {
                $logger.logInfo("Data Collector set Status: Undefined.",$False)
                $runningStatus = $FALSE
            }
        }

        Run($runningStatus)

    }catch {
         $logger.logError($MyInvocation, $_.Exception, $True)
    }
}

### Function:  SetTemplateStartCollector ###
#
#    Sets template from XML and starts the collector
#
# Arguments:
#       None 
# Return Values:
#       None
# Throws: None
#

Function SetTemplateStartCollector{

    if (Test-Path $xmlPath) {

     try{
            Remove-Item $logDir -recurse
            $datacollectorset = New-Object -COM Pla.DataCollectorSet
            $xml = Get-Content $xmlPath 
            $logger.logInfo("Setting xml template: $($xmlPath)",$False)
      
            $datacollectorset.SetXml($xml)
            sleep -s $sleepTime
            
            if($runningStatus -eq $FALSE) {
                $datacollectorset.Commit($name,$null,0x0003) | Out-Null
                sleep -s $sleepTime
                $datacollectorset.Query($name,$server) 
                sleep -s $sleepTime
            }

            $datacollectorset.Commit($name,$null,0x0003) | Out-Null
            $datacollectorset.Start($true) 

            $logger.logInfo("Data Collector Name: $($datacollectorset.Name) ",$False)
            $logger.logInfo("Status: $($datacollectorset.Status) ",$False)
            $logPath = Test-Path $logDir
       
            $logger.logInfo("Log folder created: $logPath",$False)
        
        } catch {

            $logger.logError($MyInvocation, $_.Exception, $True)
            Exit
        }

    }else {
        $errormessage = 'Path to XML Template file is invalid, exiting script'
        $logger.logError($MyInvocation, $errormessage, $True)
        Exit
    }
}
#-----------------------------------------------------------------------
#   If data collector set exists stop it and delete.
#   Start setTemplate
#
#-----------------------------------------------------------------------

### Function:  Run ###
#
#   If data collector set exists stop it and delete.
#   Start setTemplate
#
# Arguments:
#       [boolean] 
# Return Values:
#       None
# Throws: None
#

Function Run($isDataCollectorRunning) {

    if($isDataCollectorRunning) {
      
        $logger.logInfo("Data Collector Set exists, Removing.",$False)
        $datacollectorset.Query($name,$server) 
        $datacollectorset.Stop($TRUE)
        sleep -s $sleepTime
        $datacollectorset.Delete()
        sleep -s $sleepTime
        $logger.logInfo("Removing Current log files",$False)

    } else {

        $logger.logInfo("No Running Data Collector Set found . Creating",$False)
    }
    SetTemplateStartCollector
}

Main
