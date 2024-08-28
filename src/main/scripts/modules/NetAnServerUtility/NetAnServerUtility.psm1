# ********************************************************************
# Ericsson Radio Systems AB                                     MODULE
# ********************************************************************
#
#
# (c) Ericsson Radio Systems AB 2021 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Radio Systems AB, Sweden. The programs may be used 
# and/or copied only with the written permission from Ericsson Radio 
# Systems AB or in accordance with the terms and conditions stipulated 
# in the agreement/contract under which the program(s) have been 
# supplied.
#
# ********************************************************************
# Name    : NetAnServerUtility.psm1
# Date    : 23/07/2021
# Purpose : This is the containing generic utility functions that are used in
#           NetAnServer Installation
#
#
Import-Module Logger
$currentLocation = Get-Location
Set-Location $currentLocation

### Function: Test-FileExists ###
#
#   Test if a file exists
#
# Arguments:
#   [string]$fileName.
#
# Return Values:
#   [boolean]$true|$false
#
function Test-FileExists {
    param (
        [String]$fileName
    )
    try {
        $fileExists = Test-Path $fileName -ErrorAction Stop
    } catch {
        return $False
    }
    return $fileExists
}


### Function: Test-ServiceRunning ###
#
#   Test if a Service is Running.
#
# Arguments:
#   [string]$serviceName.
#
# Return Values:
#   [boolean]$true|$false
#
function Test-ServiceRunning {
     param (
        [String]$serviceName
     )
    if (Test-ServiceExists($serviceName)) {
        $service = Get-Service -Name $serviceName
        if ($service.Status -eq "Running") {
            return $True
        }
    }
    return $False
}



### Function: Test-ServiceExists ###
#
#   Test if a Service Exists.
#
# Arguments:
#   [string]$serviceName.
#
# Return Values:
#   [boolean]$true|$false
#
#
function Test-ServiceExists {
     param (
        [String]$serviceName
     )

    if ($serviceName -eq $null) {
        return $False
    }

    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
    } catch {
        return $False
    }
        return $True
}


### Function: Get-ServiceState ###
#
#   Test the OS Version.
#
# Arguments:
#   [string] $serviceName - the name of the service
#
# Return Values:
#   [string]$serviceStatus - the service state
#   [null] $null if service is not found
#
#
Function Get-ServiceState {
     param (
        [String]$serviceName
     )
    if (Test-ServiceExists($serviceName)) {
        $service = Get-Service -Name $serviceName
        return $service.Status
    } else {
        return $null
    }
}


### Function: Test-OS ###
#
#   Test the OS Version.
#
# Arguments:
#   [hashtable] $osVersionmap e.g. "Microsoft Windows Server 2016 Standard or Microsoft Windows Server 2022 Standard"
#
# Return Values:
#   [boolean]$true|$false
#
#
function Test-OS {
    param(
        [hashtable] $osVersionmap
    )
    $osCaption = Get-OSCaption
    if ($osCaption.contains($osVersionmap.osVersion2016) -or  $osCaption.contains($osVersionmap.osVersion2019) -or $osCaption.contains($osVersionmap.osVersion2022)){
       return $True 
    } else {
        return $False
    }
}
### Function: Test-FrameWork ###
#   $_.Release -ge 528049 corresponds to 4.8.0
#   Test the OS Version.
#
# Return Values:
#   [boolean]$true|$false
#
#
function Test-FrameWork {
    $a = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse |
		 Get-ItemProperty -name Version,Release -EA 0 |Where { $_.PSChildName -match '^(?!S)\p{L}' -and $_.Version -like '4.8*'} 
    if ($a.Count -gt 0) {
       return $True 
    } else {
        return $False
    }
}



### Function: Get-OSCaption ###
#
#   Returns the caption of the OS i.e. The OS name.
#
# Arguments:
#   None
#
# Return Values:
#   [string] the os caption
#
#
Function Get-OSCaption {

    try {
        $caption = (Get-WmiObject -class Win32_OperatingSystem -ErrorAction Stop).Caption
    } catch {
        return ""
    }
    return $caption
}


### Function: Test-PasswordPolicy ###
#
#   Returns true if [string]|[int] value is alphanumeric
#   and contains special character.
#   allows characters and whitespace
#
# Arguments:
#   None
#
# Return Values:
#   [boolean] $True if is Pass, $False if not
#
#
function Test-PasswordPolicy($value){
    if ($value -match '^[a-zA-Z0-9`~!@#$%^\&*\(\)-_+=\|\]\[{}'':;""?/.,\>\<\s]+$'){
        return $True
    } else {
        return $False
    }
}


### Function: Test-Number ###
#
#   Returns true if [string] contains at least 1 
#   number.
#
# Arguments:
#   [string]
#
# Return Values:
#   [boolean] $True if a number is present, $False if not
#
#
function Test-Number([string]$value) {
    if($value -match "[0-9]") {
        return $True
    } else {
        return $False
    }
}

### Function: Test-Capital ###
#
#   Returns true if [string] contains at least 1 
#   Capital.
#
# Arguments:
#   [string]
#
# Return Values:
#   [boolean] $True if a capital is present, $False if not
#
#
function Test-Capital([string]$value) {
    if($value -cmatch "[A-Z]") {
        return $True
    } else {
        return $False
    }
}

### Function: Test-Lower ###
#
#   Returns true if [string] contains at least 1 
#   lowercase char.
#
# Arguments:
#   [string]
#
# Return Values:
#   [boolean] $True if a lower is present, $False if not
#
#
function Test-Lower([string]$value) {
    if($value -cmatch "[a-z]") {
        return $True
    } else {
        return $False
    }
}


### Function: Test-Password ###
#
#   Returns true if [string] value is alphanumeric, 
#   greater than 7 characters in length and contains
#   at least 1 capital letter and at least 1 number
#   and atleast 1 special character.
#
# Arguments:
#   [string]
#
# Return Values:
#   [boolean] $True if password is ok, $False if not
#
#
function Test-Password([string]$password){
    if ((Test-PasswordPolicy($password)) -and 
        (Test-Capital($password)) -and 
        (Test-Lower($password)) -and
        (Test-Number($password)) -and
        ($password.Length -ge 8) -and
        ($password.Length -le 32)) {
        return $True
    } else {
        return $False
    }
}



### Function: Test-IP ###
#
#   Returns true if IP address is a valid
#   Ipv4 or Ipv6 address.
#
# Arguments:
#   [string] IP address
#
# Return Values:
#   [boolean] $True if valid, $False if not
#
#
function Test-IP {  
    param (  
        [Parameter(Mandatory=$true)]
        [String]$ip            
    )

    try { 
       $isValid = [bool]($ip -as [ipaddress])
    } catch {
        return $False
    }

    $segments = TestIPv4Segments $ip
    if (($segments -lt 4) -and !($ip.contains(':'))) {
        return $False
    }

    return $isValid
}

#
#Helper function for Test-IP
# Edge Case exists in cast to [ipaddress]
# the cast of 192.168.1 returns a valid ipaddress
#
Function TestIPv4Segments {
    param (  
        [String]$ip            
    ) 

    if ($ip.contains('.')) {
        return $ip.Split('.').Count -eq 4
    }
    
    return $False 
}


### Function: Test-SoftwareInstalled ###
#
#   Returns an array of all Class Win32_Product
#   installed software. The first index of the array
#   contains a boolean indicating if there was a match.
#   If a match, all names are returned in the array
#
# Arguments:
#   [string] $name - name of software to find
#
# Return Values:
#   @() an array.  
#   @()[0] [boolean] - if match was found
#   @()[0+n] [pscustomobject] with a single property 'name'
#
function Test-SoftwareInstalled {
    param (  
        [String]$name
    )
 
   try {
      $result =  Get-WmiObject -Class Win32_Product -ErrorAction Stop | select Name | where { $_.Name -match $name}
      
      if ($result -and $name) {
        return @($true)+$result
      } else {
        return @($false)
      }

   } catch {
      return @($false)
   }
}


### Function: Test-FeatureInstalled ###
#
#   Checks if a Windows Feature is installed.
#
# Arguments:
#   [string] $name - name of feature
#
# Return Values:
#   [boolean] - if match was found
#
function Test-FeatureInstalled($name) {
    try {
        $feature = Get-WindowsFeature $name -ErrorAction Stop
        if (($feature.Installed -eq "True") -and $name) { 
           return $True
        } else { 
           return $False 
        }
    } catch {
        return $False
    }
}


### Function: Test-ModuleLoaded ###
#
#   Checks if a Powershell Module is loaded.
#
# Arguments:
#   [string] $name - name of module
#
# Return Values:
#   [boolean] - $true if module was found
#
function Test-ModuleLoaded {
    param(
      [string]$moduleName
    )

    $loadedModules = Get-Module | Select Name
    
    if (!$loadedModules -like "$moduleName*") {
        return $False
    }

    if(!$moduleName) {
        return $False
    }

    return $True    
}


### Function: Test-MapForKeys ###
#
#   Checks if the map passed has the 
#   keys required
#
# Arguments:
#   [hashtable] $map
#   [list] $requiredKeys
# Return Values:
#   [list] - @($true|$false, [string] $message) 
#

Function Test-MapForKeys {
    param(
        [hashtable] $map,
        [array] $requiredKeys
    )

     if ($map) {
        foreach ($paramKey in $requiredKeys) {
            if (-not $map[$paramKey]) {                   
                return @($False, "Invalid Parameters Passed. Parameter at key $paramKey not Found")          
            } 
        } 
        
        if ($requiredKeys) {       
            return @($True, "All Parameters validated successfully")
        } else {
            return @($False, "The keys passed were null")
        }

    } else {            
        return @($False, "Incorrect Parameters Passed. Parameter Map is Null Valued")
    }
}

### Function: Invoke-UtilitiesSQL ###
#
#   Executes a SQL command. Tests if the PostgreSQL service is running.
#   
# Arguments:
#       [string] $database,
#       [string] $username,
#       [string] $password,
#       [string] $serverInstance,
#       [string] $query,
#       [string] $action (Expected values - 'insert' or 'fetch')
#  
# Return Values:
#        [list]
#
Function Invoke-UtilitiesSQL() {
    param(
        [parameter(mandatory=$True)]
        [string] $database,
        [parameter(mandatory=$True)]
        [string] $username,
        [parameter(mandatory=$True)]
        [string] $password,
        [parameter(mandatory=$True)]
        [string] $serverInstance,
        [parameter(mandatory=$True)]
        [string] $query,
		[parameter(mandatory=$True)]
        [string] $action
		
    )
    $SQL_SERVICE = "postgresql-x64-" + (((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Postgres*).MajorVersion) | measure -Maximum).Maximum
	
    $isRunning = Test-ServiceRunning "$($SQL_SERVICE)"

    if (-not $isRunning) {
        return @($False,"SQL Service $($SQL_SERVICE) is not running. Exiting")
        Exit
    }
	$driver = @((Get-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers" | Select-Object -ExpandProperty Property) | Where-Object {$_ -like 'postgresql*unicode*'})
	if ($driver.count -eq 0) {
        return @($False,"PostgreSQL ODBC driver is not installed. Exiting")
        Exit
    }
    try {
		$conn = New-Object System.Data.Odbc.OdbcConnection
		$conn.ConnectionString = "Driver={" + $driver[0] + "};Server=" + $serverInstance + ";Port=5432;Database=" + $database + ";Uid=" + $username + ";Pwd=" + $password + ";"
		if ($action -match "fetch"){
			$conn.open()
			$cmd = New-object System.Data.Odbc.OdbcCommand($query,$conn)
			$ds = New-Object system.Data.DataSet
			(New-Object system.Data.odbc.odbcDataAdapter($cmd)).fill($ds) | out-null
			$conn.close()
			return @($True,$ds.Tables[0])
        }
		elseif ($action -match "insert")  {
			$conn.open()
			$cmd = New-object System.Data.Odbc.OdbcCommand($query,$conn)
			$cmd.ExecuteNonQuery()
			$conn.close()
			return @($True,"SQL statement executed.")
		}
		else {
			return @($False, "Invalid argument.")
		}
    } catch {
        $errorMessage = "$_.Exception.Message`nError executing SQL statement. `nServer Instance: $serverInstance `nDatabase: $database `nQuery: $query"
        return @($False, $errorMessage)
    } 
}

### Function: Test-BuildIsGreaterThan ###
#
#   Tests if buildOne is greater than buildTwo.
#
#
# Arguments:
#       [string] $buildOne,
#       [string] $buildTwo
#
# Return Values:
#        [bool]
#
Function Test-BuildIsGreaterThan() {
      param(
        [string] $buildOne,
        [string] $buildTwo
    )

    # Ensure Uppercase
    $buildOne = $buildOne.Trim()
    $buildTwo = $buildTwo.Trim()
    $upperBuildOne = $buildOne.ToUpper();
    $upperBuildTwo = $buildTwo.ToUpper();

    #Remove leading 0 after R, i.e R0001A0001 -> R1A1
    $buildOne = $upperBuildOne -Replace "([A-Z])(0+)", '$1'
    $buildTwo = $upperBuildTwo -Replace "([A-Z])(0+)", '$1'

    #Test Release
    [int]$buildOneRelease = $buildOne -replace "^R(\d+).+", '$1'
    [int]$buildTwoRelease = $buildTwo -replace "^R(\d+).+", '$1'

    if($buildOneRelease -gt $buildTwoRelease) {
        return $True
    }

    if($buildOneRelease -lt $buildTwoRelease) {
        return $False
    }

    #if same release check alpha
    [string]$buildOneRelease = $buildOne -replace "^R(\d+)([A-Z]).+", '$2'
    [string]$buildTwoRelease = $buildTwo -replace "^R(\d+)([A-Z]).+", '$2'

    if($buildOneRelease -gt $buildTwoRelease) {
        return $True
    }

    if($buildOneRelease -lt $buildTwoRelease) {
        return $False
    }

    #now check build increment
    [int]$buildOneRelease = $buildOne -replace "^R(\d+)([A-Z])(\d+)", '$3'
    [int]$buildTwoRelease = $buildTwo -replace "^R(\d+)([A-Z])(\d+)", '$3'

    if($buildOneRelease -gt $buildTwoRelease) {
        return $True
    } else {
        return $False
    }
}

#----------------------------------------------------------------------------------
#  Create Secure Machine Environment Variable
#----------------------------------------------------------------------------------
Function Set-EnvVariable {
    param(
        [String]$source,
        [String]$envVarName
    )

    Try {
        $secure = ConvertTo-SecureString $source -force -asPlainText
        $Key = (231,218,9,77,42,168,254,111,24,201,181,169,247,5,91,190,208,195,7,239,38,190,139,63,114,114,91,66,18,54,30,209)
        $bytes = ConvertFrom-SecureString $secure -Key $Key
        [Environment]::SetEnvironmentVariable($envVarName, $bytes, "Machine")
    } Catch {
        $errorMessage = $_.Exception.Message
        $logger.logError($MyInvocation, "Could not create environment variable. `n $errorMessage", $True)
    }

}

#
#    Returns Environment variable and decrypts
Function Get-EnvVariable {
    param(
        [String]$envVarName
    )
    $encrypted = [environment]::GetEnvironmentVariable($envVarName,"Machine")

        $Key = (231,218,9,77,42,168,254,111,24,201,181,169,247,5,91,190,208,195,7,239,38,190,139,63,114,114,91,66,18,54,30,209)
        $password = ConvertTo-SecureString -Key $key -String $encrypted
        return $password
}

### Function: Test-ShellIsAdmin ###
#
#   Checks if the the current shell is opened as administrator
#
# Arguments: none
#
# Return Values: boolean
#
Function Test-ShellIsAdmin {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

### Function: Start-SpotfireService ###
#
#   Starts a Service
#
# Arguments: 
#    [string] $service

# Return Values: boolean
#
Function Start-SpotfireService {
    param (
        [String]$service
    )
    $logger.logInfo("Preparing to start $service.", $False)
    $serviceExists = Test-ServiceExists $service
    $logger.logInfo("Service $service found: $serviceExists.", $False)

    if ($serviceExists) {
        $isRunning = Test-ServiceRunning "$($service)"
        if ($isRunning) {
            $logger.logInfo("Service is already running.", $False)
            return $True
        } else {
            $logger.logInfo("Starting $service.", $True)
        
            try {
                Start-Service -Name "$($service)" -ErrorAction stop -WarningAction SilentlyContinue
                
                $isRunning = Test-ServiceRunning "$($service)"
                while(-not $isRunning){          
                    Start-Sleep -s 1
                    $isRunning = Test-ServiceRunning "$($service)"
                }
                
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, $errorMessage, $True)
                return $False
            }

            # double checking service has started properly, as the node manager sometimes starts and
            # stops again a few seconds later, causing the error to avoid being caught
            Start-Sleep -s 10
            $isRunning = Test-ServiceRunning "$($service)"
            if (-not $isRunning) {
                $logger.logError($MyInvocation,"Could not start $service service.", $True)
                return $False
            }

            
        }
    } else {
        $logger.logError($MyInvocation,"Service $service not found. Please check $service install was executed correctly.", $True)
        return $False
    }

    return $True
}

### Function: Stop-SpotfireService ###
#
#   Stops a Service
#
# Arguments: 
#    [string] $service

# Return Values: boolean
#
Function Stop-SpotfireService {
    param (
        [String]$service
    )
    $logger.logInfo("Preparing to stop $service", $False)

    $serviceExists = Test-ServiceExists "$service"
    
    if ($serviceExists) {
        $logger.logInfo("Service $service found: $serviceExists", $False)

        $isRunning = Test-ServiceRunning "$service"

        if ($isRunning) {
			$logger.logInfo("$service is running.", $False)
			$logger.logInfo("Stopping $service.", $True)
            try {
                Stop-Service -Name "$service" -ErrorAction stop -WarningAction SilentlyContinue
                
            } catch {
                $errorMessage = $_.Exception.Message
                $logger.logError($MyInvocation, "Could not stop service. `n $errorMessage", $True)
                return $False
            }
			
            $logger.logInfo("Service $service has stopped successfully.")
            return $True
        } else {
			$logger.logInfo("Service has already stopped.", $False)  
            return $True        
        }


    } else {
        $logger.logError($MyInvocation, "Service $service not found. Please check $service install was executed correctly.", $True)
        return $False

    }

    
}

Export-ModuleMember "*-*"
