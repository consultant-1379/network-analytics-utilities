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
# Name    : NetAnServerConfig.psm1
# Date    : 20/08/2020
# Purpose : Configuration methods for NetAnServer.
#
# Usage   : See methods below
#
#

Import-Module Logger
Import-Module NetAnServerUtility
$configKeysUpgrade = @(
    'spotfirebin', #location of tomcat bin dir
    'configName', #default name of configuration
    'jconnSrc', #src location of jconn diver 'C:\temp\media\jconn'
    'jconnDir', #destination in tomcat\lib
    'netAnServerIP', #DB server IP
    'dbName', #NetanServer database name
    'dbUser', #NetAnServer database user
    'dbPassword', #NetAnServer database passwd
    'dbDriverClass', #MSSQL driver class
    'dbURL',
    'actiondbURL',
    'configToolPassword', #NetAnServer Configtool Passwd
    'netAnServerDataSource', #Default datasource template
    'logDir', #Installation log file directory
    'netanserverBranding',
    'netanserverDeploy',
    'nodeManagerDeploy',
    'netanserverGroups',
    'libraryLocation',
    'installResourcesDir',
    'customFilterDestination'
    'hostAndDomainURL'
    )
$configKeysMinorUpgrade = @(
    'administrator',
    'adminPassword'
    )
$configKeys = @(
    'spotfirebin', #location of tomcat bin dir
    'configName', #default name of configuration
    'jconnSrc', #src location of jconn diver 'C:\temp\media\jconn'
    'jconnDir', #destination in tomcat\lib
    'netAnServerIP', #DB server IP
    'dbName', #NetanServer database name
    'dbUser', #NetAnServer database user
    'dbPassword', #NetAnServer database passwd
    'dbDriverClass', #MSSQL driver class
    'dbURL',
    'actiondbURL',
    'administrator', #NetAnServer Administrator
    'adminPassword', #NetAnServer Administrator Passwd
    'configToolPassword', #NetAnServer Configtool Passwd
    'netAnServerDataSource', #Default datasource template
    'logDir', #Installation log file directory
    'netanserverBranding',
    'netanserverDeploy',
    'nodeManagerDeploy',
    'netanserverGroups',
    'libraryLocation',
    'installResourcesDir',
    'customFilterDestination'
    'hostAndDomainURL'
    )
$consumerLicenseList= @(
    '"Spotfire.Dxp.WebPlayer"',
	'"Spotfire.Dxp.Metrics"',
     '"Spotfire.Dxp.EnterprisePlayer" -f "bookmarkPanel,bookmarksPrivate,bookmarksPublic,changePassword,exportData,exportData,exportToPdf,exportToPowerPoint,print,openFromLibrary,openLinkedData,exportImage"'
    )

$global:configToolLogfile = $null
$script:PERM_CONFIG_LOGFILE = "C:\Ericsson\NetAnServer\Logs\ConfigTool.log"

### Function:  Add-NetAnServerConfig ###
#
#    Configuring the NetAnServer Server
#
#    1. Create the connection configuration needed by the server to connect to the
#       database with the bootstrap command.
#    2. Create a default configuration with the create-default-config command
#    3. Import the configuration to the database to set it active with the
#       import-config command.
#    4. Create a first user with the create-user command
#    5. Add the first user to the Administrator group with the promote-admin command
#    6. Add Data source template for JConn4
#    7. Import the configuration to the database to set it active.
#    8. Deploys the JConn jar to tomcat lib directory
#
# Arguments:
#       $map:  @{spotfirebin, configName, jconnSrc, jconnDir, netAnServerIP, dbName, dbUser,
#                   dbPassword, dbDriverClass, dbURL, administrator, adminPassword,configToolPassword
#                   netAnServerDataSource}
# Return Values:
#       [boolean]
# Throws:
#       None

Function Add-NetAnServerConfig() {
    param (
        [hashtable] $map
    )

    $logger.logInfo("Entering the default configuration of Server Component - Network Analytics Server", $True)

    $global:configToolLogfile = "$($map.logdir)\$(get-date -Format 'yyyyMMdd_HHmmss')_configTool.log"

    ###########################################################
    #   Verify all required parameters passed to Module       #
    ###########################################################
    $logger.logInfo("Verifying default configuration parameters", $True)
    $validParams = Test-MapForKeys $map $configKeys

    if($validParams[0] -eq $True) {
        $logger.logInfo($validParams[1], $True)
    } else {
        $logger.logError($MyInvocation, $validParams[1], $True)
        Exit
    }

    Import-CustomFilter $map

    ############################################################
    #   Test JCONN.jar and datasource template are avaialble   #
    ############################################################
    $isJConnDeployed = Import-JConnDriver $map
    $hasDatasourceTemplate = Test-DatasourceTemplateExists $map


    ############################################################
    #           Start Configuration Process                    #
    ############################################################
    if ($isJConnDeployed -and $hasDatasourceTemplate) {

        $isConfigured = Test-ConfigurationExists $map

        if ( -not $isConfigured ) {
            #### create bootstrap, default-config, import sybase datasource template ###
            $logger.logInfo("Configuring bootstrap and applying default configuration of Network Analytics Server", $True)
            $bootstrapConfigStages = @('bootstrap', 'create-default-config', 'modify-ds-template', 'modify-ds-template-postgres', 'set-db-config','config-csrf-protection','set-public-address','set-config-prop','set-config-prop-hsts','set-config-prop-hsts-include-sub-domains','set-config-prop-security-basic-authentication-disable','set-config-prop-jdbc-cache','set-config-prop-query-validation','set-config-prop-clear-password','set-config-prop-autoserv-timeout','set-config-prop-online-help','set-config-prop-xframe','set-config-prop-xss','set-config-prop-cache-control','set-config-prop-content-type','set-config-prop-cookies-same-site','config-action-logger','config-action-log-database-logger','set-config-prop-protocol','set-config-list-prop','set-config-prop-hsts-max-age','set-config-prop-XcontentType','set-config-prop-library-compressed-content','set-config-legal-warning')
            $isUpdated = Update-Deployment $map $bootstrapConfigStages

            if( -not $isUpdated) {
                $logger.logError($MyInvocation, "Error while creating default configuration of Network Analytics Server", $True)
                Exit
            }

            $logger.logInfo("Bootstrap and application of default configuration of Network Analytics Server complete", $True)


            ### disable the default active datasource templates ###
            $logger.logInfo("Disabling default datasource templates")
            $defaultTemplates = @('Oracle (DataDirect)', 'SQL Server (DataDirect)', 'SQL Server (2005 or newer)', 'DB2 (DataDirect)', 'MySQL (DataDirect)', 'Redshift', 'Sybase (DataDirect)')
            $templatesRemoved = Disable-AllDefaultTemplates $defaultTemplates $map

            if( -not $templatesRemoved) {
                Exit
            }

            $logger.logInfo("Default datasource templates disabled")


            ### import the created configuration ###
            $importConfig = @('import-config')
            $logger.logInfo("Importing configuration of Network Analytics Server", $True)
            $isImported = Update-Deployment $map $importConfig

            if( -not $isImported) {
                $logger.logError($MyInvocation, "Error while importing default configuration of Network Analytics Server", $True)
                Exit
            }

            $logger.logInfo("Import of Network Analytics Server configuration complete", $True)

        } else {
            $logger.logInfo("Network Analytics Server configuration found, skipping bootstrap and default configuration", $True)
        }

        ### Configuring the NetAnServer Server Deployment package ###

        $packageDeployed = Test-ServerPackageDeployed $map
        if (!$packageDeployed ) {

            $updateDeployment = @('update-deployment')
            $logger.logInfo("Network Analytics Server package deployment started", $True)
            $isDeploymentUpdated = Update-Deployment $map $updateDeployment

        }
        else {
            $logger.logInfo("Skipping server package deployment as it is already deployed", $True)
            $isDeploymentUpdated = $True
        }

        if ($isDeploymentUpdated) {
            $logger.logInfo("Network Analytics Server deployment package successfully completed",$False)

        } else {
            $logger.logError($MyInvocation, "Network Analytics Server deployment package failed", $True)
            Exit
        }

        #### Administrative User creation and promotion  ####
        $userExists = Test-UserExists $map

        if ( -not $userExists ) {
            $logger.logInfo("Creating Administrative User $($map.administrator) for Network Analytics Server", $True)
            $userConfigStages = @('create-user', 'promote-admin', 'promote-scheduledUpdateUser', 'promote-automationServicesUser', 'add-automationServicesUserToLibraryAdmin', 'add-adminUserToLibraryAdmin','add-adminUserToScriptAuthor','add-adminUserToAutomationServices')
            $isUpdated = Update-Deployment $map $userConfigStages
        } else {
            $logger.logInfo("Skipping user creation $($map.administrator) user already exists", $True)
            $isUpdated = $True
        }

                #### Group creation   ####
        $groupExists = Test-GroupExists $map

        if ( -not $groupExists ) {
            $logger.logInfo("Creating Groups for Network Analytics Server", $True)
            $groupConfigStages = @('import-consumergroup')
            $isUpdated = Update-Deployment $map $groupConfigStages
        } else {
            $logger.logInfo("Skipping group creation as groups already exists", $True)
            $isUpdated = $True
        }
                #### Set Group License   ####

        $groupExists = Test-GroupExists $map
        if ($groupExists) {
            $logger.logInfo("Configure Consumer group on Network Analytics Server", $True)
            $licenseConfigStages = @('set-license')
            $groupName='Consumer'
            $isUpdated = Update-License $map $licenseConfigStages $consumerLicenseList $groupName
        } else {
            $logger.logInfo("Consumer group Configuration failed for Network Analytics Server", $True)
            $isUpdated = $False
        }
        if ($isUpdated) {
            $logger.logInfo("Configuration of Network Analytics Server successfully completed")
            return $True
        } else {
            $logger.logError($MyInvocation, "Configuration of Network Analytics Server failed", $True)
            Exit
        }

    } else {
        $errorMessage = "Configuration of Network Analytic Server failed
            please verify that jconn4 driver is in correct location."
        $logger.logError($MyInvocation, $errorMessage, $True)
        Exit
    }
}
### Function:  Add-NetAnServerConfigUpgrade ###
#
#    Configuring the NetAnServer Server for Upgrade
#
#    8. Deploys the JConn jar to tomcat lib directory
#
# Arguments:
#       $map:  @{spotfirebin, configName, jconnSrc, jconnDir, netAnServerIP, dbName, dbUser,
#                   dbPassword, dbDriverClass, dbURL,configToolPassword
#                   netAnServerDataSource}
# Return Values:
#       [boolean]
# Throws:
#       None

Function Add-NetAnServerConfigUpgrade() {
    param (
        [hashtable] $map
    )

    $logger.logInfo("Entering the default configuration of Server Component - Network Analytics Server", $True)
    $global:configToolLogfile = "$($map.logdir)\$(get-date -Format 'yyyyMMdd_HHmmss')_configTool.log"
    ###########################################################
    #   Verify all required parameters passed to Module       #
    ###########################################################
    $logger.logInfo("Verifying default configuration parameters", $True)
    $validParams = Test-MapForKeys $map $configKeysUpgrade

    if($validParams[0] -eq $True) {
        $logger.logInfo($validParams[1], $True)
    } else {
        $logger.logError($MyInvocation, $validParams[1], $True)
        Exit
    }

    Import-CustomFilter $map

    if (Test-path("C:\Ericsson\NetAnServer\Server\7.11\jdk\jre\lib\security\spotfire.keytab")) {

        Copy-Item -Path "C:\Ericsson\NetAnServer\Server\7.11\jdk\jre\lib\security\spotfire.keytab" -Destination "C:\Ericsson\NetAnServer\Server\$($map.currentPlatformVersion)\tomcat\spotfire-bin" -Recurse -Force
    }

    if (Test-path("C:\Ericsson\NetAnServer\Server\7.11\jdk\jre\lib\security\krb5.conf")) {

        Copy-Item -Path "C:\Ericsson\NetAnServer\Server\7.11\jdk\jre\lib\security\krb5.conf" -Destination "C:\Ericsson\NetAnServer\Server\$($map.currentPlatformVersion)\tomcat\spotfire-bin" -Recurse -Force
    }

    if (Test-path("C:\Ericsson\NetAnServer\Server\$($map.previousPlatformVersion)\tomcat\spotfire-bin\spotfire.keytab")) {

        Copy-Item -Path "C:\Ericsson\NetAnServer\Server\$($map.previousPlatformVersion)\tomcat\spotfire-bin\spotfire.keytab" -Destination "C:\Ericsson\NetAnServer\Server\$($map.currentPlatformVersion)\tomcat\spotfire-bin" -Recurse -Force
    }

    if (Test-path("C:\Ericsson\NetAnServer\Server\$($map.previousPlatformVersion)\tomcat\spotfire-bin\krb5.conf")) {

        Copy-Item -Path "C:\Ericsson\NetAnServer\Server\7.11\jdk\jre\lib\security\krb5.conf" -Destination "C:\Ericsson\NetAnServer\Server\$($map.currentPlatformVersion)\tomcat\spotfire-bin" -Recurse -Force
    }


    ############################################################
    #   Test JCONN.jar and datasource template are avaialble   #
    ############################################################
    $isJConnDeployed = Import-JConnDriver $map

    ############################################################
    #           Start Configuration Process                    #
    ############################################################

    ### Modifying datasource template ###
    $datasourcemodifStages = @('export-config', 'modify-ds-template', 'modify-ds-template-postgres', 'enable-user','config-csrf-protection','set-public-address','set-config-prop','set-config-prop-hsts','set-config-prop-jdbc-cache','set-config-prop-query-validation','set-config-prop-clear-password','set-config-prop-autoserv-timeout','set-config-prop-online-help','set-config-prop-xframe','set-config-prop-xss','set-config-prop-cache-control','set-config-prop-content-type','config-action-logger','set-config-prop-cookies-same-site','config-action-log-database-logger','set-config-prop-protocol','set-config-list-prop','set-config-prop-hsts-max-age','set-config-prop-hsts-include-sub-domains','set-config-prop-security-basic-authentication-disable','set-config-prop-library-compressed-content','set-config-prop-XcontentType','set-config-legal-warning','updateCustomLibrary')

    if (Test-path("C:\Ericsson\NetAnServer\Server\$($map.currentPlatformVersion)\tomcat\spotfire-bin\spotfire.keytab")) {
            $datasourcemodifStages += @('config-kerberos-auth')
    }
            $datasourcemodifStages += @('import-config')
            $Updated = Update-Deployment $map $datasourcemodifStages

            if ( -not $Updated) {
                $logger.logError($MyInvocation, "Error while modifying datasourcetemplate", $True)
                Exit
                                }
            $logger.logInfo("DataSource-template modification complete", $True)

    if ($isJConnDeployed) {

        ### Configuring the NetAnServer Server Deployment package ###
            $updateDeployment = @('update-deployment')
            $logger.logInfo("Network Analytics Server package deployment started", $True)
            $isDeploymentUpdated = Update-Deployment $map $updateDeployment
        if ($isDeploymentUpdated) {
            $logger.logInfo("Network Analytics Server deployment package successfully completed",$False)

        } else {
            $logger.logError($MyInvocation, "Network Analytics Server deployment package failed", $True)
            Exit
        }


     } else {
        $errorMessage = "Configuration of Network Analytic Server failed
            please verify that jconn4 driver is in correct location."
        $logger.logError($MyInvocation, $errorMessage, $True)
        Exit
    }
     #### Administrative User creation and promotion  ####
    $userExists = Test-UserExists $map

    if ( -not $userExists ) {
        $logger.logInfo("Creating Administrative User $($map.administrator) for Network Analytics Server", $True)
        $userConfigStages = @('create-user', 'promote-admin', 'promote-scheduledUpdateUser', 'promote-automationServicesUser', 'add-automationServicesUserToLibraryAdmin', 'add-adminUserToLibraryAdmin','add-adminUserToScriptAuthor', 'add-adminUserToAutomationServices')
        $isUpdated = Update-Deployment $map $userConfigStages
    } else {
        $userConfigStages = @('promote-admin', 'promote-scheduledUpdateUser', 'promote-automationServicesUser', 'add-automationServicesUserToLibraryAdmin', 'add-adminUserToLibraryAdmin', 'add-adminUserToScriptAuthor','add-adminUserToAutomationServices')
        $isUpdated = Update-Deployment $map $userConfigStages
        $logger.logInfo("Skipping user creation $($map.administrator) user already exists", $True)
        $isUpdated = $True
    }
    if ($isUpdated) {
            $logger.logInfo("Configuration of Network Analytics Server successfully completed")
            return $True
        } else {
            $logger.logError($MyInvocation, "Configuration of Network Analytics Server failed", $True)
            Exit
        }
}
### Function:  Add-NetAnServerConfigMinorUpgrade ###
#
#    Configuring the NetAnServer Server for Upgrade
# Arguments:
#       $map:  @{spotfirebin, configName, jconnSrc, jconnDir, netAnServerIP, dbName, dbUser,
#                   dbPassword, dbDriverClass, dbURL,configToolPassword
#                   netAnServerDataSource}
# Return Values:
#       [boolean]
# Throws:
#       None

Function Add-NetAnServerConfigMinorUpgrade() {
    param (
        [hashtable] $map
    )
    $logger.logInfo("Entering the default configuration of Server Component - Network Analytics Server", $True)
    $global:configToolLogfile = "$($map.logdir)\$(get-date -Format 'yyyyMMdd_HHmmss')_configTool.log"
    ###########################################################
    #   Verify all required parameters passed to Module       #
    ###########################################################
    $logger.logInfo("Verifying default configuration parameters", $True)
    $validParams = Test-MapForKeys $map $configKeysUpgrade

    if($validParams[0] -eq $True) {
        $logger.logInfo($validParams[1], $True)
    } else {
        $logger.logError($MyInvocation, $validParams[1], $True)
        Exit
    }
	Import-CustomFilter $map

     #### Administrative User creation and promotion  ####
    $userExists = Test-UserExists $map

    if ( -not $userExists ) {
        $logger.logInfo("Creating Administrative User $($map.administrator) for Network Analytics Server", $True)
        $userConfigStages = @('create-user', 'promote-admin', 'promote-scheduledUpdateUser', 'promote-automationServicesUser', 'add-automationServicesUserToLibraryAdmin', 'add-adminUserToLibraryAdmin','add-adminUserToScriptAuthor', 'add-adminUserToAutomationServices')
        $isUpdated = Update-Deployment $map $userConfigStages
    } else {
        $userConfigStages = @('promote-admin', 'promote-scheduledUpdateUser', 'promote-automationServicesUser', 'add-automationServicesUserToLibraryAdmin', 'add-adminUserToLibraryAdmin', 'add-adminUserToScriptAuthor','add-adminUserToAutomationServices')
        $isUpdated = Update-Deployment $map $userConfigStages
        $isUpdated = $True
    }
    if ($isUpdated) {
        $logger.logInfo("Configuration of Network Analytics Server successfully completed")
        return $True
    } else {
        $logger.logError($MyInvocation, "Configuration of Network Analytics Server failed", $True)
        Exit
    }
}

### Function:  Import-JConnDriver ###
#
#    Imports the jConn folder from jConnSrc directory (user provided)
#    to the tomcat lib directory
#
# Arguments:
#       [hashtable] $map
# Return Values:
#       [boolean]
# Throws: None
#
Function Import-JConnDriver() {
    param (
        [hashtable] $map
    )

    $logger.logInfo("Starting deployment of jconn4 driver", $True)

    if (Test-FileExists($map.jConnDir + "\jconn-4.jar")) {
        $logger.logInfo("Driver already found in " + $map.jConnDir + " directory.")
        return $True
    }


    $logger.logInfo("Testing if driver is in required directory "+ $map.jConnSrc)

    if (Test-FileExists($map.jConnSrc)) {
        try {
            $logger.logInfo("Deploying jconn4 driver to " + $map.jconnDir)
            Copy-Item $map.jconnSrc $map.jconnDir -ErrorAction Stop -Force
            $logger.logInfo("Successfully deployed jConn4 driver", $True)
            return $True
        } catch {
            $errorMessage = $_.Exception.Message
            $logger.logError($MyInvocation, "Error deploying jConn4 driver " + $map.jconnSrc + 
                " to directory " + $map.jconnDir + ". `n$errorMessage`n Exiting", $True)
            return $False
        }
    } else {
        $logger.logError($MyInvocation, "JConn4 Driver could not be found $($map.jConnSrc). Exiting.", $True) 
        return $False
    }

}
### Function:  Import-CustomFilter ###
#
#    Imports the Custom Filter folder from installResourcesDir directory
#    to ..Ericsson\NetAnServer\Server\version\tomcat\webapps\spotfire\WEB-INF\lib directory
#
# Arguments:
#       [hashtable] $map
# Return Values:
#       [boolean]
# Throws: None
#
Function Import-CustomFilter() {
    param (
        [hashtable] $map
    )
##error
    $logger.logInfo("Starting deployment of custom filter", $True)

    $logger.logInfo("Testing if driver is in required directory "+ $map.installResourcesDir + "\CustomAuthentication.jar")

    if (Test-FileExists($map.installResourcesDir + "\CustomAuthentication.jar")){
        try {
            $logger.logInfo("Deploying CustomAuthentication.jar to " + $map.customFilterDestination)
            $AuthSourceDir=$map.installResourcesDir + "\CustomAuthentication.jar"
            Copy-Item $AuthSourceDir -Destination $map.customFilterDestination -ErrorAction Stop -Force
            $logger.logInfo("Successfully transferred CustomAuthentication jar", $True)
            return $True
        } catch {
            $errorMessage = $_.Exception.Message
            $logger.logError($MyInvocation, "Error transferring CustomAuthentication jar from: " + $map.installResourcesDir +
                " to directory " + $map.customFilterDestination + ". `n$errorMessage`n Exiting", $True)
            return $False
        }
    } else {
        $logger.logError($MyInvocation, "CustomAuthentication.jar could not be found $($map.installResourcesDir). Exiting.", $True)
        return $False
    }

}

### Function:  Test-DatasourceTemplateExists ###
#
#    Tests if the required datasource_template.xml exists
#
# Arguments:
#       [hashtable] $map
# Return Values:
#       [boolean]
# Throws: None
#
Function Test-DatasourceTemplateExists() {
    param (
        [hashtable] $map
        )
    $logger.logInfo("Checking for presence of datasource template $($map.netAnServerDataSource)")
    if ( -not (Test-FileExists "$($map.netAnServerDataSource)") ) {
        $message = "Could not find the datasource template $($map.netAnServerDataSource).`n Exiting Configuration."
        $logger.logError($MyInvocation, $message, $True)
        return $False
    } else {
        $logger.logInfo("Datasource template found.")
        return $True
    }
}


### Function:  Test-ServerPackageDeployed ###
#
#    Tests if Network Analytic Server package deployment exists
#
# Arguments:
#       [hashtable] $map 
# Return Values:
#       [boolean]
# Throws: None
#

Function Test-ServerPackageDeployed {
    param(
        [hashtable] $map
    )

    $logger.logInfo("Checking if Network Analytics Server deployment package is already deployed ", $True)
    $command = "show-deployment --tool-password=$($map.configToolPassword)"

    $processinfo = New-Object System.Diagnostics.ProcessStartInfo
    $processinfo.FileName = $map.configTool
    $processinfo.RedirectStandardError = $true
    $processinfo.RedirectStandardOutput = $true
    $processinfo.UseShellExecute = $false
    $processinfo.Arguments = $command
    $processCmd = New-Object System.Diagnostics.Process
    $processCmd.StartInfo = $processinfo
    $processCmd.Start() | Out-Null
    $processOutput = $processCmd.StandardOutput.ReadToEnd()

    if ($processOutput -match 'empty') {
        $logger.logInfo("Network Analytics Server deployment package is empty", $True)
        return $False
    } else  {
        $logger.logInfo("Network Analytics Server deployment package is already deployed ", $True)
        return $True
    }

}

### Function:  Update-Deployment ###
#
#    Get the required argument string for the required stage.
#    e.g. create-user. It then executes the config.bat Tibco
#    utility with the returned arguments.
#
# Arguments:
#       [hashtable] $map,
#       [string] $stage
# Return Values:
#       [boolean]
# Throws: None
#
Function Update-Deployment() {
    param (
        [hashtable] $map,
        [array] $stages
    )

    foreach ($stage in $stages) {
        if ($stage) {
            $arguments = Get-Arguments $stage $map
            $logger.logInfo("Executing Stage $stage", $true)

            $successful = Use-ConfigTool $arguments $map $global:configToolLogfile

            if ($successful) {
                $logger.logInfo("Stage $stage executed successfully", $true)
                continue
            } else {
                $logger.logError($MyInvocation, "Error while executing Stage $stage", $True)
                return $False
            }
        }
    }
    return $True
}
### Function:  Update-License ###
#
#    Get the required argument string for the required stage.
#    e.g. set-license. It then executes the config.bat Tibco
#    utility with the returned arguments.
#
# Arguments:
#       [hashtable] $map,
#       [string] $stage,
#        [array] $licenseList
# Return Values:
#       [boolean]
# Throws: None
#
Function Update-License() {
    param (
        [hashtable] $map,
        [string] $stage,
        [array] $licenseList,
        [string] $groupName
    )

    foreach ($license in $licenseList) {
        if ($license) {
            $arguments = Get-Arguments $stage $map $license $groupName
            $logger.logInfo("Executing Stage $stage", $false)
            $successful = Use-ConfigTool $arguments $map $global:configToolLogfile

            if ($successful) {
                $logger.logInfo("Stage $stage executed successfully", $false)
                continue
            } else {
                $logger.logError($MyInvocation, "Error while executing Stage $stage", $True)
                return $False
            }
        }
    }
    return $True
}

### Function:  Test-ConfigurationExists ###
#
#    Tests if the Network Analytics Server configuration already exists
#
# Arguments:
#       [hashtable] $map
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Test-ConfigurationExists() {
    param (
        [hashtable] $map
    )

    $selectQuery = "select * from config_history where config_comment like `'" + $map.configName + "`'"
    $logger.logInfo("Testing if configuration ""$($map.configName)"" exists.", $True)

    $response = Invoke-SqlQuery $map $selectQuery
	
    if ($response[1].config_comment -match $map.configName) {
        $logger.logInfo("Configuration found with name: " + $response[1].config_comment, $True)
        return $True
    } else {
        $logger.logInfo("No Server Configuration detected.", $True)
        return $False
    }
}

### Function:  Test-UserExists ###
#
#    Tests if the Network Analytics Server Administrator User already exists
#
# Arguments:
#       [hashtable] $map
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Test-UserExists() {
    param (
        [hashtable] $map
    )

    $selectQuery = "select * from users where upper(user_name) like upper(`'" +  $($map.administrator) + "`')"
    $logger.logInfo("Testing if user $($map.administrator) exists.", $True)

    $response = Invoke-SqlQuery $map $selectQuery
	
    if ($response[1].user_name -match $map.administrator ) {
       $logger.logInfo("User found with name: " + $response[1].user_name, $True)
        return $True
    } else {
        $logger.logInfo("No User with name $($map.administrator) detected.", $True)
        return $False
   }
}

### Function:  Test-GroupExists ###
#
#    Tests if the Network Analytics Server Groups already exists
#     This function will return false if any of the group doesn't exists and import-groups will "only" create groups which doesn't exist. 
#
# Arguments:
#       [hashtable] $map
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Test-GroupExists() {
    param (
        [hashtable] $map
    )
    
    $selectQuery = "select * from groups where group_name like `'Consumer`'"
    $logger.logInfo("Testing if Consumer Group for Network Analytics Server exists.", $False)
    $response = Invoke-SqlQuery $map $selectQuery
   if ($response[1].group_name -match 'Consumer' ) {
        $logger.logInfo("Group found with name: " + $response[1].group_name, $False)
   } else {
       $logger.logInfo("No Group with name Consumer detected.", $False)
        return $False
    }
    return $True
}

### Function:  Invoke-SqlQuery ###
#
#    Delegator Function for Invoke-SqlCmd
#    Executes the SQL statement. If error exits the script.
#
# Arguments:
#       [hashtable] $map,
#       [string] $statement
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Invoke-SqlQuery() {
    param (
        [hashtable] $map,
        [string] $statement
    )

    try {
        $SQL_TIMEOUT = 60
        $selectQuery = $statement
        $logger.logInfo("Connecting to PostgreSQL DB server:  $($map.Item('netAnServerIP'))")
        $logger.logInfo("Connecting to PostgreSQL Database :  $($map.Item('dbName'))")
        $logger.logInfo("Sending Query :  `n$selectQuery")
        $loc = Get-Location
        $response = Invoke-UtilitiesSQL -Database $map.Item('dbName') -Username $map.Item('dbUser') -Password $map.Item('dbPassword') -ServerInstance "$($map.Item('netAnServerIP'))" -Query $selectQuery -Action fetch
		
        Set-Location $loc
        return $response

    } catch {
        Set-Location $loc
        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Error executing sql cmd`n $errorMessage. `nExiting", $True)
        Exit -1
    }
}

### Function:  Use-ConfigTool ###
#
#   Executes a command with the config.bat utility.
#   Requires a single string command with all the config.bat
#   arguments correctly formed and a map containing the location
#   of the config.bat utility.
#
# Arguments:
#       [string] $command
#       [hashtable] $map
#       [string] $logfile
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Use-ConfigTool() {
    param(
        [string] $command,
        [hashtable] $map,
        [string] $logFile = $null
    )

    #location setting as config.bat creates file in bin directory

    $loc = Get-Location
    Set-Location $($map.spotfirebin)

    $configTool = $map.spotfirebin + "config.bat"
    $logger.logInfo("Starting $configTool process")

    try {
        if ($logFile) {
            $cfgProcess = Start-Process $configTool -ArgumentList $command -Wait -PassThru -NoNewWindow -RedirectStandardOutput $logFile
            cat $logFile >> $script:PERM_CONFIG_LOGFILE -ea SilentlyContinue
            rm $logFile -ea SilentlyContinue
        } else {
            $cfgProcess = Start-Process $configTool -ArgumentList $command -Wait -PassThru -NoNewWindow
        }
    } catch {
        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Exception while starting $configTool process `n $errorMessage", $True)
    } finally {
        Set-Location $loc
    }


    #cannot log arguments - contains passwords
    if ( -not ($cfgProcess.ExitCode -eq 0)) {
        $logger.logError($MyInvocation, "Configuration Command Failed: Exited with code " + $cfgProcess.ExitCode, $True)
        return $False
    } else {
        $logger.logInfo("Configuration Command Successful: Exit Code " + $cfgProcess.ExitCode)
        return $True
    }
}

### Function:  Get-Arguments ###
#
#   Function returns the required [string] arguments for 
#   the config.bat utility where the key is the command type.
#   e.g. create-user. Returns null if key is not found.
#
# Arguments:
#       [string] $key,
#       [hashtable] $map
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Get-Arguments() {
    param(
      [Parameter(Mandatory=$true)] [string] $key, 
      [Parameter(Mandatory=$true)] [hashtable] $map,
      [string] $licensename = $null,
      [string] $groupName = $null
  )

  $configArgs = Switch ($key) {

        bootstrap {
            $logger.logInfo("Using Arguments: bootstrap -n -c $($map.dbDriverClass) " +
                "-d $($map.dbURL) -u $($map.dbUser) -p ******* -t ********")
            return "bootstrap -f -n -c $($map.dbDriverClass) -d $($map.dbURL) -u $($map.dbUser) -p $($map.dbPassword) -t $($map.configToolPassword)"
        }

        create-default-config {
            $logger.logInfo("Using Arguments: 'create-default-config -f'")
            return "create-default-config -f"
        }

        config-csrf-protection{
            $logger.logInfo("Using Arguments: 'config-csrf-protection --enabled=false'")
            return "config-csrf-protection --enabled=false"
        }

        set-public-address{
            $logger.logInfo("Using Arguments: 'set-public-address -t ********** -u $($map.hostAndDomainURL)'")
            return "set-public-address -t $($map.configToolPassword) -u `"$($map.hostAndDomainURL)`""
        }
        set-config-prop{
            $logger.logInfo("Using Arguments: 'set-config-prop ---name=security.trust.auto-trust.enabled --value=true'")
            return "set-config-prop --name=security.trust.auto-trust.enabled --value=true"
        }
        set-config-prop-protocol{
            $logger.logInfo("Using Arguments: 'set-config-prop --name=security.trust.enabled-tls-protocols.enabled-tls-protocol --value=TLSv1.2'")
            return "set-config-prop --name=security.trust.enabled-tls-protocols.enabled-tls-protocol --value=TLSv1.2"
        }
        set-config-list-prop{
            $logger.logInfo("Using Arguments: 'set-config-list-prop --name=security.trust.enabled-tls-cipher-suites --item-name=enabled-tls-cipher-suite -VTLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 -VTLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 -VTLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 -VTLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'")
            return "set-config-list-prop --name=security.trust.enabled-tls-cipher-suites --item-name=enabled-tls-cipher-suite -VTLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 -VTLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 -VTLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 -VTLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
        }
		set-config-prop-hsts{
            $logger.logInfo("Using Arguments: 'set-config-prop -n security.hsts.enabled -v true'")
            return "set-config-prop -n security.hsts.enabled -v true"
        }
        set-config-prop-hsts-max-age{
            $logger.logInfo("Using Arguments: 'set-config-prop -n security.hsts.max-age-seconds -v 31536000'")
            return "set-config-prop -n security.hsts.max-age-seconds -v 31536000"
        }
		set-config-prop-hsts-include-sub-domains{
            $logger.logInfo("Using Arguments: 'set-config-prop -n security.hsts.include-sub-domains -v true'")
            return "set-config-prop -n security.hsts.include-sub-domains -v true"
        }
        set-config-prop-security-basic-authentication-disable{
            $logger.logInfo("Using Arguments: 'set-config-prop -n security.basic.basic-disabled -v true'")
            return "set-config-prop -n security.basic.basic-disabled -v true"
        }
		set-config-prop-library-compressed-content{
            $logger.logInfo("Using Arguments: 'set-config-prop -n library.compressed-content.enabled -v false'")
            return "set-config-prop -n library.compressed-content.enabled -v false"
        }
		set-config-prop-XcontentType{
            $logger.logInfo("Using Arguments: 'set-config-prop -n security.x-content-type-options.enabled -v false'")
            return "set-config-prop -n security.x-content-type-options.enabled -v false"
        }
		set-config-legal-warning{
            $logger.logInfo("Using Arguments: 'config-login-dialog -s always -R `"/spotfire/Important_Legal_Notice.xml`"'")
            return "config-login-dialog -s always -R `"/spotfire/Important_Legal_Notice.xml`""
        }
		updateCustomLibrary{
            $logger.logInfo("Using Arguments: 'find-analysis-scripts -t ******** -d true -s true -q true -n --library-parent-path=`"/Custom Library/`"'")
			return "find-analysis-scripts -t $($map.configToolPassword) -d true -s true -q true -n --library-parent-path=`"/Custom Library/`""
        }
		set-config-prop-jdbc-cache{
            $logger.logInfo("Using Arguments: 'set-config-prop --name=information-services.jdbc.cache-lifetime-seconds --value=60'")
            return "set-config-prop --name=information-services.jdbc.cache-lifetime-seconds --value=60"
        }
		set-config-prop-query-validation{
            $logger.logInfo("Using Arguments: 'set-config-prop --name=information-services.runtime-query-validation --value=False'")
            return "set-config-prop --name=information-services.runtime-query-validation --value=False"
        }
		set-config-prop-clear-password{
            $logger.logInfo("Using Arguments: 'set-config-prop --name=clear-data-source-passwords-on-export --value=False'")
            return "set-config-prop --name=clear-data-source-passwords-on-export --value=False"
        }
		set-config-prop-autoserv-timeout{
            $logger.logInfo("Using Arguments: 'set-config-prop --name=automation-services.job-inactivity-timeout --value=28800'")
            return "set-config-prop --name=automation-services.job-inactivity-timeout --value=28800"
        }
		set-config-prop-online-help{
            $logger.logInfo("Using Arguments: 'set-config-prop -n general.applications.admin.use-online-help -v false'")
            return "set-config-prop -n general.applications.admin.use-online-help -v false"
        }
		set-config-prop-xframe{
            $logger.logInfo("Using Arguments: 'set-config-prop -n security.x-frame-options.enabled -v true'")
            return "set-config-prop -n security.x-frame-options.enabled -v true"
        }
		set-config-prop-xss{
            $logger.logInfo("Using Arguments: 'set-config-prop -n security.x-xss-protection.enabled -v true'")
            return "set-config-prop -n security.x-xss-protection.enabled -v true"
        }
		set-config-prop-cache-control{
            $logger.logInfo("Using Arguments: 'set-config-prop -n security.cache-control.enabled -v true'")
            return "set-config-prop -n security.cache-control.enabled -v true"
        }
		set-config-prop-content-type{
            $logger.logInfo("Using Arguments: 'set-config-prop -n security.x-content-type-options.enabled -v true'")
            return "set-config-prop -n security.x-content-type-options.enabled -v true"
        }
		config-action-logger{
            $logger.logInfo("Using Arguments: 'config-action-logger --file-logging-enabled=false --database-logging-enabled=true'")
            return "config-action-logger --file-logging-enabled=false --database-logging-enabled=true"
		}
        config-action-log-database-logger{
            $logger.logInfo("Using Arguments: 'config-action-log-database-logger'")
            return "config-action-log-database-logger --database-url=$($map.actiondbURL) --driver-class=$($map.dbDriverClass) -u $($map.dbUser) -p $($map.dbPassword) --log-local-time=true --pruning-period=168"
        }
        
        set-config-prop-cookies-same-site{
            $logger.logInfo("Using Arguments: 'config set-config-prop --name=security.cookies.same-site --value=Lax'")
            return "set-config-prop --name=security.cookies.same-site --value=Lax"
        }

        import-config {
            $logger.logInfo("Using Arguments: 'import-config -t ******** -c $($map.configName)'")
            return "import-config -t $($map.configToolPassword) -c `"$($map.configName)`""
        }


      #This is for creating platform admin user
        create-user {
            $logger.logInfo("Using Arguments: create-user -t ******* -u $($map.administrator) -p *******")
            return "create-user -t $($map.configToolPassword) -u $($map.administrator) -p $($map.adminPassword)"
        }

        promote-admin {
            $logger.logInfo("Using Arguments: promote-admin -t ******* -u $($map.administrator)")
            return "promote-admin -t $($map.configToolPassword) -u $($map.administrator)"
        }

        promote-scheduledUpdateUser {
            $logger.logInfo("Using Arguments: promote-admin -t ******* -u $($map.scheduledUpdateUser)")
            return "promote-admin -t $($map.configToolPassword) -u $($map.scheduledUpdateUser)"
        }

        promote-automationServicesUser {
            $logger.logInfo("Using Arguments: promote-admin -t ******* -u $($map.automationServicesUser)")
            return "promote-admin -t $($map.configToolPassword) -u $($map.automationServicesUser)"
        }

        add-automationServicesUserToLibraryAdmin {
            $logger.logInfo("Using Arguments: add-member -t ******** -g `"$($map.groupLibName)`"  -u $($map.automationServicesUser)")
            return "add-member -t $($map.configToolPassword) -g `"$($map.groupLibName)`"  -u $($map.automationServicesUser)"
        }

        add-adminUserToLibraryAdmin {
            $logger.logInfo("Using Arguments: add-member -t ******** -g `"$($map.groupLibName)`"   -u $($map.administrator)")
            return "add-member -t $($map.configToolPassword) -g `"$($map.groupLibName)`"   -u $($map.administrator)"
        }
        add-adminUserToScriptAuthor {
            $logger.logInfo("Using Arguments: add-member -t ******** -g `"$($map.groupSAName)`"   -u $($map.administrator)")
            return "add-member -t $($map.configToolPassword) -g `"$($map.groupSAName)`"   -u $($map.administrator)"
        }

        add-adminUserToAutomationServices {
            $logger.logInfo("Using Arguments: add-member -t ******** -g `"$($map.groupAutoServiceName)`"   -u $($map.administrator)")
            return "add-member -t $($map.configToolPassword) -g `"$($map.groupAutoServiceName)`"   -u $($map.administrator)"
        }

        modify-ds-template {
            $logger.logInfo("Using Arguments: modify-ds-template -n Sybase -e true -d $($map.netAnServerDataSource)")
            return "modify-ds-template -n Sybase -e true -d $($map.netAnServerDataSource)"
        }
		modify-ds-template-postgres {
			$logger.logInfo("Using Arguments: modify-ds-template -n PostgreSQL -e true")
            return "modify-ds-template -n PostgreSQL -e true"
		}
        import-groups {
            $logger.logInfo("Using Arguments: import-groups -t ******* -m true $($map.netanserverGroups)")
            return "import-groups -t $($map.configToolPassword) -m true $($map.netanserverGroups)"
        }
        import-consumergroup {
            $logger.logInfo("Using Arguments: import-groups -t *******  $($map.netanserverGroups)")
            return "import-groups -t $($map.configToolPassword)  $($map.netanserverGroups)"
        }
        set-license {
            $logger.logInfo("Using Arguments: set-license -t *******  -g `"$groupName`" -l $($licensename)")
            return "set-license -t $($map.configToolPassword)  -g `"$groupName`" -l $($licensename)"
        }
        update-deployment {
			$global:hotfixfiles = New-Object System.Collections.Generic.List[string]
			$spkFileInfo = Get-ChildItem $map.hotfixDir -Filter *.spk
			if($spkFileInfo.count -gt 0)
			{
				foreach($file in Get-ChildItem $map.hotfixDir -Filter *.spk){
					$hotfixfiles.add($map.hotfixDir+"\"+$file.name)
				}
			}
			$sdnFileInfo = Get-ChildItem $map.hotfixDir -Filter *.sdn
			if($sdnFileInfo.count -gt 0)
			{
				foreach($file in Get-ChildItem $map.hotfixDir -Filter *.sdn){
					$hotfixfiles.add($map.hotfixDir+"\"+$file.name)
				}
			}
			if($hotfixfiles.count -eq 0) {
				$logger.logInfo("No Hotfix Files Found")
				$allpackages=  $($map.netanserverDeploy)+","+$($map.netanserverBranding)+","+$($map.nodeManagerDeploy)+","+$($map.pythonDeploy)+","+$($map.TERRDeploy)#Added python & TERR deployment
			}
			else {
				$hotfixpackages = ($hotfixfiles -join ",")
				$logger.logInfo("GeneralHotfix(s) found :: $($hotfixpackages)")
				$allpackages=  $($map.netanserverDeploy)+","+$($map.netanserverBranding)+","+$($map.nodeManagerDeploy)+","+$($map.pythonDeploy)+","+$($map.TERRDeploy)+","+$($hotfixpackages)## Added Hotfix extra
			}
			$selectQuery = "select * from dep_packages where name like 'NetAnServerLegalBranding'"
			$logger.logInfo("Testing if NetAnServerLegalBranding package exists.", $True)
			
			$response = Invoke-SqlQuery $map $selectQuery
			
			if ($response[1].name -match 'NetAnServerLegalBranding') {
				$logger.logInfo("NetAnServerLegalBranding package exists.", $True)
				$removeid = $response[1].serie_id
				
				$logger.logInfo("Using Arguments: update-deployment -t ******** --remove-packages=******** -a Production $allpackages")
				return "update-deployment -t $($map.configToolPassword) --remove-packages=$removeid -a Production $allpackages"
			} else {
				$logger.logInfo("NetAnServerLegalBranding package not found.", $True)
				$logger.logInfo("Using Arguments: update-deployment -t ******** -a Production $allpackages")
				return "update-deployment -t $($map.configToolPassword) -a Production $allpackages"
			}
		}
        import-library-content {
            $logger.logInfo("Using Arguments: import-library-content -t ******** -p $($map.libraryLocation) -m KEEP_NEW -u $($map.administrator)")
            return "import-library-content -t $($map.configToolPassword) -p $($map.libraryLocation) -m KEEP_NEW -u $($map.administrator)"
        }
        add-member{
            $logger.logInfo("Using Arguments: add-member -t ******** -g $($map.groupname) -u $($map.username)")
            return "add-member -t $($map.configToolPassword) -g `"$($map.groupname)`" -u $($map.username)"
        }

        delete-user{
            $logger.logInfo("Using Arguments: delete-user -t ******** -u $($map.username)")
            return "delete-user -t $($map.configToolPassword) -u $($map.username)"
        }

        enable-user{
            $logger.logInfo("Using Arguments: enable-user -t ******** -a ")
            return "enable-user -t $($map.configToolPassword) -a "
        }

        config-kerberos-auth{
            $logger.logInfo("Using Arguments: config-kerberos-auth -t ******** -p $($map.spn) ")
            return "config-kerberos-auth -k $($map.keytabfile) -p $($map.spn) "
        }
        #This is for creating generic user
        create-genericuser {
            $logger.logInfo("Using Arguments: create-user -t ******* -u $($map.username) -p *******")
            return "create-user -t $($map.configToolPassword) -u $($map.username) -p $($map.userPassword)"
        }
        trust-node {
            $logger.logInfo("Using Arguments: trust-node -t ******* --id ******")
            return "trust-node -t $($map.configToolPassword) --id "
        }
        delete-node {
            $logger.logInfo("Using Arguments: delete-node -t ******* -i ******")
            return "delete-node -t $($map.configToolPassword) -i "
        }
        set-user-password{
            $logger.logInfo("Using Arguments: set-user-password -t ******** -u $($map.username) -p ********")
            return "set-user-password -t $($map.configToolPassword) -u $($map.username) --password=""$($map.userPassword)"""  
        }
        export-config {
            $logger.logInfo("Using Arguments: 'export-config -f -t ********")
            return "export-config -f -t $($map.configToolPassword)"
        }
        import-DBConnPool {
            $logger.logInfo("Using Arguments: 'import-config  -c max-connections -t *******'")
            return "import-config  -c `"max-connections`" -t $($map.configToolPassword)"
        }
        set-db-config {
            $logger.logInfo("Using Arguments: set-db-config -a 56")
            return "set-db-config -a 56"
        }
        default {
            $logger.logWarning("No argument available for $key")
            $null
        }
  }
  return $configArgs
}


### Function:  Disable-AllDefaultTemplates ###
#
#   Function iterates array of template names to disable
#
# Arguments:
#       [array] $templates,
#       [hashtable] $map
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Disable-AllDefaultTemplates() {
  param(
      [array] $templates,
      [hashtable] $map
  )

  foreach ($template in $templates) {
      $logger.logInfo("Disabling datasource template $template")
      $disabled = Disable-DataSourceTemplate $template $map

      if($disabled) {
          $logger.logInfo("Datasource template $template disabled")
          continue
      } else {
          $logger.logError($MyInvocation, "Disabling datasource template $template failed", $True)
          return $False
      }
  }

  return $True
}


### Function:  Disable-DataSourceTemplate ###
#
#   Function disables the datasource template [string] argument
#
# Arguments:
#       [string] $templateName,
#       [hashtable] $map
#
# Return Values:
#       [boolean]
# Throws: None
#
Function Disable-DataSourceTemplate() {
  param(
      [string] $templateName,
      [hashtable] $map
  )
  return Use-ConfigTool "modify-ds-template -n ""$templateName"" -e false" $map $global:configToolLogfile
}