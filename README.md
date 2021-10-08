archiveteam-dev-env
===================

Ubuntu preseed for a [developer environment](http://archiveteam.org/index.php?title=Dev) for ArchiveTeam projects.

Download: [archiveteam-dev-env-v1-20140913.ova 624M](https://archive.org/details/archiveteam_dev_env_v1_appliances) *This ova file is an beta version. Please help test it.*

This environment includes:

1. `seesaw-kit` environment
2. ready-to-use `universal-tracker`
3. ready-to-use `rsync` host

For the preseed of the Warrior, see [warrior-preseed](https://github.com/ArchiveTeam/warrior-preseed).

Logging into the virtual machine
--------------------------------

Once you have imported and booted up the virtual machine, the following accounts are available:

* `dev`
* `tracker`
* `rsync`

The passwords are the same as the username.

To access the tracker, visit http://localhost:9080/global-admin/. Note that "Live logging host" must be changed to `localhost:9081`.

The rsync URL is `rsync://localhost:9873/archiveteam/`.

Problems or comments? Please use the GitHub issue tracker. (Or have a chat on #archiveteam-dev on hackint.)

Additional Tips for Setup
-------------------------
* This version of the tracker doesn't support multi-items, so temporarily remove `multi={}/` from the `GetItemFromTracker` call.
* Use TRACKER_HOST = 'localhost:9080'
* For uploads, add `rsync://localhost:9873/archiveteam/<project name>/:downloader/` as a target in the "Uploads" tab of the project admin page. Log in to the VM as `rsync`, `cd` to the uploads folder, and create the `<project name>` folder.

Building the virtual machine appliance
--------------------------------------

You will need:

* Unix-like environment
* VirtualBox
* fuseiso
* An Ubuntu alternative installer ISO: http://releases.ubuntu.com/precise/ubuntu-12.04.3-alternate-i386.iso

1. Run `./build-vm.sh` which creates the virtual machine and its properties.
2. Start the virtual machine.
3. Run the installation, answer "Continue", and wait for it to shut down. During "Finishing the installation", "Running preseed" may appear to hang. Pressing Alt+Right or Alt+Left will switch consoles. One of these consoles will show logging output.
4. Run `./pack-vm.sh` which creates the OVA file.
