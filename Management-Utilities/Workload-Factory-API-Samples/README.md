# Workload Factory API Samples

This folder contains various bash shell scripts that demonstrate how to use the Workload Factory APIs to perform an action.
They all depend on the [wf_utils](wf_utils) file that contains common functions used by all the scripts. One function
in particular, `get_token()`, is used to get an authentication token from the BlueXP Workload Factory API. So, if you
copy just some of the files from this repository, make sure to copy the `wf_utils` file as well.

## Prerequisites
To run these scripts, you need to have the following prerequisites:
- A bash shell.
- The `curl` command-line tool installed.
- The `jq` command-line JSON processor installed. You can install it using your package manager, e.g., `apt-get install jq` on Debian/Ubuntu or `brew install jq` on macOS.

## Notes:
- All scripts allow you to set environment variables to pass options instead of having to use the
command line options. For example, instead of using the `-t` option to pass the
[BlueXP Refresh Token](https://docs.netapp.com/us-en/bluexp-automation/platform/create_user_token.html#1-generate-a-netapp-refresh-token),
you can set the `REFRESH_TOKEN` environment variable.

- All scripts use the `-h` option to display the help message, which includes the available options and their descriptions.

Hopefully with these samples you'll be able to create your own scripts that use any the Workload Factory APIs.
If you do create a new script, please consider contributing it back to this repository so that others can benefit from it.

## Available Scripts
| Script | Description |
| --- | --- |
| [list_bluexp_accts](list_bluexp_accts) | This list all the BlueXP accounts (a.k.a. organizations) that you have access to. |
| [list_credentials](list_credentials) | This lists all the Workload Factory credentials that you have access to. |
| [list_filesystems](list_filesystems) | This lists all the FSx for ONTAP file systems that you have access to in the specified AWS region. |
| [list_snapmirrors](list_snapmirrors) | This lists all the SnapMirror relationships that are associated with the specified file system. |
| [list_svms](list_svms) | This lists all the SVMs that are associated with the specified file system. |
| [list_volumes](list_volumes) | This lists all the volumes that are associated with the specified file system. |
| [snapmirror_break](snapmirror_break) | This breaks the SnapMirror relationship for the specified relationship. |
| [snapmirror_create](snapmirror_create) | This creates a SnapMirror relationship between the specified source volume and destination SVM. |
| [snapmirror_delete](snapmirror_delete) | This deletes the SnapMirror relationship for the specified relationship. |
| [snapmirror_resync](snapmirror_resync) | This resyncs the SnapMirror relationship for the specified relationship. |
| [snapmirror_reverse](snapmirror_reverse) | This reverses the SnapMirror relationship for the specified relationship. |
| [snapmirror_update](snapmirror_update) | This updates the SnapMirror relationship for the specified relationship. |
| [snapshot_create](snapshot_create) | This creates a snapshot of the specified volume. |
| [volume_clone](volume_clone) | This clones the specified volume. |
| [volume_delete](volume_delete) | This deletes the specified volume. |
| [wf_utils](wf_utils) | This file contains common functions used by all the scripts. It includes the `get_token()` function that retrieves an authentication token from the Workload Factory API. |

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an _"AS IS"_ basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2025 NetApp, Inc. All Rights Reserved.
