# ansible.dbatools.collection
The Ansible dba tools collection is Ansible automation which is meant to be run locally to manage Microsoft SQL Server. It is based off the popular  [dbatools](https://github.com/sqlcollaborative/dbatools) PowerShell Module. Currently the Ansible Collection will be developed using dbatools v1.0.145.
In addition to this being used on the local machine (with PowerShell and dbatools installed) it can also be used in Ansible Execution Environments. This can then be used in AWX v19.1.0+

Currently the collection will accomodate for the following use cases:

* SQL Server facts
* Backup Restore Activity 
* Management of Databases
* User / Login Management

This is just for starters. 

# TODO:
* Add support for Kerberos. At this time, in order to connect to a SQL Instance the username must be a local user.  This is something that needs to be experimented against.

