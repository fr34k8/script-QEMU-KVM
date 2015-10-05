#!/bin/bash
CURRENT_PATH=$(pwd)
IMG_FILE="$1"
IMGF_DIR="$(dirname $1)"

#if [ -n "$IMG_PATH" | ]; then

# Crear carpeta backup si no existe.
mkdir -p Backups

# *************************** #
NOM_VM="$(basename ${IMG_FILE} .img)"

## Apagar la maquina
virsh shutdown ${NOM_VM}

## Comprobar que la máquina está apagada.
while [[ $(virsh list --all | grep $NOM_VM | egrep 'apagado' | wc -l) = 0 ]]; do
	echo "Esperando a la maquina para apagarse..."
	sleep 5
done

echo "Maquina apagada. Empezando la copia de seguridad..."

## Renombar el incremento
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
NOM_INC="${NOM_VM}_${TIMESTAMP}"

mv ${NOM_VM}.img ${NOM_INC}.img

## Back up con enlace duro
ln ${NOM_INC}.img Backups/${NOM_INC}.img

ln -sf ${NOM_INC}.img ${NOM_VM}-current.img

## Crear un nuevo incremento del incremento anterior.
qemu-img create -b ${NOM_VM}-current.img -f qcow2 ${NOM_VM}.img
chmod o=rw ${NOM_VM}.img

## Encender la maquina.
echo "Copia de seguridad creada. Encendiendo la maquina..."
virsh start ${NOM_VM}

# ***************************** #

# ***************************** #
qemu-img convert -O qcow2 $NOM_INC
# ***************************** #

#REBASE_FILE="$(ls ${NOM_VM}* | grep rebase)"
#if [ -n "${REBASE_FILE}" ]; then
#	LAST_TIMESTAMP="$(basename ${REBASE_FILE} .rebase | cut -d "_" -f2)"
#	REMOVE_LIST=$(ls -l ${NOM_VM}_*.img | grep -v "rebase")
#	for f in $REMOVE_LIST ; do
#		rm "$f"
#	done
#	NEW_BASE="$(basename ${REBASE_FILE} .rebase)"
#	mv "${REBASE_FILE}" "${NEW_BASE}"
#fi
