#!/usr/bin/pwsh
# WANT_JSON
# This file is part of Ansible

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#region Helper functions

Function Exit-Json($obj)
{
<#
    .SYNOPSIS
    Helper function to convert a PowerShell object to JSON and output it, exiting
    the script
    .EXAMPLE
    Exit-Json $result
#>

    # If the provided $obj is undefined, define one to be nice
    If (-not $obj.GetType)
    {
        $obj = @{ }
    }

    if (-not $obj.ContainsKey('changed')) {
        Set-Attr -obj $obj -name "changed" -value $false
    }

    Write-Output $obj | ConvertTo-Json -Compress -Depth 99
    Exit
}

Function Set-Attr($obj, $name, $value)
{
	# If the provided $obj is undefined, define one to be nice
	If (-not $obj.GetType)
	{
		$obj = @{ }
	}
	
	Try
	{
		$obj.$name = $value
	}
	Catch
	{
		$obj | Add-Member -Force -MemberType NoteProperty -Name $name -Value $value
	}
}


Function Fail-Json($obj, $message = $null)
{
	if ($obj -is [hashtable] -or $obj -is [psobject])
	{
		# Nothing to do
	}
	elseif ($obj -is [string] -and $message -eq $null)
	{
		# If we weren't given 2 args, and the only arg was a string,
		# create a new Hashtable and use the arg as the failure message
		$message = $obj
		$obj = @{ }
	}
	else
	{
		# If the first argument is undefined or a different type,
		# make it a Hashtable
		$obj = @{ }
	}
	
	# Still using Set-Attr for PSObject compatibility
	Set-Attr $obj "msg" $message
	Set-Attr $obj "failed" $true
	
	if (-not $obj.ContainsKey('changed'))
	{
		Set-Attr $obj "changed" $false
	}
	
	write-output $obj | ConvertTo-Json -Compress -Depth 99
	Exit 1
}

Function Get-AnsibleParam($obj, $name, $default = $null, $resultobj = @{ }, $failifempty = $false, $emptyattributefailmessage, $ValidateSet, $ValidateSetErrorMessage, $type = $null, $aliases = @())
{
	# Check if the provided Member $name or aliases exist in $obj and return it or the default.
	try
	{
		
		$found = $null
		# First try to find preferred parameter $name
		$aliases = @($name) + $aliases
		
		# Iterate over aliases to find acceptable Member $name
		foreach ($alias in $aliases)
		{
			if ($obj.ContainsKey($alias))
			{
				$found = $alias
				break
			}
		}
		
		if ($found -eq $null)
		{
			throw
		}
		$name = $found
		
		if ($ValidateSet)
		{
			
			if ($ValidateSet -contains ($obj.$name))
			{
				$value = $obj.$name
			}
			else
			{
				if ($ValidateSetErrorMessage -eq $null)
				{
					#Auto-generated error should be sufficient in most use cases
					$ValidateSetErrorMessage = "Get-AnsibleParam: Argument $name needs to be one of $($ValidateSet -join ",") but was $($obj.$name)."
				}
				Fail-Json -obj $resultobj -message $ValidateSetErrorMessage
			}
			
		}
		else
		{
			$value = $obj.$name
		}
		
	}
	catch
	{
		if ($failifempty -eq $false)
		{
			$value = $default
		}
		else
		{
			if (!$emptyattributefailmessage)
			{
				$emptyattributefailmessage = "Get-AnsibleParam: Missing required argument: $name"
			}
			Fail-Json -obj $resultobj -message $emptyattributefailmessage
		}
		
	}
	
	# If $value -eq $null, the parameter was unspecified by the user (deliberately or not)
	# Please leave $null-values intact, modules need to know if a parameter was specified
	# When $value is already an array, we cannot rely on the null check, as an empty list
	# is seen as null in the check below
	if ($value -ne $null -or $value -is [array])
	{
		if ($type -eq "path")
		{
			# Expand environment variables on path-type
			$value = Expand-Environment($value)
			# Test if a valid path is provided
			if (-not (Test-Path -IsValid $value))
			{
				$path_invalid = $true
				# could still be a valid-shaped path with a nonexistent drive letter
				if ($value -match "^\w:")
				{
					# rewrite path with a valid drive letter and recheck the shape- this might still fail, eg, a nonexistent non-filesystem PS path
					if (Test-Path -IsValid $(@(Get-PSDrive -PSProvider Filesystem)[0].Name + $value.Substring(1)))
					{
						$path_invalid = $false
					}
				}
				if ($path_invalid)
				{
					Fail-Json -obj $resultobj -message "Get-AnsibleParam: Parameter '$name' has an invalid path '$value' specified."
				}
			}
		}
		elseif ($type -eq "str")
		{
			# Convert str types to real Powershell strings
			$value = $value.ToString()
		}
		elseif ($type -eq "bool")
		{
			# Convert boolean types to real Powershell booleans
			$value = $value | ConvertTo-Bool
		}
		elseif ($type -eq "int")
		{
			# Convert int types to real Powershell integers
			$value = $value -as [int]
		}
		elseif ($type -eq "float")
		{
			# Convert float types to real Powershell floats
			$value = $value -as [float]
		}
		elseif ($type -eq "list")
		{
			if ($value -is [array])
			{
				# Nothing to do
			}
			elseif ($value -is [string])
			{
				# Convert string type to real Powershell array
				$value = $value.Split(",").Trim()
			}
			elseif ($value -is [int])
			{
				$value = @($value)
			}
			else
			{
				Fail-Json -obj $resultobj -message "Get-AnsibleParam: Parameter '$name' is not a YAML list."
			}
			# , is not a typo, forces it to return as a list when it is empty or only has 1 entry
			write-output $value
		}
	}
	
	Write-Output $value
}

#Alias Get-attr-->Get-AnsibleParam for backwards compat. Only add when needed to ease debugging of scripts
If (!(Get-Alias -Name "Get-attr" -ErrorAction SilentlyContinue))
{
	New-Alias -Name Get-attr -Value Get-AnsibleParam
}

# Helper filter/pipeline function to convert a value to boolean following current
# Ansible practices
# Example: $is_true = "true" | ConvertTo-Bool
Function ConvertTo-Bool
{
	param (
		[parameter(valuefrompipeline = $true)]
		$obj
	)
	
	$boolean_strings = "yes", "on", "1", "true", 1
	$obj_string = [string]$obj
	
	if (($obj -is [boolean] -and $obj) -or $boolean_strings -contains $obj_string.ToLower())
	{
		Write-Output $true
	}
	else
	{
		Write-Output $false
	}
}

Function Parse-Args($arguments, $supports_check_mode = $false)
{
	$params = New-Object psobject
	If ($arguments.Length -gt 0)
	{
        $params = Get-Content $arguments[0] -raw | ConvertFrom-Json -AsHashtable
	}
	Else
	{
		$params = $complex_args
	}
	$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
	If ($check_mode -and -not $supports_check_mode)
	{
		Exit-Json @{
			skipped = $true
			changed = $false
			msg	    = "remote module does not support check mode"
		}
	}
	write-output $params
}

#Alias Get-attr-->Get-AnsibleParam for backwards compat. Only add when needed to ease debugging of scripts
If (!(Get-Alias -Name "Get-attr" -ErrorAction SilentlyContinue))
{
	New-Alias -Name Get-attr -Value Get-AnsibleParam
}


##endregion


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
$SecondaryFileMaxSize = Get-AnsibleParam -obj $params -name "secondaryfilemaxsize" -type "int"
$SecondaryFileCount = Get-AnsibleParam -obj $params -name "secondaryfilecount" -type "int"
$DefaultFileGroup = Get-AnsibleParam -obj $params -name "defaultfilegroup" -type "str" -ValidateSet "primary", "secondary"

$result = @{
	changed   = $false
	message = ''
}
Exit-Json $result
#region test import dbatools module
try
{
	Import-Module dbatools -ErrorAction stop
	
}
catch
{
	Fail-Json -obj $result -message "The module dbatools is not present in the environment. Please install before running this task."
}
## Region generate credential  so that this becomes the base for connecting to the SQL Instance.
[string]$credusername = $dbausername
[string]$credpassword = $dbapassword
[securestring]$secStringPassword = ConvertTo-SecureString $credpassword -AsPlainText -Force
[pscredential]$dbacredObject = New-Object System.Management.Automation.PSCredential ($dbausername, $secStringPassword)
##endregion 

#region  attempt to connect to sqlinstance
try
{
	Connect-DbaInstance -SqlInstance $sqlinstance -SqlCredential $dbacredObject 
}
catch
{
	Fail-Json -obj $result -message "There was a failure connecting to the sqlserver instance. The error message was ($_.exception)"
}

#endregion


$collection = @() #build a data collection for structureddata
$badcollection = @()
if ($diff_mode)
{
	$result.diff = @{ }
}
$testdatabasepresent = Get-DbaDatabase -SqlInstance $sqlinstance -SqlCredential $dbacredObject -Database $database

if ($testdatabasepresent)
{
	$databasepresent = $true
}
else
{
	$databasepresent = $false
}

if ($state -eq 'present')
{
	
	if (!$databasepresent)
	{
		#region creates a generic hash table that fills out the parameters from the yaml to new-dbadatabase cmdlet.
		$dbaparams = @{
			name	    = $name;
			sqlinstance = $sqlinstance;
			erroraction = 'stop'
		}
		
		if ($collation)
		{
			$dbaparams.add('collation', $collation)
		}
		
		if ($recoverymodel)
		{
			$dbaparams.add('recoverymodel', $recoverymodel)
		}
		
		if ($DataFilePath)
		{
			$dbaparams.add('datafilepath', $DataFilePath)
		}
		
		if ($LogFilePath)
		{
			$dbaparams.add('logfilepath', $LogFilePath)
		}
		
		if ($PrimaryFilesize)
		{
			$dbaparams.add('primaryfilesize', $PrimaryFilesize)
		}
		
		if ($PrimaryFileGrowth)
		{
			$dbaparams.Add('primaryfilegrowth', $PrimaryFileGrowth)
		}
		
		if ($primaryFilemaxsize)
		{
			$dbaparams.add('primaryfilemaxsize', $PrimaryFileMaxSize)
		}
		
		if ($logsize)
		{
			$dbaparams.add('logsize', $LogSize)
		}
		
		if ($LogGrowth)
		{
			$dbaparams.add('loggrowth', $LogGrowth)
		}
		
		if ($LogMaxSize)
		{
			$dbaparams.add('logmaxsize', $LogMaxSize)
		}
		
		if ($SecondaryFilesize)
		{
			$dbaparams.add('secondaryfilesize', $SecondaryFilesize)
		}
		
		if ($SecondaryFileGrowth)
		{
			$dbaparams.add('secondaryfilegrowth', $SecondaryFileGrowth)
		}
		
		if ($SecondaryFileMaxSize)
		{
			$dbaparams.add('secondaryfilemaxsize', $SecondaryFileMaxSize)
		}
		$result.changed = $true #set to true here to accomodate for checkmode.
		#endregion
		if (-not ($checkmode))
		{
			
			#this allows  for dry runs
			
			try
			{
				New-DbaDatabase @dbaparams
				$result.message = "The database $name was created successfully on $sqlinstance"
				
			}
			catch
			{
				$result.change = $false
				Fail-Json -obj $result -message "Error was this $Error[0]"
			}
			
		}
	}else{
		$message = "The database $database is already present on the SQL Instance $sqlinstance  "
	}
}

if ($state -eq 'absent')
{
	if ($databasepresent)
	{
		if (-not ($checkmode)) 
		{
			#this allows  for dry runs
			try
			{
				Remove-DbaDatabase -database $database -SqlInstance $sqlinstance 
				$result.changed = $true
				$result.message = "Removed the Database $name from sql instance $sqlinstance "
				
			}
			catch
			{
				Fail-Json -obj $result -message "Error was this $Error[0]"
			}
			
		}
	}
}
Exit-Json $result


# Reference
# https://docs.ansible.com/ansible/2.6/dev_guide/developing_modules_general_windows.html
# https://docs.ansible.com/ansible/2.4/dev_guide/developing_modules_general_windows.html