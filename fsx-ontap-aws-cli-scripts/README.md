# FSxN Convenience Scripts
This folder contains sample scripts that are designed to help you use FSxN from
a command line. Most of the scripts are written in Bash, intended to be run either from
a UNIX based O/S (e.g. Linux, MacOS, FreeBSD), or from a Microsoft Windows based system with a
Windows Subsystem for Linux (WSL) based Linux distribution installed.

## Preparation
Before running the UNIX based scripts, make sure the following package is installed:

* jq  - lightweight and flexible command-line JSON processor

## Summary of the convenience scripts

| Script                  | Description     |
|:------------------------|:----------------|
|create_fsxn_filesystem   | Creates a new FSx for NetApp ONTAP file-system |
|create_fsxn_svm          | Creates a new Storage Virtual Server (svm) in a soecific FSx ONTAP filesystem |
|create_fsxn_volume       | Creates a new volume under a specified SVM. |
|list_fsx_filesystems     | List all the FSx for NetApp ONTAP filesystems that the user has access to. |
|list_fsx_filesystems.ps1 | List all the FSx for NetApp ONTAP filesystems that the user has access to, written in PowerShell. |
|list_fsxn_volumes        | List all the FSx for NetApp ONTAP volumes that the user has access to. |
|list_fsxn_svms           | List all the storage virtual machines that the user access to. |
|delete_fsxn_filesystem   | Deletes an FSx for NetApp ONTAP filesystem. |
|delete_fsxn_svm          | Deletes an svm. |
|delete_fsxn_volume       | Deletes a volume. |
