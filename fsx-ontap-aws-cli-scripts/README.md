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
|list_fsx_fss             | List all the FSxN filesystems that the user has access to. |
|list_fax_fss.ps1         | List all the FSxN filesystems that the user has access to, written in PowerShell. |
|list_fsx_volumes         | List all the FSxN volumes that the user has access to. |
|list_fsx_svms            | List all the storage virtual machines that the user access to. |
|fsx_create_volume        | Creates a new volume under a specified SVM. |
|fsx_delete_volume        | Deletes a volume. |
