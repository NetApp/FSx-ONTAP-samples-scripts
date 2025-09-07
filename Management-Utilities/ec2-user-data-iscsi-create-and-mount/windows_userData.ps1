<powershell>
# This script is used to install and configure FSx for Windows File Server
param(
   [string]$SecretId,
   [string]$FSxNAdminIp,
   [string]$VolumeName,
   [string]$VolumeSize,
   [string]$DriveLetter
)
# "AWS secret ARN, e.g arn:aws:secretsmanager:us-east-1:111222333444:secret:MySecret-123456"
$secretId=
# "Fsx admin ip, e.g. 111.22.33.44"
$ip=
# "Fsx volume name, e.g. iscsiVol"
$volName=
# "volume size in GB, e.g 100"
$volSize=
# "drive letter to use, e.g. d"
$drive_letter=

$secretId = if ($SecretId) { $SecretId } else { $secretId }
$ip = if ($FSxNAdminIp) { $FSxNAdminIp } else { $ip }
$volName = if ($VolumeName) { $VolumeName } else { $volName }
$volSize = if ($VolumeSize) { $VolumeSize } else { $volSize }
$drive_letter = if ($DriveLetter) { $DriveLetter } else { $drive_letter }

# Defaults
$user="fsxadmin"
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
   $message = "Failed to get data from Secrets Manager, exiting..."
   Write-Output $message >> $currentLogPath 
   write-host $message -ForegroundColor Red
   EXIT 1
}

$message = "Get data from Secrets Manager, successfully"
Write-Output $message >> $currentLogPath 
write-host $message -ForegroundColor Green
$totaldisks = (get-disk | Sort-Object -Property number | Select-Object -Last 1 -ExpandProperty number)

$path= "HKLM:\Software\UserData"
$itemName = "FSXnRunStep"

if(!(Get-Item $path -ErrorAction SilentlyContinue)) {
   New-Item $path
   New-ItemProperty -Path $path -Name $itemName -Value 0 -PropertyType dword
}

Write-Output "Write-Host ""Uninstall FSxn configuration""" >> $uninstallFile
Write-Output "# FSXn uninstall:" >> $uninstallFile

$runStep = Get-ItemProperty -Path $path -Name $itemName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $itemName

if($runStep -eq 0) {

   ### Install MPIO ####
   $message = "Installing Multipath-IO windows feature"
   Write-Output $message >> $currentLogPath
   Write-Host $message -ForegroundColor Yellow
   $res = Get-WindowsFeature -Name Multipath-IO | Where-Object {$_.InstallState -eq "Installed"}
   if(($res.Installed))
   {
      $message = "Windows feature Multipath-IO already installed"
      Write-Output $message >> $currentLogPath
      Write-Output "IDone.." >> $currentLogPath
      write-host $message -ForegroundColor Green
      write-host "Done.." -ForegroundColor Green
   }
   else {
      # restart the instance after installing MPIO
      Install-WindowsFeature -name Multipath-IO -Restart 
      @("Uninstall-WindowsFeature -Name Multipath-IO -Remove -Confirm:$false") + (Get-Content $uninstallFile) | Set-Content $uninstallFile   
   }

   $vol_number = get-random -Minimum 1 -Maximum 10000
   $vol_name = $volName
   $lun_name = $volName + "_" + $vol_number
   $igroup_name = "winhost_ig_" + $vol_number
   
   #### check if letter drive already in used and in the correct format ####
   if($drive_letter.Length -gt 1 -or !($drive_letter -match '[a-zA-Z]'))
   {
      $message = "Drive letter: $drive_letter is not in the correct format"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red
      . $uninstallFile
      break
   }
   if(Test-Path $drive_letter':')
   {
      $message = "Drive letter: $drive_letter already in use"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red
      . $uninstallFile
      break
   }

   ##### Enable MPIO and Start iSCSI Service ####
   Write-Output "Enabling MPIO" >> $currentLogPath 
   Write-Host "Enabling MPIO" -ForegroundColor Yellow
   Enable-MSDSMAutomaticClaim -BusType iSCSI -Confirm
   @("Disable-MSDSMAutomaticClaim -BusType iSCSI -Confirm") + (Get-Content $uninstallFile) | Set-Content $uninstallFile   
   $message = "Starting iSCSI service and setting on automatic status"
   Write-Output $message >> $currentLogPath
   Write-Host $message -ForegroundColor Yellow
   try {
      Start-Service -Name msiscsi -ErrorAction Stop
      @("Stop-Service  -Name msiscsi -Force") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   catch {
      $message = "Failed start msiscsi, due to: $_"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red
      . $uninstallFile
      break
   }

   Set-Service -Name msiscsi -StartupType Automatic

   #### Validate connection to FSX ####
   Write-Host "Connectiong to FSxN filesystem" -ForegroundColor Yellow
            
   $connectResult = curl.exe -X GET -k "https://$ip/api/cluster?fields=version" -u "${user}:${password}" | ConvertFrom-Json
   if ($null -eq $connectResult.version) {
      $message = "Failed connect to FSXn filesystem, due to: $connectResult.error.message"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red
      . $uninstallFile
      break
   }

   Write-Output "Creating volume: $vol_name" >> $currentLogPath 
   Write-Host "Creating volume: $vol_name" -ForegroundColor Yellow
   $instanceId = Get-EC2InstanceMetadata -Category InstanceId

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
      }],
      \"_tags\": [
         \"instanceId:$instanceId\",
         \"hostName:$env:COMPUTERNAME\",
         \"mountPoint:$drive_letter\"
      ]
   }
"@
   $createVolumeResult = curl.exe -m $TIMEOUT -X POST -u "${user}:${password}" -k "https://$ip/api/storage/volumes" -d $jsonPayload | ConvertFrom-Json
   Start-Sleep -Seconds 10
   $jobId = $createVolumeResult.job.uuid
   $jobStatus = curl.exe -X GET -u "${user}:${password}" -k "https://$ip/api/cluster/jobs/$jobId" | ConvertFrom-Json
   if ($jobStatus.state -ne "success") {
      $message = "Failed create volume: $vol_name, due to: $($jobStatus.error)"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red
      . $uninstallFile
      break
   }
   $volumeResult = curl.exe -m $TIMEOUT -X GET -u "${user}:${password}" -k "https://$ip/api/storage/volumes?name=${vol_name}&svm.name=${svm_name}" | ConvertFrom-Json
   $record = $volumeResult.records | Where-Object { $_.name -eq $vol_name }
   $volumeUUid = $record.uuid
   if ($null -eq $volumeUUid) {
      $message = "Failed create volume: $vol_name, aborting"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red
      . $uninstallFile
      break
   }
   @("curl.exe -m $TIMEOUT -X DELETE -u `"${user}:${password}`" -k `"https://$ip/api/storage/volumes/$volumeUUid`"") + (Get-Content $uninstallFile) | Set-Content $uninstallFile

   $message = "Creating LUN: /vol/$vol_name/$lun_name"
   Write-Output $message >> $currentLogPath 
   Write-Host $message -ForegroundColor Yellow

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
      $message = "Failed create LUN: $lun_name, aborting"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red
      . $uninstallFile
      break
   }

   $message = "LUN created successfully with UUID: $lunUuid"
   Write-Output $message >> $currentLogPath
   Write-Host $message -ForegroundColor Green
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
         $message = "Failed create Igroup: $igroup_name, aborting"
         Write-Output $message >> $currentLogPath 
         Write-Host $message -ForegroundColor Red
         . $uninstallFile
      break
   }
      @("curl.exe -m $TIMEOUT -X DELETE -u `"${user}:${password}`" -k `"https://$ip/api/protocols/san/igroups/$iGroupUuid`"") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }  
   else {
      $message = "Initiator ${iqn} with group ${igroup_name} already exists, skipping creation."
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Green
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
      $message = "Failed mapping LUN: $lun_name to igroup: $igroup_name"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red
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
      $message = "Failed to get iSCSI interfaces from ONTAP, aborting"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red
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
      $message = "Failed to add new target, due to: $_"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red
      . $uninstallFile
      break
   }

   Write-Output "Connect to the new target" >> $currentLogPath 
   try {
      Get-IscsiTarget | Connect-IscsiTarget -IsMultipathEnabled $true -ErrorAction stop -IsPersistent $true
      @("Get-IscsiTarget | Disconnect-IscsiTarget") + (Get-Content $uninstallFile) | Set-Content $uninstallFile
   }
   catch {
      $message = "Failed to connect to the new target, due to: $_"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red
      . $uninstallFile
      break
   }
   
   #### create new ISCSI disk ####
   $message = "Online, Initialize and format disks"
   Write-Output $message >> $currentLogPath 
   Write-host $message -ForegroundColor Yellow
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
      $message = "Failed set disk to online, due to: $_"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red -ErrorAction stop
      break
   }

   $message = "Set disk to have Read/Write permissions"
   Write-Output $message >> $currentLogPath 
   Write-host $message -ForegroundColor Yellow
   try {
      set-disk -Number $diskNum -IsReadOnly $false
   }
   catch {
      $message = "Failed set disk to RW, due to: $_"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red -ErrorAction stop
      break
   }

   try {
      $message = "Starting Initialize and format disk number: $diskNum"
      Write-Output $message >> $currentLogPath 
      Write-host $message -ForegroundColor Yellow
      Initialize-Disk -Number $diskNum -PartitionStyle MBR
      New-Partition -DiskNumber $diskNum -UseMaximumSize -IsActive -DriveLetter $drive_letter | Format-Volume
   }
   catch {
      $message = "Failed create new partition, due to: $_"
      Write-Output $message >> $currentLogPath 
      Write-Host $message -ForegroundColor Red  -ErrorAction stop
      break
   }
   Set-ItemProperty -Path $path -Name $itemName -Value 1
   $message = "Done creating new FSx disk, drive letter: $drive_letter"
   Write-Output $message >> $currentLogPath 
   Write-Host $message -ForegroundColor Green
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