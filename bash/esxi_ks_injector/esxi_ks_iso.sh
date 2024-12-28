#!/bin/bash
# Add kickstart configuration to ESXi ISO for automated installation.
#
# Example:
# ./esxi_ks_iso.sh -i VMware-VMvisor-Installer-7.0U2-17630552.x86_64.iso -k KS.CFG

# Check if genisoimage is installed
command -v genisoimage >/dev/null 2>&1 || { echo >&2 "This script requires genisoimage but it's not installed."; exit 1; }

# Script must be started as root to allow iso mounting
if [ "$EUID" -ne 0 ] ; then echo "Please run as root." ;  exit 1 ;  fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -i|--iso) BASEISO="$2"; shift ;;
    -k|--ks) KS="$2"; shift ;;
    -w|--working-dir) WORKINGDIR="$2"; shift ;;
    -n|--name) NAME="$2"; shift ;;    
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z $BASEISO || -z $KS ]]; then
 echo 'Usage: esxi_ks_iso.sh -i VMware-VMvisor-Installer-7.0U2-17630552.x86_64.iso -k KS.CFG'
 echo 'Options:'
 echo "  -i, --iso          Base ISO File"
 echo '  -k, --ks           Kickstart Configuration File'
 echo '  -w, --working-dir  Working directory (Optional)'
 exit 1
fi

if [[ -z $WORKINGDIR ]]; then
  WORKINGDIR="/dev/shm/esxibuilder"
fi

mkdir -p ${WORKINGDIR}/iso-${NAME}
mount -t iso9660 -o loop,ro ${BASEISO} ${WORKINGDIR}/iso-${NAME}

mkdir -p ${WORKINGDIR}/isobuild-${NAME}
cp ${KS} ${WORKINGDIR}/isobuild-${NAME}/KS.CFG
cd ${WORKINGDIR}/iso-${NAME}
tar cf - . | (cd ${WORKINGDIR}/isobuild-${NAME}; tar xfp -)

chmod +w ${WORKINGDIR}/isobuild-${NAME}/boot.cfg
chmod +w ${WORKINGDIR}/isobuild-${NAME}/efi/boot/boot.cfg
sed -i -e 's/cdromBoot/ks=cdrom:\/KS.CFG/g'  ${WORKINGDIR}/isobuild-${NAME}/boot.cfg
sed -i -e 's/cdromBoot/ks=cdrom:\/KS.CFG/g'  ${WORKINGDIR}/isobuild-${NAME}/efi/boot/boot.cfg

cd ${WORKINGDIR}
genisoimage -relaxed-filenames -J -R -o ${NAME}.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -eltorito-boot efiboot.img -quiet --no-emul-boot ${WORKINGDIR}/isobuild-${NAME}  2>/dev/null
echo ${NAME}.".iso"

umount ${WORKINGDIR}/iso-${NAME}
rm -rf ${WORKINGDIR}/iso-${NAME}
rm -rf ${WORKINGDIR}/isobuild-${NAME}
