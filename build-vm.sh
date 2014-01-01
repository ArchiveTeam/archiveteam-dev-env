#!/bin/bash -ex

VMNAME="archiveteam-dev-env"
INSTALL_ISO="ubuntu-12.04.3-alternate-i386.iso"

mkdir -p original-iso/ custom-iso/
fuseiso $INSTALL_ISO original-iso/
cp -r original-iso/* original-iso/.[a-z]* custom-iso/
fusermount -u original-iso/

chmod -R u+rw custom-iso/

cp txt.cfg custom-iso/isolinux
cp preseed.cfg custom-iso/preseed/

mkisofs -r -V "Custom Ubuntu Install CD" \
    -cache-inodes \
    -J -l -b isolinux/isolinux.bin \
    -c isolinux/boot.cat -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o at.iso custom-iso/

rm -r custom-iso/

VBoxManage createvm --name $VMNAME --ostype Ubuntu --register
VBoxManage modifyvm $VMNAME \
	--largepages off \
	--accelerate3d off \
	--natpf1 "Tracker Web Interface,tcp,127.0.0.1,9080,,9080" \
	--natpf1 "Tracker WebSocket,tcp,127.0.0.1,9081,,9081" \
	--natpf1 "Rsync,tcp,127.0.0.1,9873,,9873" \
	--natpf1 "SSH,tcp,127.0.0.1,9022,,9022" \
	--audio none \
	--usb off \
	--usbehci off \
	--memory 512 \
	--biosbootmenu menuonly

VBoxManage storagectl $VMNAME --name "SATA Controller" --add sata
VBoxManage createhd --filename os.vdi --size 8192

VBoxManage storageattach $VMNAME \
	--storagectl "SATA Controller" \
	--port 0 --device 0 --type hdd \
	--medium os.vdi

VBoxManage storagectl $VMNAME --name "IDE Controller" --add ide
VBoxManage storageattach $VMNAME --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium at.iso

