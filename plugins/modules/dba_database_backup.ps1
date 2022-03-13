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

## Choosing the first block of parametersets. It is unclear about what is different with 

$sqlinstance = Get-AnsibleParam -obj $params -name "sqlinstance" -type "str" -failifempty $true
$dbausername = Get-AnsibleParam -obj $params -name "username" -type "str" -failifempty $true
$dbapassword = Get-AnsibleParam -obj $params -name "password" -type "str" -failifempty $true
$database = Get-AnsibleParam -obj $params -name "database" -type "str" -failifempty $true
$path = Get-AnsibleParam -obj $params -name "path" -type "str" 
$filepath = Get-AnsibleParam -obj $params -name "filepath" -type "str" 
$incrementalprefix = Get-AnsibleParam -obj $params -name "incrementalprefix" -type "bool" -default $false 
$replaceinname = Get-AnsibleParam -obj $params -name "replaceinname" -type "bool" -default $false
$copyonly = Get-AnsibleParam -obj $params -name "copyonly" -type "bool" -default $false
$type = Get-AnsibleParam -obj $params -name "type" -type "str" -ValidateSet "full" , "log" , "differential" , "diff" , "database"
$createfolder = Get-AnsibleParam -obj $params -name "createfolder" -type "bool" -default $false
$filecount = Get-AnsibleParam -obj $params -name "filecount" -type "int"
$compressbackup = Get-AnsibleParam -obj $params -name "compressbackup" -type "bool" -default $false
$checksum = Get-AnsibleParam -obj $params -name "checksum" -type "bool" -default $false
$verify = Get-AnsibleParam -obj $params -name "verify" -type "bool" -default $false
$maxtransfersize = Get-AnsibleParam -obj $params -name "maxtransfersize" -type "str"
$blocksize = Get-AnsibleParam -obj $params -name "blocksize" -type "int" 
$buffercount = Get-AnsibleParam -obj $params -name "buffercount" -type "int"
$norecovery = Get-AnsibleParam -obj $params -name "norecovery" -type "bool" -default $false
$buildpath = Get-AnsibleParam -obj $params -name "buildpath" -type "bool" -default $false
$withformat = Get-AnsibleParam -obj $params -name "withformat" -type "bool" -default $false
$initialize = Get-AnsibleParam -obj $params -name "initialize" -type "bool" -default $false
$skiptapeheader = Get-AnsibleParam -obj $params -name "skiptapeheader" -type "bool" -default $false
$timestampformat = Get-AnsibleParam -obj $params -name "timestampformat" -type "str"
$ignorefilechecks = Get-AnsibleParam -obj $params -name "ignorefilechecks" -type "bool" -default $false
$outputscriptonly = Get-AnsibleParam -obj $params -name "outputscriptonly" -type "bool" -default $false
$encryptionalgorithm = Get-AnsibleParam -obj $params -name "encryptionalgorithm" -type "str"
$encryptioncertificate = Get-AnsibleParam -obj $params -name "encryptioncertificate" -type "str"
$enableexception = Get-AnsibleParam -obj $params -name "enableexception" -type "bool" -default $false

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
## This is a hash table which we will add as a splat to the cmdlet
$backupparams = @{
	
	database = $database
	sqlinstance = $sqlinstance
	ErrorAction = $stop
}
if ($path)
{
	$backupparams.Add('path',$path)
}
if ($filepath)
{
	$backupparams.add('filepath', $filepath)
}

if ($incrementalprefix)
{
	$backupparams.add('incrementalprefix', $true)
}

if ($replaceinname)
{
	$backupparams.add('replaceinname' , $true)
}

if ($copyonly)
{
	$backupparams.add('copyonly', $true)
	
}
if ($type)
{
	$backupparams.add('type', $type)
}

if ($createfolder)
{
	$backupparams.Add('createfolder', $createfolder)
}

if ($filecount)
{
	$backupparams.add('filecount',$filecount)
}

if ($compressbackup)
{
	$backupparams.Add('compressbackup',$compressbackup)
}

if ($checksum)
{
	$backupparams.Add('checksum',$checksum)
}

if ($verify)
{
	$backupparams.add('verify', $verify)
}

if ($maxtransfersize)
{
	$backupparams.add('maxtransfersize',$maxtransfersize)
}

if ($blocksize)
{
	$backupparams.add('blocksize', $blocksize)
}

if ($buffercount)
{
	
	$backupparams.add('buffercount', $buffercount)
}

if ($norecovery)
{
	$backupparams.add('norecovery',$norecovery)
}

if ($buildpath)
{
	
	$backupparams.add('buildpath',$buildpath)
}

if ($withformat)
{
	$backupparams.Add('withformat', $withformat)
}


if ($initialize)
{
	$backupparams.add('initialize', $initialize)
}

if ($skiptapeheader)
{
	$backupparams.add('skiptapeheader', $skiptapeheader)
}

if ($timestampformat)
{
	$backupparams.Add('timestampformat', $timestampformat)
}

if ($ignorefilechecks)
{
	$backupparams.add('ignorefilechecks',$ignorefilechecks)
}

if ($outputscriptonly)
{
	$backupparams.Add('outputscriptonly', $outputscriptonly)
}

if ($encryptionalgorithm)
{
	$backupparams.add('encryptionalgorithm',$encryptionalgorithm)
}

if ($encryptioncertificate)
{
	$backupparams.add('encryptioncertificate', $encryptioncertificate)
}

if ($enableexception)
{
	$backupparams.Add('enableexception', $enableexception)
}
## we add the splat
Backup-DbaDatabase @backupparams 



Exit-Json $result


# Reference
# https://docs.ansible.com/ansible/2.6/dev_guide/developing_modules_general_windows.html
# https://docs.ansible.com/ansible/2.4/dev_guide/developing_modules_general_windows.html
