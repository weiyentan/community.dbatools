# community.dbatools.database
Manages SQL Server databases using dbatools as a backend.

* [Synopsis](#Synopsis)
* [Requirements](#Requirements)
* [Parameters](#Parameters)
* [Notes](#Notes)
* [Examples](#Example)

## Synopsis
* Tasks to manage databases using [dbatools](https://github.com/sqlcollaborative/dbatools) module. The tasks involved will be adding/removing SQL databases and the settings surrounding them.

## Requirements 
* PowerShell module [dbatools](https://github.com/sqlcollaborative/dbatools) needs to be installed on the Ansible host/execution environment.

## Parameters
|Parameters|Default| Choices|Required|Description|Example|
|:---:|:---:|:--:|:---:|:---:|:---:|
| `database`|""|""| Yes| The database that will be created/removed | Assets
| `sqlinstance` |""| ""|Yes |The instance that you will be targetting against| SQLServer
| `username` |""| "" | Yes | The username that you will be using to connect to the database| domain\johndoe , bob |
|`password`|"" | ""| Yes| The password that you want to use to connect to the database | password
|`state` | "" | absent , present | Yes | Whether to add or remove database | present
|`collation`| "" |""| No | The database collation, if not supplied the default server collation will be used.| SQL_Latin_General_CP1_CI_AS
|`recoverymodel`| Simple | Simple,Full, Bulklogged | No | Recovery model for database. If omited, Simple mode is chosen. | 'Bulklogged'
|`datafilepath`| ""| ""| No | The location that data files will be placed, otherwise the default SQL Server data path will be used. | 'E:\SQLData'
|`logfilepath`| ""| "" | No | The location where the log files will be placed , otherwise SQL Server log files will be used" | 'L:\SQLData\LogFiles
|`primaryfilesize`|""|""|No |The size in MB for the Primary file. If this is less than the primary file size for the model database, then the model size will be used instead.| 20|
|`primaryfilegrowth`|""|""|No| The size in MB that the Primary file will autogrow by.| 10
|`primaryfilemaxsize`| ""| ""| No| The maximum permitted size in MB for the Primary File. If this is less than the primary file size for the model database, then the model size will be used instead.| 100
|`logsize`| ""| ""| No| The size in MB that the Transaction log will be created.| 10
| `loggrowth`| ""|""| No | The amount in MB that the log file will be set to autogrow by.| 10
|`secondaryfilegrowth` |""|""|No|The amount in MB that the Secondary files will be set to autogrow by| 100
|`secondaryfilemaxSize`| ""|""|No| The maximum permitted size in MB for the Secondary data files to grow to. Each file added will be created with this max size setting.| 60
|`secondaryfilecount`| ""|""|No | The number of files to create in the Secondary filegroup for the database.| 5
|`defaultfilegroup` | ""|Primary,Secondary|No | Sets the default file group. Either primary or secondary.| Primary|
## Examples

```yaml
---
  - name: Playbook to create database
    hosts: localhost
    connection: local
    gather_facts: no
    tasks:
      - name: create database AssetDatabase
        community.dbatools.database:
          database: AssetDatabase
          sqlinstance: MSSQL
          primaryfilegrowth: 10
          primaryfilesize: 100
          logfilepath: 'e:\sqldata'
          username: "{{ dbatools_username }}"
          password: "{{ dbatools_password }}"
          state: present
```

This playbook will create the database AssetDatabase from the instance MSSQL with the options:

* primary file growth set to 100
* primary file size 10
* log file path set to e:\sqldata



```yaml
---
  - name: Playbook to remove database
    hosts: localhost
    connection: local
    gather_facts: no
    tasks:
      - name: remove database AssetDataase
        community.dbatools.database:
          database: AssetDatabase
          sqlinstance: MSSQL
          username: "{{ dbatools_username }}"
          password: "{{ dbatools_password }}"
          state: absent
```

This will remove the database AssetDatabase from the SQL Instance MSSQL.