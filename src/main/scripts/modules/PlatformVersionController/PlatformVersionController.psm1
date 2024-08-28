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
# Name    : PlatformVersionController.psm1
# Purpose : Platform version management utility
#
#

Import-Module RepDBUtilities -DisableNameChecking


function Get-PlatformVersionFile() {
    param(
        [string]$versionDir
    )

    if(-not (Test-Path $versionDir)) {
        return @($False, "platform version directory does not exist")
    }

    $xmlFile = Get-ChildItem $versionDir platform-utilities-release.*.xml

    if( $xmlFile -eq $null ) {
        return @($False, "platform-utilities-release.xml file not found in $($versionDir)")
    }

    return @($true, $xmlFile.Fullname)
}


function Get-PlatformDataFromFile() {
    param(
        [string]$platformXmlFile
    )

    $xmlHashTable = @{}

    if(-not (Test-Path $platformXmlFile)) {
        return @($False, "platform-utilities-release.xml not found at path: $($platformXmlFile)")
    }

    $build = $platformXmlFile.split(".")[-2]
    $xmlHashTable['RSTATE'] = $build -replace '^([A-Z]{1}?\d+?[A-Z])\d.*', '$1'
     #Get BUILD Number
    $xmlHashTable['BUILD'] = $build



    [xml]$xmlContent = Get-Content $platformXmlFile
    $xmlContent.SelectNodes("//text()") | Foreach { $xmlHashTable[$_.ParentNode.ToString()] = $_.Value }
    return @($True, $xmlHashTable)
}


function Invoke-InsertPlatformVersionInformation() {
    param(
        [hashtable] $platformReleaseHashTable,
        [string] $password
    )

    #RepDbUtilities.Add-PlatformVersionToDB
    $result = Add-PlatformVersionToDB $platformReleaseHashTable $password -ErrorAction Stop

    if((-not $result[0]) -and ($result[1].Contains("Cannot insert duplicate key in object 'dbo.NETWORK_ANALYTICS_PLATFORM'"))) {
        return @($True, "duplicate key, platform version already added")
    }

    return $result
}


function Get-PlatformVersions() {
    <#
        .SYNOPSIS
        Get-PlatformVersions displays information of installed platform and platform features on the Network Analytics Server.

        .DESCRIPTION
        The function returns installed versions of the platform
        as well as a full history of previously installed version of the platform.

        .EXAMPLE
        Get-PlatformVersions

        PRODUCT-ID   : CNA-XXX-XXXX
        PRODUCT-NAME : Network Analytics Deployment
        RELEASE      : NA
        RSTATE       : R3A
        BUILD        : R3A011
        STATUS       : ACTIVE
        INSTALL-DATE : YYYY-MM-DD hh:mm:ss

        .EXAMPLE
        Get-PlatformVersions  -FULL_HISTORY

        PRODUCT-ID   : CNA-XXX-XXXX
        PRODUCT-NAME : Network Analytics Deployment
        RELEASE      : NA
        RSTATE       : R3A
        BUILD        : R3A011
        STATUS       : ACTIVE
        INSTALL-DATE : YYYY-MM-DD hh:mm:ss

        PRODUCT-ID   : CNA-XXX-XXXX
        PRODUCT-NAME : Network Analytics Deployment
        RELEASE      : NA
        RSTATE       : R3A
        BUILD        : R3A010
        STATUS       : REMOVED
        INSTALL-DATE : YYYY-MM-DD hh:mm:ss

        .PARAMETER FULL_HISTORY
        A switch to optionally return a full history of installed features on the platform
    #>
        param(
         [switch] $FULL_HISTORY
    )
    $envVar = (New-Object System.Management.Automation.PSCredential 'N/A', $(Get-EnvVariable "NetAnVar")).GetNetworkCredential().Password
    if($FULL_HISTORY) {
        return (Get-PlatformVersionsFromDB $envVar $True)[1]
    } else {
        return (Get-PlatformVersionsFromDB $envVar )[1]
    }


}

