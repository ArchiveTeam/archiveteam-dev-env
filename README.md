archiveteam-dev-env
===================

**Work in progress.**

Ubuntu preseed for a [developer environment](http://archiveteam.org/index.php?title=Dev) for ArchiveTeam projects.

This environment includes:

1. `seesaw-kit` environment
2. ready-to-use `universal-tracker`
3. ready-to-use `rsync` host

For the preseed of the Warrior, see [warrior-preseed](https://github.com/ArchiveTeam/warrior-preseed).

Creating the virtual machine appliance
--------------------------------------

You will need:

* VirtualBox
* fuseiso
* An Ubuntu alternative installer ISO: http://releases.ubuntu.com/precise/ubuntu-12.04.3-alternate-i386.iso

1. Run `./build-vm.sh` which creates the virtual machine and its properties.
2. Start the virtual machine.
3. Run the installation, answer "Continue", and wait for it to shut down. During "Finishing the installation", "Running preseed" may appear to hang. Pressing Alt+Right or Alt+Left will switch consoles. One of these consoles will show logging output.
4. Run `./pack-vm.sh` which creates the OVA file.

Logging into the virtual machine
--------------------------------

Once you have imported and booted up the virtual machine, the following accounts are available:

* `dev`
* `tracker`
* `rsync`

The passwords are the same as the username.

To access the tracker, visit http://localhost:9080/global-admin/. Note that "Live logging host" must be changed to `localhost:9081`.

The rsync URL is `rsync://localhost:9873/archiveteam/`.


