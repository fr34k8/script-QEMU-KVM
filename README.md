# Incremental creating and rebasing script for QEMU/KVM

This script allows you to:
* automaticlaly shutdown the virtual machine via virsh
* create incrementals of QCOW2 virtual disks files
* rebase the incremental disk files after certain amount since the [last re]base
* automatically back-up of increments and rebases via hard links.

The syntax is:
```
kvm_vm_backup.sh [image disk]
```
For example, having an Ubuntu virtual machine its disk name ubuntu.img:
```
kvm_vm_backup.sh ubuntu.img
```
