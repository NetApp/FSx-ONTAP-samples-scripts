# Warm Performance (SSD) tier for an FSx for ONTAP volume

## Introduction
This sample provides a script that can be used to warm a FSx for ONTAP
volume. In other words, it ensures that all the blocks for a volume are in
the "performance tier" as opposed to the "capacity tier." It does that by
simply reading every byte of every file in the volume. Doing that
causes all blocks that are currently in the capacity tier to be pulled
into the performance tier before being returned to the reader. At that point,
assuming, the tiering policy is not set to 'all', all the data should remain
in the performance tier until ONTAP tiers it back based on the volume's
tiering policy.

Note that Data ONTAP will not store data in the performance
tier from the capacity tier if it detects that the data is being read
sequentially. This is to keep things like backups and virus scans from
filling up the performance tier. Because of that, this script will
read files in "reverse" order. Meaning it will read the last block of
the file first, then the second to last block, and so on. 

To speed up the process, the script will spawn multiple threads to process
the volume. It will spawn a separate thread for each directory
in the volume, and then a separate thread for each file in that directory.
The number of directory threads is controlled by the -t option. The number
of reader threads is controlled by the -x option. Note that the script
will spawn -x reader threads **per** directory thread. So for example, if you have 4
directory threads and 10 reader threads, you could have up to 40 reader
threads running at one time.

Since the goal of this script is to force all the data that is currently
in the capacity tier to the performance tier you should ensure you have
enough free space in your performance tier to hold all the data in the volume.
You can use the `volume show-footprint` ONTAP command to see how much space
is currently in the capacity tier. You can then use `storage aggregate show`
to see how much space is available in the performance tier.

## Set Up
The script is meant to be run on a Linux based host that is able to NFS
mount the volume to be warmed. If the volume is already mounted, then
any user that has read access to the files in the volume can run it.
Otherwise, the script needs to be run as 'root' so it can mount the
volume before reading the files.

If the 'root' user can't read the files in the volume, then you should use 'root'
to mount the volume first and then run the script from a user ID that can read the contents
of all the files in the volume. 

Make sure you have set the tiering policy on the volume set to something
other than "all" or "snapshot-only", otherwise the script will be ineffective.

# Running The Script
There are two main ways to run the script. The first is to just provide
the script with a directory to start from. The script will then read
every file in that directory and all subdirectories. The second way
is to provide the script with the FSx for ONTAP file system data endpoint
and the volume name. The script will then attempt to mount the volume
if it isn't already mounted. If it does mount it, it will mount it read-only
and unmount when it is done.

In order to mount the volume the script assumes that the junction path is the same
as the volume name. If this isn't the case, then just mount the volume first
before running the script and provide the path to the mount point
with the -d option.

To run this script you just need to change the UNIX permissions on
the file to be executable, then run it as a command:
```
chmod +x warm_performance_tier
 ./warm_performance_tier -d /path/to/mount/point
```
The above example will force the script to read every file in the /path/to/mount/point
directory and any directory under it.

If you want the script to ensure the volume is mounted, you can specify
the file system data endpoint and volume name:
```
./warm_performance_tier -f fsxfileserver.us-west-2.amazonaws.com -v myvolume
```
By default there won't be any output from the script. You can provide a -V option to
get verbose output. This will display the thread ID, date (in epoch seconds), then the
directory or file being processed.

If you run the script with a '-h' option, you will see the following help message:
```
Usage: warm_performance_tier [-f filesystem_endpoint] [-v volume_name] [-d directory] [-t max_directory_threads] [-x max_read_threads] [-n nfs_type] [-h] [-V]
Where:
  -f filesystem_endpoint - Is the hostname or IP address of the FSx for ONTAP file system.
  -v volume_name - Is the ID of the volume.
  -n nfs_type - Is the NFS version to use. Default is nfs4.
  -d directory - Is the root directory to start the process from.
  -t max_directory_threads - Is the maximum number of threads to use to process directories. The default is 10.
  -x max_read_threads - Is the maximum number of threads to use to read files. The default is 4.
  -V - Enable verbose output. Displays the thread ID, date (in epoch seconds), then the directory or file being processed.
  -h - Prints this help information.

Notes:
  * The filesystem_endpoint, volume_name and nfs_type are used to mount the volume
    if it is not already mounted. It will be mounted read-only. It assumes that
    the junction path is the same as the volume name.
  * For each directory thread, there will be a maximum of max_read_threads threads
    reading files.
```

## Author Information

This repository is maintained by the contributors listed on [GitHub](https://github.com/NetApp/FSx-ONTAP-samples-scripts/graphs/contributors).

## License

Licensed under the Apache License, Version 2.0 (the "License").

You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" basis, without WARRANTIES or conditions of any kind, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

© 2024 NetApp, Inc. All Rights Reserved.