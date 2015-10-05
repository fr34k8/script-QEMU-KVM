#!/bin/bash
CURRENT_PATH=$(pwd)
IMG_FILE="$1"
IMGF_DIR="$(dirname $1)"
NOM_VM="$(basename ${IMG_FILE} .img)"

apagar(){
	# Comprobar que la máquina está apagada.
	COUNTER=0
	while [[ $(virsh list --all | grep $NOM_VM | egrep 'apagado' | wc -l) = 0 ]]; do
		echo "Esperando a la maquina para apagarse..."
		sleep 5
		COUNTER=$COUNTER+1

		if [ $COUNTER -ge 10 ]; then
	4		echo "La maquina no se cierra o está tardando un mucho, abortando el scriptñ."
			exit
		fi
	done

	echo "Maquina apagada correctamente."
}

incremental(){
	if ; then
		## Renombar el incremento
		TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
		NOM_INC="${NOM_VM}_${TIMESTAMP}"

		mv ${NOM_VM}.img ${NOM_INC}.img

		## Back up con enlace duro
		ln ${NOM_INC}.img Backups/${NOM_INC}.img

		## Crear un nuevo incremento del incremento anterior.
		qemu-img create -b ${NOM_INC}.img -f qcow2 ${NOM_VM}.img
		chmod o=rw ${NOM_VM}.img
	else
		
	fi

	## Encender la maquina.
	echo "Copia de seguridad creada. Encendiendo la maquina..."
	virsh start ${NOM_VM}
}

rebase(){
	TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
	NOM_INC="${NOM_VM}_${TIMESTAMP}"

	mv ${NOM_VM}.img ${NOM_INC}.img
	qemu-img convert -O qcow2 ${NOM_INC}.img ${NOM_INC}.img.rebase
	ln ${NOM_INC}.img.rebase Backups/${NOM_INC}.img.rebase

	REBASE_FILE="$(ls ${NOM_VM}* | grep rebase)"
	if [ -n "${REBASE_FILE}" ]; then
		REMOVE_LIST=$(ls -l ${NOM_VM}_*.img | grep -v "rebase")
		for f in $REMOVE_LIST ; do
			rm "$f"
		done
		NEW_BASE="$(basename ${REBASE_FILE} .rebase)"
		mv "${REBASE_FILE}" "${NEW_BASE}"
	fi
}

#if [ -n "$IMG_PATH" | ]; then

# Crear carpeta backup si no existe.
mkdir -p Backups

COUNTER=$(qemu-img info --backing-chain ${NOM_VM}.img | grep "backing file" | wc -l )
MAX_COUNTER=3

virsh shutdown ${NOM_VM}
apagar
if [ ${COUNTER} -ge ${MAX_COUNTER} ]; then
	rebase
else
	incremental
fi
virsh start ${NOM_VM}
