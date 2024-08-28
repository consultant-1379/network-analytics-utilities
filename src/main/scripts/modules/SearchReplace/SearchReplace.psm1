# ********************************************************************
# Ericsson Radio Systems AB                                     MODULE
# ********************************************************************
#
#
# (c) Ericsson Radio Systems AB 2016 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Radio Systems AB, Sweden. The programs may be used
# and/or copied only with the written permission from Ericsson Radio
# Systems AB or in accordance with the terms and conditions stipulated
# in the agreement/contract under which the program(s) have been
# supplied.
#
# ********************************************************************
# Name    : SearchAndReplace.psm1
# Date    : 05/01/2016
# Purpose : Search file and replace datasource guid.
# Usage: SearchAndReplace ([String]$sourceDir, [String]$NewDSGuid)

Function SearchReplace {
    param(
    [string]$sourceDir,
    [string]$guidToFind,
    [string]$newDSGuid 
    )

    If(Test-path $sourceDir) {

        $directoryInfo = Get-ChildItem $sourceDir | Measure-Object
        If($directoryInfo.count -ne 0) {

            Try{

            #Gets each file in the $sourceDir, finds the $guidToFind and replaces it with $NewDSGuid
                ForEach ($File in ( Get-ChildItem $sourceDir -Recurse ) ){

                    If ( $File|Select-String $guidToFind -SimpleMatch -Quiet ) {

                        $File|Select-String $guidToFind -SimpleMatch -AllMatches|Select -ExpandProperty LineNumber -Unique|Out-Null

                        (Get-Content $File.FullName) | %{$_ -replace [RegEx]::Escape($guidToFind),$NewDSGuid} | Set-Content $File.Fullname
                    }
                }

                $count = Select-String -Path "$sourceDir\*" -pattern $guidToFind

                If ( $count -eq $null ) {
                    return $True

                } else {

                    return @($False,"SearchReplace did not complete correctly.")
                }

            }Catch {

                
                    return @($False,"SearchReplace error. $($_.Execption.message)")
            }

        } else {

            
            return @($False,"Directory $sourceDir is empty, exiting.")
        }

    } else {

        return @($False,"Directory $sourceDir not found, exiting.")

    }
}