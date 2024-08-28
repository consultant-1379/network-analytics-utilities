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
# Name    : ConcurrentUsers.psm1
# Date    : 20/08/2020
# Purpose : Parses usage.log and returns the number of the each
#           users per user group: Business Analyst, Business Author, Consumer, Other for a ROP period of 15 Min
#
# Usage   : 
#

Import-Module NetAnServerUtility

### Function: Get-ConcurrentUsers ###
#
#    Returns a count of all users by group type.
#   
#
# $usagelog="C:\Ericsson\NetAnServer\Server\$version\tomcat\logs\usage.log"
# Return Values: [hashtable]
#       
# Throws:
#       None
#
Function Get-ConcurrentUsers {
   param(
        [parameter(mandatory=$True)]
        [string] $usagelog,
        [parameter(mandatory=$True)]
        [string] $platform
    )

   
  [datetime]$timeStamp = Get-Date -Format s
  [datetime]$ropTime=$timeStamp.addminutes(-(($timeStamp.minute % 15)+15)) 
  $ropStartMin=$ropTime.Minute
  $ropEndMin=$ropStartMin+14
  $searchString=$ropTime.ToString('yyyy-MM-ddTHH')
  $userList = [System.Collections.ArrayList] @()
  
  $allUser=Get-Users -all


  $businessAuthor= $allUser|Where-Object { $_.Group -eq "Business Author"}
  $businessAnalyst= $allUser|Where-Object { $_.Group -eq "Business Analyst"}
  $consumer = $allUser|Where-Object { $_.Group -eq "Consumer"}
  $businessAuthorCount=0
  $businessAnalystCount=0
  $counsumerCount=0
  $otherCount=0


  $usage=Get-Content $usagelog|Select-String $searchString
  foreach($line in $usage) {
    $row= $line.ToString().Split(" ")
    $min=$row[3].Split(":")|Select -Index 1
    if( ($ropStartMin -le $min) -and ($min -le $ropEndMin) ) {
      $userList.Add(($row[2])) | Out-Null
    }
  }
  $uniqueUsers = $userList|Select -Unique
  $total=$uniqueUsers|Measure-Object

  foreach($user in $uniqueUsers ) {
    if($user -ne $null) {
      if($businessAnalyst) {
        if($businessAnalyst.UserName.Contains($user)) {
          $businessAnalystCount=$businessAnalystCount+1
          continue
        }
      }
      if($businessAuthor) {
        if($businessAuthor.UserName.Contains($user)) {
          $businessAuthorCount=$businessAuthorCount+1
          continue
        }
      }
      if($consumer) {
        if($consumer.UserName.Contains($user)) {
          $counsumerCount=$counsumerCount+1
          continue
        }
      }
      else {
        $otherCount=$otherCount+1
      }
    }
  }
      
$formattedTime=$ropTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss')
    
    $RECORD = New-Object System.Collections.Specialized.OrderedDictionary

    $RECORD.Add('TIMESTAMP',$formattedTime)
    $RECORD.Add( 'ANALYST',$businessAnalystCount)
    $RECORD.Add( 'AUTHOR',$businessAuthorCount)
    $RECORD.Add( 'CONSUMER',$counsumerCount)
    $RECORD.Add( 'OTHER',$otherCount)
    $RECORD.Add( 'TOTAL',$($total.count))
    

  return $RECORD
}