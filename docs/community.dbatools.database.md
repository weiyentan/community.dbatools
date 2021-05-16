# community.dbatools.database
Manages SQL Server databases using dbatools as a backend.

* [Synopsis](#Synopsis)
* [Requirements](#Requirements)
* [Parameters](#Parameters)
* [Notes](#Notes)
* [Examples](#Example)

## Synopsis
* Tasks to manage databases using [dbatools](https://github.com/sqlcollaborative/dbatools) module. This

## Requirements 
* PowerShell module [dbatools](https://github.com/sqlcollaborative/dbatools) needs to be installed on the Ansible host/execution environment.

## Parameters
|Parameters|Default| Choices|Required|Description|Example|
|:---:|:---:|:--:|:---:|:---:|:---:|
| `database`|""|""| Yes| The database that will be created/removed | Assets
| `instance` |""| ""|Yes |The instance that you will be targetting against| SQLServer
| `username` |""| "" | Yes | The username that you will be using to connect to the database| domain\johndoe , bob |
|`password`|"" | ""| Yes| The password that you want to use to connect to the database | password
| `type`   |standard | availability_group, standard| No |  The type of database to create | availailability_group
| `state` | "" | absent , present | Yes | Whether to add or remove database | present

## Examples


```yaml
---
  - name: Playbook to create database
    hosts: localhost
    connection: local
    gather_facts: no
    tasks:
      - name: create database 
        community.dbatools.database:
          database: AssetDatabase
          instance: MSSQL
          username: "{{ dbatools_username }}"
          password: "{{ dbatools_password }}"
          type: availability_group
          state: present
```
This playbook will create the database AssetDatabase from the instance MSSQL.

```yaml
---
  - name: Playbook to create database
    hosts: localhost
    connection: local
    gather_facts: no
    tasks:
      - name: create database 
        community.dbatools.database:
          database: AssetDatabase
          instance: MSSQL
          username: "{{ dbatools_username }}"
          password: "{{ dbatools_password }}"
          state: absent
```
This will remove the database AssetDatabase from the SQL Instance MSSQL.