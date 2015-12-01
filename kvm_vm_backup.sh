#!/bin/bash

# Create configuration file.
if [ -f kvm_vm_backup.conf ]; then
	cat<<EOF
POOLDIR=""
BACKUPDIR="\$POOLDIR/Backups"
EOF
fi

# Load variables
CONFFILE="./kvm_vm_backup.conf"
source kvm_vm_backup.conf
IMG_FILE="$1"
NOM_VM="$(basename ${IMG_FILE} .img)"

increment_renaming(){
	TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
	NOM_INC="${NOM_VM}_${TIMESTAMP}"

	mv ${NOM_VM}.img ${NOM_INC}.inc.img
}

apagar(){
	COUNTER=0

	## Turn off machine
	virsh shutdown ${NOM_VM}

	## Check that Virtual Machine is turned off
	while [[ $(virsh domstate ${NOM_VM} | egrep 'apagado' | wc -l) -eq 0 ]]; do
		echo "Waiting for VM to shut down..."
		sleep 10
		COUNTER=$COUNTER+1

		## Exit script if it doesn't turn off.
		if [ $COUNTER -ge 5 ]; then
			echo "VM can't be stopped or is waiting to long, aborting script."
			exit 1
		fi
	done

	echo "VM has been shutdown correctly..."
}

incremental(){
	echo "Creating new snapshot."
	## Rename snapshot.
	increment_renaming

	## Back-up snapsot using hard link.
	ln ${NOM_INC}.img Backups/${NOM_INC}.inc.img

	## Create a new snapshot using previous one as backing file.
	qemu-img create -b ${NOM_INC}.img -f qcow2 ${NOM_VM}.inc.img

	## For non-privileged users, add read and write permisions to others.
	chmod o=rw ${NOM_VM}.img

	echo "Snapshot ${NOM_INC}.img created, a copy has been created at $PWD/Backups."
}

rebase(){
	echo "Rebasing the snapshots."
	# Rename snapshot.
	increment_renaming

	# Rebasing the last snapshot and backing it up as a hard link.
	qemu-img convert -O qcow2 ${NOM_INC}.img ${NOM_INC}.rebase.img
	ln ${NOM_INC}.img.rebase Backups/${NOM_INC}.rebase.img

	echo "The new base (${NOM_INC}.img.rebase) has been created."

	# Deleting old unnecesary snapshots.
	REBASE_FILE="$(ls ${NOM_VM}* | grep rebase)"
	if [ -n "${REBASE_FILE}" ]; then
		REMOVE_LIST=$(ls -l ${NOM_VM}_*.img | grep -v "rebase")
		for f in $REMOVE_LIST ; do
			rm "$f"
		done
		NEW_BASE="$(basename ${REBASE_FILE} .rebase)"
		mv "${REBASE_FILE}" "${NEW_BASE}"
	fi

	# Creating a new snapshot with the new base as backing file.
	qemu-img create -b ${NEW_BASE} -f qcow2 ${NOM_VM}.img
	echo -e "Old snapshots have been deleted.\nA new snapshot (${NOM_VM}.img) have been created and ready to be used."
}

rsync_backup(){
	rsync -aw
}
# Creating "Backups" folder if it does not exit.
if [ -z $POOLDIR ]; then
	read -p "Please, input your VM pool folder path: " POOLDIR
	POOLDIR=`readlink -m $POOLDIR`
	sed -i "s/POOLDIR=\".*\"/POOLDIR=\"$POOLDIR\"/g" $CONFFILE
fi

if [ ! -d $BACKUPDIR ]; then
	mkdir -p $BACKUPDIR
fi

COUNTER=$(qemu-img info --backing-chain ${NOM_VM}.img | grep "backing file" | wc -l )
MAX_COUNTER=3

if [[ $(virsh domstate ${NOM_VM} | egrep 'apagado' | wc -l) -eq 0 ]]; then
	echo "Turning off the VM."
	apagar
fi

if [ ${COUNTER} -ge ${MAX_COUNTER} ]; then	# After X snapshots...
	rebase					# do a rebase.
else
	incremental				# Or make a new incremental if not.
fi
echo "Starting up the VM."
virsh start ${NOM_VM}
