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
# Name    : UserAudit.psm1
# Date    : 21/08/2020
# Purpose : Get defined user, get concurrent users, create audit file, populate audit database
#
#

$db = 'netanserver_db'
$server = 'localhost'
$user = 'netanserver'
$envVariable = "NetAnVar"

$restoreResourcesPath = "C:\Ericsson\NetAnServer\RestoreDataResources\"
[xml]$xmlObj = Get-Content "$($restoreResourcesPath)\version\supported_NetAnPlatform_versions.xml"
$platformVersionDetails = $xmlObj.SelectNodes("//platform-details")

foreach ($platformVersionString in $platformVersionDetails)
{
    if ($platformVersionString.'current' -eq 'y') {
            $version = $platformVersionString.'version'
        }
}
$currentTimeStamp = $(get-date -Format 'yyyyMMdd')
$drive = (Get-ChildItem Env:SystemDrive).value
$usageLog = "C:\Ericsson\NetAnServer\Server\$($version)\tomcat\logs\usage.log"
$outputLogDir = $drive + "\Ericsson\Instrumentation\UserAudit\"
$auditFile = 'userAuditLog'+$currentTimeStamp+'.txt'
$auditFilePath = $outputLogDir+$auditFile
$TYPE = "Type="
$DEFINED = "defined_users"
$CONCURRENT = "concurrent_users"



Import-Module DefinedUsers
Import-Module NetAnServerUtility
Import-Module RepDBUtilities -DisableNameChecking
Import-Module ConcurrentUsers

Function Main {

    $logdir = CheckLogDirs

    If($logdir) {
        Check-AuditFileExists
    }

    $platform = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable $envVariable)).GetNetworkCredential().Password

    If ($platform -ne $null) {


    # ------------------------------------
    #         Get defined users
    # ------------------------------------
    $definedUsers = Get-DefinedUsers -database $db -serverInstance $server -username $user -password $platform

    #Add defined Users to audit file
    $definedUsersStr= [string]($definedUsers.GetEnumerator()| % { "$($_.Value)`t"})
    $definedUsersStr += " "+"DEFINED_USERS"
    $definedUsersStr | Out-File $auditFilePath -Append

    #Add defined users to database
    Try {
       $defDBResult = Insert-UserDatatoDB -usersData $definedUsers -table $DEFINED -password $platform
    } Catch {
        Exit -1
    }

    # ------------------------------------
    #         Get Concurrent users
    # ------------------------------------
        If (Test-Path $usageLog ) {

            $concurrentUsers = Get-ConcurrentUsers -usagelog $usageLog -platform $platform
            $concurrentUsersStr= [string]($concurrentUsers.GetEnumerator()| % { "$($_.Value)`t" })
            $concurrentUsersStr += " "+"CONCURRENT_USERS"
            $concurrentUsersStr | Out-File $auditFilePath -Append

            #Add concurrent users to database
            Try {
                $conDBResult = Insert-UserDatatoDB -usersData $concurrentUsers -table $CONCURRENT -password $platform
            } Catch {
               Exit -1
            }

        }Else{
            Exit -1
        }

    } Else {
        Exit -1
    }
}


#Checks if file audit file exists, creates it if it doesnt
Function Check-AuditFileExists {
    If ( !(Test-Path ($outputLogDir+$auditFile)) ){
        New-Item $auditFilePath -type File | Out-Null
        $cols = "TIMESTAMP `t ANALYST `t AUTHOR `t CONSUMER `t OTHER `t TOTAL `t Type"
        $cols | Out-File $auditFilePath

    }
}


#Checks if file audit log directory exists, creates it if it doesnt
Function CheckLogDirs {

    Try {

        If (!(Test-Path $outputLogDir)) {
            New-Item -ItemType directory -Path $outputLogDir -ErrorAction stop | Out-Null
        }
        return $true

    } Catch {

        return $false
    }
}

Main
