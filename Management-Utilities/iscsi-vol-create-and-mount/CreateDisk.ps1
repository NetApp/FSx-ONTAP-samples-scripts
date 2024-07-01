[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='This script intentinally uses Write-Host to display messages to the user.')]
#### Getting param ####
param(
[Parameter(Mandatory=$true,HelpMessage="Enter FSxN filesystem management IP")]
[string]$ip,
[Parameter(Mandatory=$true,HelpMessage="Enter FSxN username")]
[string]$user,
[Parameter(Mandatory=$true,HelpMessage="Enter FSx filesystem password")]
[SecureString]$password,
[Parameter(Mandatory=$true,HelpMessage="Enter volume size (in GB)")]
[string]$volSize,
[Parameter(Mandatory=$true,HelpMessage="Enter drive letter")]
[string]$drive_letter,
[Parameter(Mandatory=$true,HelpMessage="Create parttition and format disk? return y/n (default no)")]
[ValidateSet('yes','no', 'y', 'n')]
[string]$format_disk)

Write-Host "Getting disks numbers before startig..." -ForegroundColor yellow
$totaldisks = (get-disk | Sort-Object -Property number | Select-Object -Last 1 -ExpandProperty number)
Write-Host "Getting local disks before startig..." -ForegroundColor yellow
Write-Host "There are $totaldisks disks" -ForegroundColor yellow

$vol_number= get-random -Minimum 1 -Maximum 10000
$vol_name = "vol_drive_" + $vol_number
$lun_name = "drive_" + $vol_number
$igroup_name = "winhost_ig_" + $vol_number

#### check if letter drive already in used and in the correct format ####
if($drive_letter.Length -gt 1)
{
 Write-Host "Drive letter not in the correct format" -ForegroundColor Red
 break
}
if($drive_letter.Length -gt 1)
{
 Write-Host "Drive letter not in the correct format" -ForegroundColor Red
 break
}
if (!($drive_letter -match '[a-zA-Z]'))
{
 Write-Host "Drive letter not in the correct format" -ForegroundColor Red
 break
}
if(Test-Path $drive_letter':')
{
 Write-Host "Drive letter already in use" -ForegroundColor Red
 break
}

##### Enable MPIO and Start iSCSI Service ####
Write-Host "Enabling MPIO" -ForegroundColor Yellow
Enable-MSDSMAutomaticClaim -BusType iSCSI -Confirm
Write-Host "Starting iSCSI service and setting on automatic status" -ForegroundColor Yellow
try {
 Start-Service -Name msiscsi -ErrorAction Stop
}
catch {
 Write-Host "Failed start msiscsi, due to: $_" -ForegroundColor Red
 break
}

Set-Service -Name msiscsi -StartupType Automatic

#### Connect to FSX ####
Write-Host "Connectiong to FSx filesystem" -ForegroundColor Yellow
$credntials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password
try {
 Connect-NcController $ip -Credential $credntials -ErrorAction Stop
}
catch {
 Write-Host "Failed connect to FSx filesystem, due to: $_" -ForegroundColor Red
 break
}

Write-Host "Creating volume" -ForegroundColor Yellow
try {
New-Ncvol -Name $vol_name -Aggregate aggr1 -Size $volSize'g' -JunctionPath /$vol_name -SecurityStyle ntfs -ErrorAction stop
}
catch {
 Write-Host "Failed create volume, due to: $_" -ForegroundColor Red
 break
}

Write-Host "Creating LUN" -ForegroundColor Yellow
try {
New-NcLun -Size $volSize'g' -OsType windows -Path /vol/$vol_name/$lun_name -Unreserved -ErrorAction stop
}
catch {
 Write-Host "Failed create LUN, due to: $_" -ForegroundColor Red
 break
}

Write-Host "Creating Igroup" -ForegroundColor Yellow
try {
New-NcIgroup -Name $igroup_name -Protocol iscsi -Type windows -ErrorAction stop
}
catch {
 Write-Host "Failed create Igroup, due to: $_" -ForegroundColor Red
 break
}


#### map server iqn to lun ####
Write-Host "Mapping  LUN  to Igroup" -ForegroundColor Yellow

$iqn = Get-NcHostIscsiAdapter | sort-object iqn | ForEach-Object {$_.iqn}
try {
Add-NcIgroupInitiator -Initiator $iqn -Name $igroup_name -ErrorAction stop
}
catch {
 Write-Host "Failed map server iqn to igroup, due to: $_" -ForegroundColor Red
 break
}

Write-Host "Mapping  LUN  to Igroup" -ForegroundColor Yellow
try {
Add-NcLunMap -Path /vol/$vol_name/$lun_name -InitiatorGroup $igroup_name -ErrorAction stop
}
catch {
 Write-Host "Failed map LUN to igroup, due to: $_" -ForegroundColor Red
 break
}


### create new target ####
Write-Host "Creating new target" -ForegroundColor Yellow
$iscsi_address = get-ncnetinterface -Name iscsi_* |  sort-object address | ForEach-Object {$_.address}
try {
New-IscsiTargetPortal -TargetPortalAddress $iscsi_address[0] -ErrorAction stop
New-IscsiTargetPortal -TargetPortalAddress $iscsi_address[1] -ErrorAction stop
}
catch {
 Write-Host "Failed to add new target, due to: $_" -ForegroundColor Red
 break
}

try {
Get-IscsiTarget | Connect-IscsiTarget -IsMultipathEnabled $true -ErrorAction stop
}
catch {
 Write-Host "Failed to connect to the new target, due to: $_" -ForegroundColor Red
 break
}


#### create new ISCSI disk ####
Write-host 'Online, Initialize and format disks' -ForegroundColor Yellow
#### find free disk ####
Start-Sleep -Seconds 10
$maxRetries = 5
$counter = 0
$diskNum = (get-disk | Sort-Object -Property number | Select-Object -Last 1 -ExpandProperty number)
while ($diskNum -eq $totaldisks -and $counter -lt $maxRetries)
{

  Write-host 'retry..'
  $counter += 1
  Start-Sleep -Seconds 10
  $diskNum = (get-disk | Sort-Object -Property number | Select-Object -Last 1 -ExpandProperty number)
}

if($counter -eq $maxRetries)
{
  Write-host 'Max retries occured...' -ForegroundColor Red
  break
}

### refresh disk ####
Get-PSDrive | Out-Null
try {
set-disk -Number $diskNum -IsOffline $false -ErrorAction SilentlyContinue
}
catch {
 Write-Host "Failed set disk to online, due to: $_" -ForegroundColor Red -ErrorAction stop
 break
}

try {
set-disk -Number $diskNum -IsReadOnly $false
}
catch {
 Write-Host "Failed set disk to RW, due to: $_" -ForegroundColor Red -ErrorAction stop
 break
}

if($format_disk -eq "yes" -or $format_disk -eq "y")
{
 Write-host "Starting Initialize and format disks"
 Initialize-Disk -Number $diskNum  -PartitionStyle MBR
 New-Partition -DiskNumber $diskNum -UseMaximumSize -IsActive -DriveLetter $drive_letter | Format-Volume
}

Write-Host "Done creating new FSx disk" -ForegroundColor green
