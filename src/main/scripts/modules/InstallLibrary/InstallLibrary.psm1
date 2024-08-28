# ********************************************************************
# Ericsson Radio Systems AB                                     MODULE
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
# Name    : InstallLibrary.psm1
# Date    : 20/08/2020
# Purpose : Install library structure for Network Analytics Server Features. 
#
# Usage   : See methods below
#           
#

Import-Module NetAnServerConfig
Import-Module Logger
Import-Module NetAnServerUtility


$logger = Get-Logger($LoggerNames.Install)


### Function:  Install-LibraryStructure ###
#
#   Function installs top-level library folders 
#
# Arguments:
#       [hashtable] $map
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Install-LibraryStructure() {

    param(
            [Parameter(Mandatory=$true)]
            [hashtable]$map
        )

        $logger.logInfo("Checking if Library Structure file exists in $($map.libraryLocation)", $True)

        If( -not (Test-Path($map.libraryLocation))){
            $logger.logError($MyInvocation, "The library Structure File does not exist in the  $($map.libraryLocation)", $True)
            return $False
         } Else {
              $logger.logInfo("Library file exists in $($map.libraryLocation)", $False)
         } 

        $logger.logInfo("Installing Library Structure...", $True)

        $arguments = Get-Arguments import-library-content $map
        If($arguments){
            $import = Use-ConfigTool $arguments $map $global:configToolLogfile
            If($import){
                $logger.logInfo("Install of Library Structure was successfull", $True)
                return $True
            } Else {
                $logger.logError($MyInvocation, "Error installing the Library Structure $import.ExitCode", $True)
                return $False
            }
        } Else {
            $logger.logError($MyInvocation, "No arguments returned", $True)
            return $False
        }
  

}