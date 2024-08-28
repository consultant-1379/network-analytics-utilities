# ********************************************************************
# Ericsson Radio Systems AB                                     SCRIPT
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
# Name    : NetAnServer_upgrade.ps1
# Date    : 08/09/2020
# Purpose : #  Upgrade script for Ericsson Network Analytic Server
#
# Usage   : NetAnServer_upgrade.ps1
#
#---------------------------------------------------------------------------------

# check if backup data present for 79 or 711
Remove-Module *
. C:\Ericsson\tmp\Scripts\Install\NetAnServer_install.ps1
MainUpgrade
