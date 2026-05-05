#!/bin/bash

#
# Copyright (C) 2021-2022 KonstaKANG
#
# SPDX-License-Identifier: Apache-2.0
#

exit_with_error() {
  echo $@
  exit 1
}

if [ -z ${TARGET_PRODUCT} ]; then
  exit_with_error "TARGET_PRODUCT environment variable is not set. Run lunch first."
fi

if [ -z ${ANDROID_PRODUCT_OUT} ]; then
  exit_with_error "ANDROID_PRODUCT_OUT environment variable is not set. Run lunch first."
fi

if [ -z ${ANDROID_BUILD_TOP} ]; then
  exit_with_error "ANDROID_BUILD_TOP environment variable is not set. Run lunch first."
fi

if ! command -v zip >/dev/null 2>&1; then
  exit_with_error "zip is required but not found in PATH"
fi

TARGET=$(echo ${TARGET_PRODUCT} | sed 's/^aosp_//')

case "${TARGET}" in
  gbrpi4_car|gbrpi5_car)
    ;;
  *)
    exit_with_error "Unsupported target: ${TARGET}. mkimg.sh only supports gbrpi4_car and gbrpi5_car."
    ;;
esac

SIZE_GB_DEFAULT=15
SIZE_GB=${1:-${SIZE_GB_DEFAULT}}

if ! [[ "${SIZE_GB}" =~ ^[0-9]+$ ]]; then
  exit_with_error "Invalid size: '${SIZE_GB}'. Pass an integer number of GB (e.g. 32)."
fi

if [ ${SIZE_GB} -lt ${SIZE_GB_DEFAULT} ]; then
  exit_with_error "Requested size ${SIZE_GB}GB is smaller than the minimum (${SIZE_GB_DEFAULT}GB)."
fi

for PARTITION in "boot" "system" "vendor"; do
  if [ ! -f ${ANDROID_PRODUCT_OUT}/${PARTITION}.img ]; then
    exit_with_error "Partition image not found. Run 'make ${PARTITION}image' first."
  fi
done

VERSION=RaspberryVanillaAOSP16
DATE=$(date +%Y%m%d)
IMGDIR=${VERSION}-${DATE}-${TARGET}
IMGNAME=${IMGDIR}.img
ZIPNAME=${IMGDIR}.zip
IMGSIZE=$((${SIZE_GB} * 1024 * 1000 * 1000))

BOOT_PARTITION_SIZE=128
SYSTEM_PARTITION_SIZE=3072
VENDOR_PARTITION_SIZE=384
METADATA_PARTITION_SIZE=16
EXTENDED_PARTITION_SIZE=$((${SYSTEM_PARTITION_SIZE}+${VENDOR_PARTITION_SIZE}+${METADATA_PARTITION_SIZE}+4))

if [ -f ${ANDROID_PRODUCT_OUT}/${IMGNAME} ]; then
  exit_with_error "${ANDROID_PRODUCT_OUT}/${IMGNAME} already exists!"
fi

if [ -f ${ANDROID_BUILD_TOP}/${ZIPNAME} ]; then
  exit_with_error "${ANDROID_BUILD_TOP}/${ZIPNAME} already exists!"
fi

if [ -e ${ANDROID_PRODUCT_OUT}/${IMGDIR} ]; then
  exit_with_error "${ANDROID_PRODUCT_OUT}/${IMGDIR} already exists!"
fi

echo "Creating image file ${ANDROID_PRODUCT_OUT}/${IMGNAME}..."
sudo fallocate -l ${IMGSIZE} ${ANDROID_PRODUCT_OUT}/${IMGNAME}
sync

echo "Creating partitions..."
(
echo o

echo n
echo p
echo 1
echo
echo +${BOOT_PARTITION_SIZE}M

echo n
echo e
echo 2
echo
echo +${EXTENDED_PARTITION_SIZE}M

echo n
echo l
echo
echo +${SYSTEM_PARTITION_SIZE}M

echo n
echo l
echo
echo +${VENDOR_PARTITION_SIZE}M

echo n
echo l
echo
echo +${METADATA_PARTITION_SIZE}M

echo n
echo p
echo 3
echo
echo

echo t
echo 1
echo c
echo a
echo 1

echo w
) | sudo fdisk ${ANDROID_PRODUCT_OUT}/${IMGNAME}
sync

LOOPDEV=$(sudo kpartx -av ${ANDROID_PRODUCT_OUT}/${IMGNAME} | awk 'NR==1{ sub(/p[0-9]$/, "", $3); print $3 }')
if [ -z ${LOOPDEV} ]; then
  exit_with_error "Unable to find loop device!"
fi
echo "Image mounted as /dev/${LOOPDEV}"
sleep 1

echo "Copying boot..."
sudo dd if=${ANDROID_PRODUCT_OUT}/boot.img of=/dev/mapper/${LOOPDEV}p1 bs=1M
echo "Copying system..."
sudo dd if=${ANDROID_PRODUCT_OUT}/system.img of=/dev/mapper/${LOOPDEV}p5 bs=1M
echo "Copying vendor..."
sudo dd if=${ANDROID_PRODUCT_OUT}/vendor.img of=/dev/mapper/${LOOPDEV}p6 bs=1M
echo "Creating metadata..."
sudo mkfs.ext4 /dev/mapper/${LOOPDEV}p7 -I 512 -L metadata
echo "Creating userdata..."
sudo mkfs.ext4 /dev/mapper/${LOOPDEV}p3 -I 512 -L userdata
sync

sudo kpartx -d "/dev/${LOOPDEV}"
sudo losetup -d "/dev/${LOOPDEV}"
sudo chown ${USER}:${USER} ${ANDROID_PRODUCT_OUT}/${IMGNAME}

ALLOCATED_HUMAN=$(numfmt --to=iec ${IMGSIZE})
ONDISK_HUMAN=$(du -h ${ANDROID_PRODUCT_OUT}/${IMGNAME} | awk '{print $1}')

echo "Staging ${IMGNAME} into ${IMGDIR}/ for archiving..."
mkdir ${ANDROID_PRODUCT_OUT}/${IMGDIR}
mv ${ANDROID_PRODUCT_OUT}/${IMGNAME} ${ANDROID_PRODUCT_OUT}/${IMGDIR}/${IMGNAME}

echo "Zipping ${IMGDIR}/ to ${ANDROID_BUILD_TOP}/${ZIPNAME}..."
(cd ${ANDROID_PRODUCT_OUT} && zip -fz -r ${ANDROID_BUILD_TOP}/${ZIPNAME} ${IMGDIR})
ZIP_STATUS=$?

if [ ${ZIP_STATUS} -ne 0 ] || [ ! -f ${ANDROID_BUILD_TOP}/${ZIPNAME} ]; then
  exit_with_error "zip failed; leaving ${ANDROID_PRODUCT_OUT}/${IMGDIR}/ in place for inspection."
fi

ZIP_HUMAN=$(du -h ${ANDROID_BUILD_TOP}/${ZIPNAME} | awk '{print $1}')

echo "Removing ${ANDROID_PRODUCT_OUT}/${IMGDIR}/..."
rm -r ${ANDROID_PRODUCT_OUT}/${IMGDIR}

echo ""
echo "Image size report:"
echo "  allocated : ${ALLOCATED_HUMAN}"
echo "  on disk   : ${ONDISK_HUMAN}"
echo "  zipped    : ${ZIP_HUMAN}"
echo ""
echo "Done, created ${ANDROID_BUILD_TOP}/${ZIPNAME}!"
exit 0
