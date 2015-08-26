# Dev Environment Installation (bootstrap)

## Description
Powershell script to bootstrap python and all dependencies for the Salt Minion. Useful for development purposes. Git and all salt dependencies are installed. Salt is cloned to "C:\Salt-Dev". Configuration files are placed in "C:\Salt". All executables are downloaded from [SaltStack's win-repo](https://repo.saltstack.com/windows/dependencies/). 

Source and target directories can be changed by editing variables towards the top. of the file.

You'll still need to edit the minion configuration file in order to run salt-minion.

## Notes
If the script fails to run, you may need to change the execution policy. Run the following in powershell:
Set-ExecutionPolicy RemoteSigned

## Warning
This script will overwrite existing config files in C:\salt.
