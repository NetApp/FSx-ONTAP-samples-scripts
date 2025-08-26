<powershell>
# This script is used to install and configure FSx for Windows File Server
#### Process param ####
$secretId="AWS secret ARN, e.g arn:aws:secretsmanager:us-east-1:111222333444:secret:MySecret-123456"
$ip="Fsx admin ip, e.g. 111.22.33.44"
$volName="Fsx volume name, e.g. iscsiVol"
$volSize="volume size in GB, e.g 100"
$drive_letter="drive letter to use, e.g. d"

# Default value is fsxadmin
$user="fsxadmin"
# Default value is fsx
$svm_name="fsx"

# default values
# The script will create a log file and uninstall script
$currentLogPath="C:\Users\Administrator\install.log"
$uninstallFile="C:\Users\Administrator\uninstall.ps1"
$TIMEOUT=5

$password=Get-SECSecretValue -SecretId "$secretId" -Select "SecretString"

if (Test-Path $currentLogPath){ 
   Remove-Item -Path $currentLogPath -Force 
}

if( $null -eq $password -or $password -eq "" ) {
   Write-Output "Failed to get data from Secrets Manager, exiting..." >> $currentLogPath 
   write-host "Failed to get data from Secrets Manager, exiting..." -ForegroundColor Red
   EXIT 1
}

Write-Output "Get data from Secrets Manager, successfully" >> $currentLogPath 
write-host "Get data from Secrets Manager, successfully" -ForegroundColor Green
$totaldisks = (get-disk | Sort-Object -Property number | Select-Object -Last 1 -ExpandProperty number)

$path= "HKLM:\Software\UserData"
$itemName = "FSXnRunStep"

if(!(Get-Item $path -ErrorAction SilentlyContinue)) {
   New-Item $path
   New-ItemProperty -Path $path -Name $itemName -Value 0 -PropertyType dword
}

$runStep = Get-ItemProperty -Path $path -Name $itemName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $itemName
Write-Output "Write-Host ""Uninstall FSxn configuration""" >> $uninstallFile
Write-Output "# FSXn uninstall:" >> $uninstallFile

if($runStep -eq 0) {
   if (Get-Module | Where-Object {$_.Name -ne 'NuGet'}) {
      Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
      @("Uninstall-PackageProvider -Name NuGet -Force") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
         Set-ItemProperty -Path $path -Name $itemName -Value 1
}

$runStep = Get-ItemProperty -Path $path -Name $itemName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $itemName

if($runStep -eq 1) {

   ### Install MPIO ####
   Write-Output "Installing Multipath-IO windows feature" >> $currentLogPath 
   Write-Host "Installing Multipath-IO windows feature" -ForegroundColor Yellow
   $res = Get-WindowsFeature -Name Multipath-IO | Where-Object {$_.InstallState -eq "Installed"} 
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

   $vol_number = get-random -Minimum 1 -Maximum 10000
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

   #### Validate connection to FSX ####
   Write-Host "Connectiong to FSxN filesystem" -ForegroundColor Yellow
            
   $connectResult = curl.exe -X GET -k "https://$ip/api/cluster?fields=version" -u "${user}:${password}" | ConvertFrom-Json
   if ($null -eq $connectResult.version) {
      Write-Output "Failed connect to FSXn filesystem, due to: $connectResult.error.message" >> $currentLogPath 
      Write-Host "Failed connect to FSXn filesystem, due to: $connectResult.error.message" -ForegroundColor Red
      . $uninstallFile
      break
   }

   Write-Output "Creating volume: $vol_name" >> $currentLogPath 
   Write-Host "Creating volume: $vol_name" -ForegroundColor Yellow

   $jsonPayload = @"
   {
      \"name\": \"$vol_name\",
      \"size\": \"${volSize}g\",
      \"state\": \"online\",
      \"svm\": {
         \"name\": \"$svm_name\"
      },
      \"aggregates\": [{
         \"name\": \"aggr1\"
      }]
   }
"@
   $createVolumeResult = curl.exe -m $TIMEOUT -X POST -u "${user}:${password}" -k "https://$ip/api/storage/volumes" -d $jsonPayload | ConvertFrom-Json
   Start-Sleep -Seconds 10
   $jobId = $createVolumeResult.job.uuid
   $jobStatus = curl.exe -X GET -u "${user}:${password}" -k "https://$ip/api/cluster/jobs/$jobId" | ConvertFrom-Json
   if ($jobStatus.state -ne "success") {
      Write-Output "Failed create volume: $vol_name, due to: $($jobStatus.error)" >> $currentLogPath 
      Write-Host "Failed create volume: $vol_name, due to: $($jobStatus.error)" -ForegroundColor Red
      . $uninstallFile
      break
   }
   $volumeResult = curl.exe -m $TIMEOUT -X GET -u "${user}:${password}" -k "https://$ip/api/storage/volumes?name=${vol_name}&svm.name=${svm_name}" | ConvertFrom-Json
   $record = $volumeResult.records | Where-Object { $_.name -eq $vol_name }
   $volumeUUid = $record.uuid
   if ($null -eq $volumeUUid) {
      Write-Output "Failed create volume: $vol_name, aborting" >> $currentLogPath 
      Write-Host "Failed create volume: $vol_name, aborting" -ForegroundColor Red
      . $uninstallFile
      break
   }
   @("curl.exe -m $TIMEOUT -X DELETE -u `"${user}:${password}`" -k `"https://$ip/api/storage/volumes/$volumeUUid`"") + (Get-Content $uninstallFile) | Set-Content $uninstallFile

   Write-Output "Creating LUN: /vol/$vol_name/$lun_name" >> $currentLogPath 
   Write-Host "Creating LUN: /vol/$vol_name/$lun_name" -ForegroundColor Yellow

   $lunSize=0.9*$volSize
   $jsonPayload = @"
   {
      \"name\": \"/vol/$vol_name/$lun_name\",
      \"space\": {
         \"size\": \"${lunSize}GB\",
         \"scsi_thin_provisioning_support_enabled\": true
      },
      \"svm\": {
         \"name\": \"$svm_name\"
      },
      \"os_type\": \"windows\"
   }
"@
   curl.exe -m $TIMEOUT -X POST -u "${user}:${password}" -k "https://$ip/api/storage/luns" -d $jsonPayload 
   $lunResult = curl.exe -X GET -u "${user}:${password}" -k "https://$ip/api/storage/luns?fields=uuid&name=/vol/${vol_name}/$lun_name" | ConvertFrom-Json
   $record = $lunResult.records | Where-Object { $_.name -eq "/vol/$vol_name/$lun_name" }
   $lunUuid = $record.uuid
   if ($null -eq $lunUuid) {
      Write-Output "Failed create LUN: $lun_name, aborting" >> $currentLogPath 
      Write-Host "Failed create LUN: $lun_name, aborting" -ForegroundColor Red
      . $uninstallFile
      break
   }
   Write-Output "LUN created successfully with UUID: $lunUuid" >> $currentLogPath
   Write-Host "LUN created successfully with UUID: $lunUuid" -ForegroundColor Green
   @("curl.exe -m $TIMEOUT -X DELETE -u `"${user}:${password}`" -k `"https://$ip/api/storage/luns/$lunUuid`"") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   
   $iqn = (Get-InitiatorPort).NodeAddress | sort-object iqn 
   $iGroupResult=curl.exe -m $TIMEOUT -X GET -u "${user}:${password}" -k "https://$ip/api/protocols/san/igroups?svm.name=$svm_name&name=$igroup_name&initiators.name=$iqn&protocol=iscsi&os_type=windows" | ConvertFrom-Json
   $initiatorExists = $iGroupResult.num_records
   if ($initiatorExists -eq 0) {
      Write-Output "Creating Igroup" >> $currentLogPath 
      Write-Host "Creating Igroup" -ForegroundColor Yellow
      
      $jsonPayload = @"
      {
         \"protocol\": \"iscsi\",
         \"initiators\": [
         {
            \"name\": \"$iqn\"
         }
         ],
         \"os_type\": \"windows\",
         \"name\": \"$igroup_name\",
         \"svm\": {
            \"name\": \"$svm_name\"
         }
      }
"@
      curl.exe -m $TIMEOUT -X POST -u "${user}:${password}" -H "Content-Type: application/json" -k "https://$ip/api/protocols/san/igroups" -d $jsonPayload | ConvertFrom-Json
      $iGroupResult=curl.exe -m $TIMEOUT -X GET -u "${user}:${password}" -k "https://$ip/api/protocols/san/igroups?svm.name=$svm_name&name=$igroup_name&initiators.name=$iqn&protocol=iscsi&os_type=windows" | ConvertFrom-Json
      $record = $iGroupResult.records | Where-Object { $_.name -eq $igroup_name }
      $iGroupUuid = $record.uuid
      if ($null -eq $iGroupUuid) {
         Write-Output "Failed create Igroup: $igroup_name, aborting" >> $currentLogPath 
         Write-Host "Failed create Igroup: $igroup_name, aborting" -ForegroundColor Red
         . $uninstallFile
      break
   }
      @("curl.exe -m $TIMEOUT -X DELETE -u `"${user}:${password}`" -k `"https://$ip/api/protocols/san/igroups/$iGroupUuid`"") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }  
   else {
      Write-Output "Initiator ${iqn} with group ${igroup_name} already exists, skipping creation." >> $currentLogPath 
      Write-Host "Initiator ${iqn} with group ${igroup_name} already exists, skipping creation." -ForegroundColor Green
   } 
   #### map server iqn to lun ####
   Write-Output "Mapping LUN to Igroup" >> $currentLogPath 
   Write-Host "Mapping LUN to Igroup" -ForegroundColor Yellow
   
   $jsonPayload = @"
   {
      \"lun\": {
         \"name\": \"/vol/$vol_name/$lun_name\"
      },
      \"igroup\": {
         \"name\": \"${igroup_name}\"
      },
      \"svm\": {
         \"name\": \"${svm_name}\"
      },
      \"logical_unit_number\": 0
   }
"@

   curl.exe -m $TIMEOUT -X POST -u "${user}:${password}" -k "https://$ip/api/protocols/san/lun-maps" -d $jsonPayload
   $getLunMap = curl.exe -m $TIMEOUT -X GET -u "${user}:${password}" -k "https://$ip/api/protocols/san/lun-maps?lun.name=/vol/$vol_name/$lun_name&igroup.name=$group_name&svm.name=$svm_name" | ConvertFrom-Json
   $lunGroupCreated = $getLunMap.num_records
   if ($lunGroupCreated -eq 0) {
      Write-Output "Failed mapping LUN: $lun_name to igroup: $igroup_name" >> $currentLogPath 
      Write-Host "Failed mapping LUN: $lun_name to igroup: $igroup_name" -ForegroundColor Red
      . $uninstallFile
      break
   }
   @("curl.exe -m $TIMEOUT -X DELETE -u `"${user}:${password}`" -k `"https://$ip/api/protocols/san/lun-maps?lun.name=/vol/$vol_name/$lun_name&igroup.name=$igroup_name&svm.name=$svm_name`"") + (Get-Content $uninstallFile) | Set-Content $uninstallFile

   ### create new target ####
   Write-Output "Creating new target" >> $currentLogPath 
   Write-Host "Creating new target" -ForegroundColor Yellow

   # Query ONTAP REST API for iSCSI interfaces
   $interfacesResult = curl.exe -m $TIMEOUT -X GET -u "${user}:${password}" -k "https://$ip/api/network/ip/interfaces?svm.name=$svm_name&fields=ip,name" | ConvertFrom-Json

   $iscsi1IP = $interfacesResult.records | Where-Object { $_.name -eq "iscsi_1" } | Select-Object -ExpandProperty ip | Select-Object -ExpandProperty address
   $iscsi2IP = $interfacesResult.records | Where-Object { $_.name -eq "iscsi_2" } | Select-Object -ExpandProperty ip | Select-Object -ExpandProperty address

   if ($null -eq $iscsi1IP -or $null -eq $iscsi2IP) {
      Write-Output "Failed to get iSCSI interfaces from ONTAP, aborting" >> $currentLogPath 
      Write-Host "Failed to get iSCSI interfaces from ONTAP, aborting" -ForegroundColor Red
      . $uninstallFile
      break
   }

   try {
      New-IscsiTargetPortal -TargetPortalAddress $iscsi1IP -ErrorAction stop
      New-IscsiTargetPortal -TargetPortalAddress $iscsi2IP -ErrorAction stop
      @("Remove-IscsiTargetPortal -TargetPortalAddress $iscsi2IP") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
      @("Remove-IscsiTargetPortal -TargetPortalAddress $iscsi1IP") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   catch {
      Write-Output "Failed to add new target, due to: $_" >> $currentLogPath 
      Write-Host "Failed to add new target, due to: $_" -ForegroundColor Red
      . $uninstallFile
      break
   }

   Write-Output "Connect to the new target" >> $currentLogPath 
   try {
      Get-IscsiTarget | Connect-IscsiTarget -IsMultipathEnabled $true -ErrorAction stop -IsPersistent $true
      @("Get-IscsiTarget | Disconnect-IscsiTarget") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   catch {
      Write-Output "Failed to connect to the new target, due to: $_" >> $currentLogPath 
      Write-Host "Failed to connect to the new target, due to: $_" -ForegroundColor Red
      . $uninstallFile
      break
   }
   
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
if (Test-Path $uninstallFile){ 
   Remove-Item -Path $uninstallFile -Force 
   Write-Output "Uninstall script removed" >> $currentLogPath
   Write-Host "Uninstall script removed" -ForegroundColor Green
}
</powershell>
<persist>true</persist>