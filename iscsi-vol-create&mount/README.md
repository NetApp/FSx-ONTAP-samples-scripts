
# Mount FSxN ISCSI volume on EC2 windows
Powershell automation for creation FSxN ISCSI volume and mount it on ec2 instance.

### Prerequisites
* Connection between FSxN and ec2 windows.
* TCP ports should be open between the ec2 windows and the FSxN: 
    `22`,
    `443`,
    `3260`
## Deployment
There are two PowerShell scripts:

```text
  1. Preinstall.ps1 - It installs ONTAP PowerShell and Multiple-IO if they haven't been installed. (no user input needed)
  2. CreateDisk.ps1 - It creates volume, lun, igroup and mapped to the server. 
```
## User Input

Parameter | Description | 
--- | --- | 
IP | FSxN filesystem management IP |
User | Fsxadmin user or user with lun and volume creation privileges | 
Password | User Password |
Vol_size | Disk size (GB) |
Drive_letter | Drive letter to map the disk |
Format_disk | (Boolean – Yes or no) – The user can choose whether to create a partition and format the disk. |

## Installation
 There are two ways to run the scripts and set the params:

```text
  1. in PowerShell ISE 
  2. CMD command: .\createDisk.ps1  <ip> <user> <password> <vol_size> <drive_letter> <formatdisk>
```
    
## Notes
  1.  Reboot is required for the Multiple-IO module - The instance will be restarted automatically once the Preinstall script is complete
  2. On each run, the script creates only one disk
  3. Every step in the script has an error handling component, so if a step fails, the script will stop and print the error message.
## Screenshots

![Screenshots 1](./images/image1.png)
![Screenshots 2](./images/image2.png)
![Screenshots 3](./images/image3.png)
![Screenshots 4](./images/image4.png)

