<powershell>
# This script is used to install and configure FSx for Windows File Server
#### Process param ####
$secretId="AWS secret ARN, e.g arn:aws:secretsmanager:us-east-1:111222333444:secret:MySecret-123456"
$ip="Fsx admin ip, e.g. 111.22.33.44"
$volName="Fsx volume name, e.g. iscsiVol"
$volSize="volume size in GB, e.g 100"
$drive_letter="drive letter to use, e.g. d"

# Default value is fsx, but you can change it to any other value according to yours FSx for ONTAP SVM name
$svm_name="fsx"

function unInstall {
   param (
      [bool]$printUninstallConnect,
      [string]$ip,
      [System.Management.Automation.PSCredential]$credntials,
      [string]$svm_name
   )
   if( $printUninstallConnect -eq $true ) {
      @("Connect-NcController $ip -Credential $credntials -Vserver $svm_name -ErrorAction Stop") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   . $uninstallFile
}

# default values
# All FSxN instances are created with the user 'fsxadmin' which can't be changed
# The script will create a log file in the Administrator home directory
# The script will create an uninstall script in the Administrator home directory
$user="fsxadmin"
$currentLogPath="C:\Users\Administrator\install.log"
$uninstallFile="C:\Users\Administrator\uninstall.ps1"

$password=Get-SECSecretValue -SecretId "$secretId" -Select "SecretString"


if( $password -eq $null -or $password -eq "" ) {
   Write-Output "Failed to get data from Secrets Manager, exiting..." >> $currentLogPath 
   write-host "Failed to get data from Secrets Manager, exiting..." -ForegroundColor Red
   EXIT 1
}

Write-Output "Get data from Secrets Manager, successfully" >> $currentLogPath 
write-host "Get data from Secrets Manager, successfully" -ForegroundColor Green
$totaldisks = (get-disk | Sort-Object -Property number | Select-Object -Last 1 -ExpandProperty number)

#### Installing ONTAP module #####
$m = "NetApp.ONTAP"
$path= "HKLM:\Software\UserData"
$itemName = "FSXnRunStep"

if(!(Get-Item $Path -ErrorAction SilentlyContinue)) {
   New-Item $Path
   New-ItemProperty -Path $Path -Name $itemName -Value 0 -PropertyType dword
}

$runStep = Get-ItemProperty -Path $path -Name $itemName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $itemName

if($runStep -eq 0 -or (Get-Module | Where-Object {$_.Name -ne $m})) {
   Write-Output "Write-Host ""Uninstall FSxn configuration""" >> $uninstallFile
   Write-Output "# FSXn uninstall:" >> $uninstallFile
   Write-Output "Installing/ Import ONTAP module" >> $currentLogPath 
   Write-Host "Installing/ Import ONTAP module" -ForegroundColor Yellow

   if (Get-Module | Where-Object {$_.Name -ne 'NuGet'}) {
      Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
      @("Uninstall-PackageProvider -Name NuGet -Force") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   Write-Output "Validate if module $m imported, otherwise import it" >> $currentLogPath 
   write-host "Validate if module $m imported, otherwise import it" -ForegroundColor Yellow
   if (Get-Module | Where-Object {$_.Name -eq $m}) {
      write-host "Module $m is already imported."
   }
   else {

      # If module is not imported, but available on disk then import
      if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
         Write-Output "Import module $m." >> $currentLogPath 
         write-host "Import module $m."
         Import-Module $m -Verbose
         Set-ItemProperty -Path $path -Name $itemName -Value 1
      }
      else {

         # If module is not imported, not available on disk, but is in online gallery then install and import
         if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
            Install-Module -Name $m -Force -Verbose -Scope CurrentUser
            Write-Output "Import module $m." >> $currentLogPath 
            write-host "Import module $m."
            Import-Module $m -Verbose
            Set-ItemProperty -Path $path -Name $itemName -Value 1
            @("Uninstall-PackageProvider -Name $m -Force") + (Get-Content $uninstallFile) | Set-Content $uninstallFile   
         }
         else {
            # If the module is not imported, not available and not in the online gallery then abort
            Write-Output "Failed installing Module $m, exiting...." >> $currentLogPath 
            write-host "Failed installing Module $m, exiting...." -ForegroundColor Red
            # run uninstall script
            . $uninstallFile
            EXIT 1
         }
      }
   }
}

$runStep = Get-ItemProperty -Path $path -Name $itemName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $itemName

if($runStep -eq 1) {

   $printUninstallConnect = $false
   ### Install MPIO ####
   Write-Output "Installing Multipath-IO windows feature" >> $currentLogPath 
   Write-Host "Installing Multipath-IO windows feature" -ForegroundColor Yellow
   $res = Get-WindowsFeature -Name Multipath-IO
   if(($res.Installed))
   {
      Write-Output "Windows feature Multipath-IO already installed" >> $currentLogPath 
      Write-Output "IDone.." >> $currentLogPath 
      write-host "Windows feature Multipath-IO already installed" -ForegroundColor Green
      write-host "Done.." -ForegroundColor Green
   }
   else {
      # restart the instance after installing MPIO
      Install-WindowsFeature -name Multipath-IO -Restart 
      @("Uninstall-PackageProvider -Name Multipath-IO -Force") + (Get-Content $uninstallFile) | Set-Content $uninstallFile   
   }

   $vol_number= get-random -Minimum 1 -Maximum 10000
   $vol_name = $volName
   $lun_name = $volName + "_" + $vol_number
   $igroup_name = "winhost_ig_" + $vol_number
   
   #### check if letter drive already in used and in the correct format ####
   if($drive_letter.Length -gt 1 -or !($drive_letter -match '[a-zA-Z]'))
   {
      Write-Output "Drive letter: $drive_letter is not in the correct format" >> $currentLogPath 
      Write-Host "Drive letter: $drive_letter is not in the correct format" -ForegroundColor Red
      . $uninstallFile
      break
   }
   if(Test-Path $drive_letter':')
   {
      Write-Output "Drive letter: $drive_letter already in use" >> $currentLogPath 
      Write-Host "Drive letter: $drive_letter already in use" -ForegroundColor Red
      . $uninstallFile
      break
   }

   ##### Enable MPIO and Start iSCSI Service ####
   Write-Output "Enabling MPIO" >> $currentLogPath 
   Write-Host "Enabling MPIO" -ForegroundColor Yellow
   Enable-MSDSMAutomaticClaim -BusType iSCSI -Confirm
   @("Disable-MSDSMAutomaticClaim -BusType iSCSI -Confirm") + (Get-Content $uninstallFile) | Set-Content $uninstallFile   
   Write-Output "Starting iSCSI service and setting on automatic status" >> $currentLogPath 
   Write-Host "Starting iSCSI service and setting on automatic status" -ForegroundColor Yellow
   try {
      Start-Service -Name msiscsi -ErrorAction Stop
      @("Stop-Service  -Name msiscsi -Force") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   catch {
      Write-Output "Failed start msiscsi, due to: $_" >> $currentLogPath 
      Write-Host "Failed start msiscsi, due to: $_" -ForegroundColor Red
      . $uninstallFile
      break
   }

   Set-Service -Name msiscsi -StartupType Automatic

   #### Connect to FSX ####
   Write-Host "Connectiong to FSx filesystem" -ForegroundColor Yellow
   $PWord = ConvertTo-SecureString -String $password -AsPlainText -Force
   $credntials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $PWord
   try {
      $controller = Connect-NcController $ip -Credential $credntials -Vserver $svm_name -ErrorAction Stop
   }
   catch {
      Write-Output "Failed connect to FSXn filesystem, due to: $_" >> $currentLogPath 
      Write-Host "Failed connect to FSXn filesystem, due to: $_" -ForegroundColor Red
      . $uninstallFile
      break
   }

   Write-Output "Creating volume: $vol_name" >> $currentLogPath 
   Write-Host "Creating volume: $vol_name" -ForegroundColor Yellow

   try {
      New-Ncvol -Name $vol_name -Aggregate aggr1 -Size $volSize'g' -JunctionPath /$vol_name -SecurityStyle ntfs -ErrorAction stop
      @("Remove-NcVol $vol_name") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
      @("Set-NcVol $vol_name -offline") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
      $printUninstallConnect = $true
   }
   catch {
      Write-Output "Failed create volume, due to: $_" >> $currentLogPath 
      Write-Host "Failed create volume, due to: $_" -ForegroundColor Red
      unInstall $printUninstallConnect $ip $credntials $svm_name
      break
   }

   Write-Output "Creating LUN" >> $currentLogPath 
   Write-Host "Creating LUN" -ForegroundColor Yellow
   try {
      New-NcLun -Size $volSize'g' -OsType windows -Path /vol/$vol_name/$lun_name -Unreserved -ErrorAction stop
      @("Remove-NcLun $lun_name -force") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   catch {
      Write-Output "Failed create LUN, due to: $_" >> $currentLogPath 
      Write-Host "Failed create LUN, due to: $_" -ForegroundColor Red
      unInstall $printUninstallConnect $ip $credntials $svm_name
      break
   }

   Write-Output "Creating Igroup" >> $currentLogPath 
   Write-Host "Creating Igroup" -ForegroundColor Yellow
   try {
      New-NcIgroup -Name $igroup_name -Protocol iscsi -Type windows -ErrorAction stop
      @("Remove-NcIgroup -Name $igroup_name -force") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   catch {
      Write-Output "Failed create Igroup, due to: $_" >> $currentLogPath 
      Write-Host "Failed create Igroup, due to: $_" -ForegroundColor Red
      unInstall $printUninstallConnect $ip $credntials $svm_name
      break
   }

   #### map server iqn to lun ####
   Write-Output "Add Igroup initiator" >> $currentLogPath 
   Write-Host "Add Igroup initiator" -ForegroundColor Yellow

   $iqn = Get-NcHostIscsiAdapter | sort-object iqn | ForEach-Object {$_.iqn}
   try {
      Add-NcIgroupInitiator -Initiator $iqn -Name $igroup_name -ErrorAction stop
      @("Remove-NcIgroupInitiator -Name $igroup_name -Initiator $iqn -force") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
      
   }
   catch {
      Write-Output "Failed to add igroup initiator, due to: $_" >> $currentLogPath 
      Write-Host "Failed to add igroup initiator, due to: $_" -ForegroundColor Red
      unInstall $printUninstallConnect
      break
   }

   Write-Output "Mapping LUN to Igroup" >> $currentLogPath 
   Write-Host "Mapping LUN to Igroup" -ForegroundColor Yellow
   try {
      Add-NcLunMap -Path /vol/$vol_name/$lun_name -InitiatorGroup $igroup_name -ErrorAction stop
      @("Remove-NcLunMap -Path /vol/$vol_name/$lun_name -InitiatorGroup $igroup_name -force") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   catch {
      Write-Output "Failed mapping LUN to igroup, due to: $_" >> $currentLogPath 
      Write-Host "Failed mapping LUN to igroup, due to: $_" -ForegroundColor Red
      unInstall $printUninstallConnect
      break
   }


   ### create new target ####
   Write-Output "Creating new target" >> $currentLogPath 
   Write-Host "Creating new target" -ForegroundColor Yellow
   $iscsi_address = get-ncnetinterface -Name iscsi_* |  sort-object address | ForEach-Object {$_.address}
   try {
      New-IscsiTargetPortal -TargetPortalAddress $iscsi_address[0] -ErrorAction stop
      New-IscsiTargetPortal -TargetPortalAddress $iscsi_address[1] -ErrorAction stop
      @("Remove-IscsiTargetPortal -TargetPortalAddress $iscsi_address[1]") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
      @("Remove-IscsiTargetPortal -TargetPortalAddress $iscsi_address[0]") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   catch {
      Write-Output "Failed to add new target, due to: $_" >> $currentLogPath 
      Write-Host "Failed to add new target, due to: $_" -ForegroundColor Red
      unInstall $printUninstallConnect
      break
   }

   Write-Output "Connect to the new target" >> $currentLogPath 
   try {
      Get-IscsiTarget | Connect-IscsiTarget -IsMultipathEnabled $true -ErrorAction stop
      @("Get-IscsiTarget | Disconnect-IscsiTarget") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   catch {
      Write-Output "Failed to connect to the new target, due to: $_" >> $currentLogPath 
      Write-Host "Failed to connect to the new target, due to: $_" -ForegroundColor Red
      unInstall $printUninstallConnect
      break
   }
   @("Connect-NcController $ip -Credential $credntials -Vserver $svm_name -ErrorAction Stop") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   
   #### create new ISCSI disk ####
   Write-Output "Online, Initialize and format disks" >> $currentLogPath 
   Write-host 'Online, Initialize and format disks' -ForegroundColor Yellow
   #### find free disk ####
   $maxRetries = 5
   $counter = 0
   
   do {
      $diskNum = (get-disk | Sort-Object -Property number | Select-Object -Last 1 -ExpandProperty number)
      $counter += 1
      Start-Sleep -Seconds 10
   } 
   while ($diskNum -eq $totaldisks -and $counter -lt $maxRetries)

   ### refresh disk ####
   Get-PSDrive | Out-Null
   try {
      set-disk -Number $diskNum -IsOffline $false
   }
   catch {
      Write-Output "Failed set disk to online, due to: $_" >> $currentLogPath 
      Write-Host "Failed set disk to online, due to: $_" -ForegroundColor Red -ErrorAction stop
      break
   }

   Write-Output "Set disk to have Read/Write permissions" >> $currentLogPath 
   Write-host 'Set disk to have Read/Write permissions' -ForegroundColor Yellow
   try {
      set-disk -Number $diskNum -IsReadOnly $false
   }
   catch {
      Write-Output "Failed set disk to RW, due to: $_" >> $currentLogPath 
      Write-Host "Failed set disk to RW, due to: $_" -ForegroundColor Red -ErrorAction stop
      break
   }

   try {
      Write-Output "Starting Initialize and format disk number: $diskNum" >> $currentLogPath 
      Write-host "Starting Initialize and format disk number: $diskNum" -ForegroundColor Yellow
      Initialize-Disk -Number $diskNum -PartitionStyle MBR
      New-Partition -DiskNumber $diskNum -UseMaximumSize -IsActive -DriveLetter $drive_letter | Format-Volume
   }
   catch {
      Write-Output "Failed create new partition, due to: $_" >> $currentLogPath 
      Write-Host "Failed create new partition, due to: $_" -ForegroundColor Red  -ErrorAction stop
      break
   }
   Set-ItemProperty -Path $path -Name $itemName -Value 2
   Write-Output "Done creating new FSx disk, drive letter: $drive_letter" >> $currentLogPath 
   Write-Host "Done creating new FSx disk, drive letter: $drive_letter" -ForegroundColor Green
}
else {
   Write-Output "FSx disk already created" >> $currentLogPath 
   Write-Host "FSx disk already created" -ForegroundColor Green
}
Remove-Item -Path $uninstallFile -Force 
</powershell>
