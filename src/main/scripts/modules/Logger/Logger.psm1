# ********************************************************************
# Ericsson Radio Systems AB                                     MODULE
# ********************************************************************
#
#
# (c) Ericsson Radio Systems AB 2015 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Radio Systems AB, Sweden. The programs may be used
# and/or copied only with the written permission from Ericsson Radio
# Systems AB or in accordance with the terms and conditions stipulated
# in the agreement/contract under which the program(s) have been
# supplied.
#
# ********************************************************************
# Name    : Logger.psm1
# Date    : 03/03/2015
# Revision: PA1
# Purpose : Logging Utility for NetAnServer Install
# Usage:
#   Get-Logger([string] $logger_name)
#   logError([System.Management.Automation.InvocationInfo]$MyInvocation, [string] $message, [boolean] $toScreen)
#   logInfo([string] $message, [boolean] $toScreen)
#   setLogDirectory([string] $dir)
#   setLogName([string] $name)

$script:loggers = @{}

### Function: Get-Logger ###
#
#   This function provides a logger instance.
#   Searches the loggers map by the key $logger_name.
#   If none present will create a new instance and adds it to the $script:loggers map
#
# Arguments:
#   $logger_name[string] the string logger name.
#
# Return Values:
#   logger psobject instance.
#
function global:Get-Logger($logger_name) {
    if(!$script:loggers.ContainsKey([string]$logger_name)) {
        $logger = New-Object psobject
        Add-Member -in $logger NoteProperty 'filename' $logger_name'.log'
        Add-Member -in $logger NoteProperty 'loggerName' $logger_name
        Add-Member -in $logger NoteProperty 'logDirectory' './'
        Add-Member -in $logger NoteProperty 'timestamp' $(get-date -Format 'yyyyMMdd_HHmmss')
        Add-Member -InputObject $logger -MemberType ScriptMethod -Name logError -Value $logError
        Add-Member -InputObject $logger -MemberType ScriptMethod -Name logInfo -Value $logInfo
        Add-Member -InputObject $logger -MemberType ScriptMethod -Name logWarning -Value $logWarning
        Add-Member -InputObject $logger -MemberType ScriptMethod -Name setLogDirectory -Value $setLogDirectory
        Add-Member -InputObject $logger -MemberType ScriptMethod -Name setLogName -Value $setLogName
        $script:loggers.Add([string]$logger_name, $logger)
    }
    return $script:loggers.Get_Item([string]$logger_name)
}


### ScriptMethod: logError ###
#
#   Logs an error to console and/or file
#
# Arguments:
#   $miInvocation [System.Management.Automation.InvocationInfo] Required. A $MyInvocation object.
#   $message [string] the string message to log
#   $toScreen [boolean] flag to display message to console. $true: console and log. $false (DEFAULT) to log only.
#
# Return Values:
#   None
#
# Throws:
#   Exception if no [System.Management.Automation.InvocationInfo] object is passed
#
$logError = {
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.InvocationInfo] $miInvocation,
        [string]$message,
        [boolean]$toScreen = $false
       )

    $lineNumber = $MiInvocation.ScriptLineNumber
    Write-Host $MiInvocation.DisplayScriptPosition
    $script = $MiInvocation.ScriptName
    $functionName = $MiInvocation.MyCommand

    $message += "`r`nScript: "+"$script"+" `r`n"
    $message += "Function: "+$functionName+" `r`n"
    $message += "Line Number: $lineNumber `r`n"

    Log-Message -level "ERROR" -message $message -toScreen $toScreen
}


### ScriptMethod: logInfo ###
#
#   Logs the info message to console and/or file.
#
# Arguments:
#    $message [string] - the string message to log
#    $toScreen [boolean] - flag to display message to console. $true: console and log. $false (DEFAULT) to log only
# Return Values:
#    none
#
$logInfo = {
 param( [string]$message, [boolean]$toScreen = $false )
    Log-Message -level "INFO" -message $message -toScreen $toScreen
}


### ScriptMethod: logWarning ###
#
#   Logs the Warning message to console and/or file.
#
# Arguments:
#    $message [string] - the string message to log
#    $toScreen [boolean] - flag to display message to console. $true: console and log. $false (DEFAULT) to log only
# Return Values:
#    none
#
$logWarning = {
 param( [string]$message, [boolean]$toScreen = $false )
    Log-Message -level "WARNING" -message $message -toScreen $toScreen
}


### ScriptMethod: setLogDirectory ###
#
#   Sets the log output directory.
#   Overrides the default directory which is the current working directory.
#   Will Throw an exception if directory does not exist.
#
# Arguments:
#   $dir [string] the name of the log directory
# Return Values:
#   None
# Throws:
#    Exception if directory not found
#
$setLogDirectory = {
    param([string] $dir)
    if(!(Test-Path($dir))) {
        throw "ERROR - Logger.ps1. $($dir) does not exist"
    }
    $this.logDirectory = "$($dir)\"
}


### ScriptMethod: setLogName
#
#   Sets the log file name.
#   Overrides the default logfile name
#
# Arguments:
#   $name [string]  - the log file name. Filename extension must be included
# Return Values:
#   none
#
$setLogName = {
    param([string] $name)
    $this.filename = $name
}


### Function: Log-Message function ###
#
#   Logs the Error or Info Log messages to screen and console.
#   
# Arguments:
#   $level[string] - The log level. INFO|ERROR
#   $message[string] - The message to log
#   $toScreen[boolean] - Boolean flag to display log to screen. Default is false(do not display to screen)
# Return Values:
#   none
#
function Log-Message {
     param(
     [string]$level,
     [string]$message,
     [boolean] $toScreen
     )

     $log_colors = @{'INFO'='green'; 'ERROR'='red'; 'WARNING'='yellow'}
     $logfile = "$($this.logDirectory)$($this.timestamp)_$($this.filename)"
     $timestamp = $(get-date -Format 'yyyy/MM/dd HH:mm:ss')

     if($toScreen) {
        Write-Host "$timestamp - $($level): $($message) $($invocation)" -Foreground $log_colors[$level]
     }

     "$timestamp - $($level): $($message) $($invocation)" | Out-File $logfile -Append
}


$global:LoggerNames = New-Object psobject
Add-Member -in $LoggerNames NoteProperty 'Install' -Value "NetAnServerLogger".GetHashCode()

Export-ModuleMember "Get-Logger"
