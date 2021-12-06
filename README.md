# SD Card Copy Script

This is a bash script meant for copying data from one PLCNext SD card to multiple others without destroying the licenses contained on them. 

### Requirements

- This script was developed and tested on a Lubuntu machine, so Ubuntu based distros are recommended for use with this script

- This script requires rsync to run
- This script will disable udisks2 to preserve block device topology between mounts. The user will have to manual reenable this or reboot after running the script

### Usage

- Place the script in it's own empty folder
- run the script with "sudo bash ./script.sh"



