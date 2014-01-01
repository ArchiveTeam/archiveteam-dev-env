#!/bin/bash -ex

VMNAME="archiveteam-dev-env"
OVA_OUT="archiveteam-dev-env-v1-$( date +%Y%m%d ).ova"

VBoxManage modifyhd --compact os.vdi

VBoxManage export $VMNAME \
  --output $OVA_OUT \
  --vsys 0 \
  --product "ArchiveTeam Developer Environment" \
  --vendor "ArchiveTeam" \
  --vendorurl "http://www.archiveteam.org/" \
  --version "1"
