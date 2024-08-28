# ********************************************************************
# Ericsson Radio Systems AB                                     MODULE
# ********************************************************************
#
#
# (c) Ericsson Inc. 2016 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Inc. The programs may be used and/or copied only with
# the written permission from Ericsson Inc. or in accordance with the
# terms and conditions stipulated in the agreement/contract under
# which the program(s) have been supplied.
#
#
# ********************************************************************
# Name    : ZipUnZip.psm1
# Date    : 05/01/2016
# Purpose : Zipping and UnZipping Utility.
# Usage:
#   Zip-Dir([string] $SourceDirName, [String] $destDirName)
#   Unzip-File([string] $pathToZip, [string] $destDirName )

Import-Module NetAnserverUtility

Function Zip-Dir {
    param (  
        [String]$dirName,
        [String]$destDir
    )

    if(Test-path $destDir) {
        Remove-item $destDir -Recurse
    }

    Add-Type -assembly "system.io.compression.filesystem"

    [io.compression.zipfile]::CreateFromDirectory($dirName, $destDir) 
    
}

Function Unzip-File {
    param (  
        [String]$pathToZip,
        [String]$destDir
    )

    if(Test-FileExists $pathToZip) {
        
        if(Test-path $destDir) {
            Remove-item $destDir -Recurse
        }
        
        try{
            [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
            [System.IO.Compression.ZipFile]::ExtractToDirectory($pathToZip, $destDir)
            $dirCount  = (gci $destDir | Measure-Object).count
            
            if($dirCount -ne 0) {
                return @($True,$destDir)    
            }
            return @($False,"Error unzipping file $pathToZip. The zipped package contains no files.")
            
        } catch {
            $errorMessage = $_.Exception.Message            
            return @($False,"Error UnZipping $pathToZip"+ ". `n$errorMessage`n Exiting")
        }

        $directoryInfo = Get-ChildItem $destDir | Measure-Object
        if($directoryInfo.count -ne 0) {
            return $True 
        } else {
            return @($False,"Error unzipping file $pathToZip.")
        }

    } else {
        return @($False,"No Zip file $pathToZip found, exiting.")
    }
}