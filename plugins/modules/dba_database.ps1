#!/usr/bin/pwsh
# WANT_JSON
# This file is part of Ansible

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# region main functions
$ErrorActionPreference = 'Stop'

$params = Parse-Args -arguments $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$diff_mode = Get-AnsibleParam -obj $params -name "_ansible_diff" -type "bool" -default $false

# these are your module parameters, there are various types which can be
# used to format your parameters. You can also set mandatory parameters
# with -failifempty, set defaults with -default and set choices with
# -validateset.
$name = Get-AnsibleParam -obj $params -name "name" -type "str" -failifempty $true
$sqlinstance = Get-AnsibleParam -obj $params -name "sqlinstance" -type "str" -failifempty $true
$dbausername = Get-AnsibleParam -obj $params -name "username" -type "str" -failifempty $true
$dbapassword = Get-AnsibleParam -obj $params -name "password" -type "str" -failifempty $true
$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present" -validateset "absent", "present"
$collation = Get-AnsibleParam -obj $params -name "collation" -type "str"
$recoverymodel = Get-AnsibleParam -obj $params -name "recoverymodel" -type "str"
$DataFilePath = Get-AnsibleParam -obj $params -name "datafilepath" -type "str"
$LogFilePath = Get-AnsibleParam -obj $params -name "logfilepath" -type "str"
$PrimaryFilesize = Get-AnsibleParam -obj $params -name "primaryfilesize" -type "int"
$PrimaryFileGrowth = Get-AnsibleParam -obj $params -name "primaryfilegrowth" -type "int"
$PrimaryFileMaxSize = Get-AnsibleParam -obj $params -name "primaryfilemaxsize" -type "int"
$LogSize = Get-AnsibleParam -obj $params -name "logsize" -type "int"
$LogGrowth = Get-AnsibleParam -obj $params -name "loggrowth" -type "int"
$LogMaxSize = Get-AnsibleParam -obj $params -name "logmaxsize" -type "int"
$SecondaryFilesize = Get-AnsibleParam -obj $params -name "secondaryfilesize" -type "int"
$SecondaryFileGrowth = Get-AnsibleParam -obj $params -name "secondaryfilegrowth" -type "int"
$SecondaryFileMaxSize = Get-AnsibleParam -obj $params -name "secondaryfilemaxsize" -type "int"
$SecondaryFileCount = Get-AnsibleParam -obj $params -name "secondaryfilecount" -type "int"
$DefaultFileGroup = Get-AnsibleParam -obj $params -name "defaultfilegroup" -type "str" -ValidateSet "primary", "secondary"

$result = @{
	changed  = $false
	database = ''
}

#region test import dbatools module
try {
	Import-Module dbatools -ErrorAction stop
	
}
catch {
	Fail-Json -obj $result -message "The module dbatools is not present in the environment. Please install before running this task."
}
## Region generate credential  so that this becomes the base for connecting to the SQL Instance.
[string]$credusername = $dbausername
[string]$credpassword = $dbapassword
[securestring]$secStringPassword = ConvertTo-SecureString $credpassword -AsPlainText -Force
[pscredential]$dbacredObject = New-Object System.Management.Automation.PSCredential ($credusername, $secStringPassword)
##endregion 

#region  attempt to connect to sqlinstance
try {
	Connect-DbaInstance -SqlInstance $sqlinstance -SqlCredential $dbacredObject | out-null
}
catch {
	Fail-Json -obj $result -message "There was a failure connecting to the sqlserver instance. The error message was ($_.exception)"
}

#endregion


$collection = @() #build a data collection for structureddata
$badcollection = @()
if ($diff_mode) {
	$result.diff = @{ }
}
$testdatabasepresent = Get-DbaDatabase -SqlInstance $sqlinstance -SqlCredential $dbacredObject -Database $name

if ($testdatabasepresent.name -eq $name) {
	$databasepresent = $true
}
else {
	$databasepresent = $false
}

if ($state -eq 'present') {
	
	if ($databasepresent -eq $false) {
		#region creates a generic hash table that fills out the parameters from the yaml to new-dbadatabase cmdlet.
		$dbaparams = @{
			name          = $name;
			sqlinstance   = $sqlinstance;
			erroraction   = 'stop'
			sqlcredential = $dbacredObject
		}
	 
		if ($collation) {
			$dbaparams.add('collation', $collation)
		}
		
		if ($recoverymodel) {
			$dbaparams.add('recoverymodel', $recoverymodel)
		}
		
		if ($DataFilePath) {
			$dbaparams.add('datafilepath', $DataFilePath)
		}
		
		if ($LogFilePath) {
			$dbaparams.add('logfilepath', $LogFilePath)
		}
		
		if ($PrimaryFilesize) {
			$dbaparams.add('primaryfilesize', $PrimaryFilesize)
		}
		
		if ($PrimaryFileGrowth) {
			$dbaparams.Add('primaryfilegrowth', $PrimaryFileGrowth)
		}
		
		if ($primaryFilemaxsize) {
			$dbaparams.add('primaryfilemaxsize', $PrimaryFileMaxSize)
		}
		
		if ($logsize) {
			$dbaparams.add('logsize', $LogSize)
		}
		
		if ($LogGrowth) {
			$dbaparams.add('loggrowth', $LogGrowth)
		}
		
		if ($LogMaxSize) {
			$dbaparams.add('logmaxsize', $LogMaxSize)
		}
		
		if ($SecondaryFilesize) {
			$dbaparams.add('secondaryfilesize', $SecondaryFilesize)
		}
		
		if ($SecondaryFileGrowth) {
			$dbaparams.add('secondaryfilegrowth', $SecondaryFileGrowth)
		}
		
		if ($SecondaryFileMaxSize) {
			$dbaparams.add('secondaryfilemaxsize', $SecondaryFileMaxSize)
		}
		$result.changed = $true #set to true here to accomodate for checkmode.
		#endregion
		if (-not ($checkmode)) {
			
			#this allows  for dry runs
			
			try {
				$databaseobject = New-DbaDatabase @dbaparams
				$newdatabaseobject = $databaseobject | Select-Object computername, instancename, sqlinstance, name, status, isaccessible, recoverymodel, logreusewaitstatus, sizemb, Compatibility, Collation, Owner, LastFullBackup, LastDiffBackup, LastLogBackup
				$result.database += $newdatabaseobject
			}
			catch {
				$result.change = $false
				Fail-Json -obj $result -message "Error was this $Error[0]"
			}
			
		}
	}
	else {
		$result.message = "The database $name is already present on the SQL Instance $sqlinstance  "
	}
}

if ($state -eq 'absent') {
	if ($databasepresent) { 
		$result.changed = $true
		if (-not ($checkmode)) {
			#this allows  for dry runs
			try {
				
				Get-DbaDatabase -database $name -sqlinstance $sqlinstance -SqlCredential $dbacredObject | Remove-DbaDatabase  -Confirm:$false -ErrorAction Stop
				
				$message = ''
				
			}
			catch {
				Fail-Json -obj $result -message "Error was this $Error[0]"
			}
			
		}
	}
}
Exit-Json $result


# Reference
# https://docs.ansible.com/ansible/2.6/dev_guide/developing_modules_general_windows.html
# https://docs.ansible.com/ansible/2.4/dev_guide/developing_modules_general_windows.html