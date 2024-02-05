# FSxN Convenience Scripts
This folder contains sample scripts that are designed to help you use FSxN from
a command line. Most of the scripts are written in Bash, intended to be run either from
a UNIX based O/S (e.g. Linux, MacOS, FreeBSD), or from a Microsoft Windows based system with a
Windows Subsystem for Linux (WSL) based Linux distribution installed.

## Preparation
Before running the UNIX based scripts, make sure the following package is installed:

* jq  - lightweight and flexible command-line JSON processor
* aws-cli - Command Line Environment for AWS

## Summary of the convenience scripts

| Script                    | Description     |
|:-00-----------------------|:----------------|
|create_fsxn_filesystem     | Createa a new FSxN file system.|
|create_fsxn_svm            | Creates a new storage virtual machine under the specified file system. |
|create_fsxn_volume         | Creates a new volume under a specified SVM. |
|list_fsxn_filesystems      | List all the FSxN file systems that the user has access to. |
|list_fsxn_filesystems.ps1  | List all the FSxN file systems that the user has access to, written in PowerShell. |
|list_fsxn_svms             | List all the FSxN storage virtual machines that the user access to. |
|list_fsxn_volumes          | List all the FSxN volumes that the user has access to. |
|delete_fsxn_filesystem     | Deletes a FSxN file system. |
|delete_fsxn_svm            | Deltees a FSxN storage virtual machine. |
|delete_fsxn_volume         | Deletes a FSxN volume. |
