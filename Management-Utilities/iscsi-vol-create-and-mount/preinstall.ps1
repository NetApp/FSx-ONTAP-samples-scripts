[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='This script intentinally uses Write-Host to display messages to the user.')]
Param()
#
#### Installing ONTAP module #####
Write-Host "Installing/ Import ONTAP module" -ForegroundColor Yellow
$m = "NetApp.ONTAP"
if (Get-Module | Where-Object {$_.Name -eq $m}) {
       write-host "Module $m is already imported."
   }
   else {

       # If module is not imported, but available on disk then import
       if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
           Import-Module $m -Verbose
       }
       else {

           # If module is not imported, not available on disk, but is in online gallery then install and import
           if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
               Install-Module -Name $m -RequiredVersion 9.10.1.2111 -Force -Verbose -Scope CurrentUser
               Import-Module $m -Verbose
           }
           else {

               # If the module is not imported, not available and not in the online gallery then abort
               write-host "Cannot install Module $m, exiting...." -ForegroundColor Red
               EXIT 1
           }
       }
   }



### Install MPIO ####
Write-Host "Installing Multipath-IO windows feature" -ForegroundColor Yellow
$res = Get-WindowsFeature -Name Multipath-IO
if(($res.Installed))
{
    write-host "Windows feature Multipath-IO already installed" -ForegroundColor Green
    write-host "Done.." -ForegroundColor Green
}

else {
   Install-WindowsFeature -name Multipath-IO -Restart
}
