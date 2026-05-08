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

if ! command -v xz >/dev/null 2>&1; then
  exit_with_error "xz is required but not found in PATH"
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
SIZE_GB=${SIZE_GB_DEFAULT}
OUTPUT_PATH=""
FORCE=0

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] [SIZE_GB]
  -o, --output PATH   Final .img.xz path (default: \$ANDROID_BUILD_TOP/<derived>.img.xz)
  -f, --force         Overwrite any existing intermediate img or output archive
  -h, --help          Show this help
  SIZE_GB             Image size in GB (default: ${SIZE_GB_DEFAULT}, also the minimum)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output)
      [ -z "$2" ] && exit_with_error "$1 requires a path argument."
      OUTPUT_PATH="$2"; shift 2 ;;
    -f|--force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) exit_with_error "Unknown option: $1 (use -h for help)" ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        SIZE_GB="$1"; shift
      else
        exit_with_error "Unexpected argument: '$1' (use -h for help)"
      fi ;;
  esac
done

if ! [[ "${SIZE_GB}" =~ ^[0-9]+$ ]]; then
  exit_with_error "Invalid size: '${SIZE_GB}'. Pass an integer number of GB (e.g. 32)."
fi

if [ -n "${OUTPUT_PATH}" ]; then
  case "${OUTPUT_PATH}" in
    /*) ;;
    *)  OUTPUT_PATH="${PWD}/${OUTPUT_PATH}" ;;
  esac
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

if [ -n "${OUTPUT_PATH}" ]; then
  IMGDIR=$(basename "${OUTPUT_PATH}")
  IMGDIR=${IMGDIR%.xz}
  IMGDIR=${IMGDIR%.img}
fi

IMGNAME=${IMGDIR}.img
XZNAME=${IMGNAME}.xz
XZDEST=${OUTPUT_PATH:-${ANDROID_BUILD_TOP}/${XZNAME}}
IMGSIZE=$((${SIZE_GB} * 1024 * 1000 * 1000))

BOOT_PARTITION_SIZE=128
SYSTEM_PARTITION_SIZE=3072
VENDOR_PARTITION_SIZE=384
METADATA_PARTITION_SIZE=16
EXTENDED_PARTITION_SIZE=$((${SYSTEM_PARTITION_SIZE}+${VENDOR_PARTITION_SIZE}+${METADATA_PARTITION_SIZE}+4))

for EXISTING in \
    "${ANDROID_PRODUCT_OUT}/${IMGNAME}" \
    "${XZDEST}"; do
  if [ -e "${EXISTING}" ]; then
    if [ ${FORCE} -eq 1 ]; then
      echo "Removing existing ${EXISTING} (--force)..."
      rm -rf "${EXISTING}" || exit_with_error "Failed to remove ${EXISTING}"
    else
      exit_with_error "${EXISTING} already exists! (use -f to overwrite)"
    fi
  fi
done

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

XZDEST_DIR=$(dirname "${XZDEST}")
mkdir -p "${XZDEST_DIR}" || exit_with_error "Cannot create output directory ${XZDEST_DIR}"

echo "Compressing ${IMGNAME} with xz -T0 -6 to ${XZDEST}..."
xz -T0 -6 -c "${ANDROID_PRODUCT_OUT}/${IMGNAME}" > "${XZDEST}"
XZ_STATUS=$?

if [ ${XZ_STATUS} -ne 0 ] || [ ! -f "${XZDEST}" ]; then
  rm -f "${XZDEST}"
  exit_with_error "xz failed; leaving ${ANDROID_PRODUCT_OUT}/${IMGNAME} in place for inspection."
fi

XZ_HUMAN=$(du -h "${XZDEST}" | awk '{print $1}')

echo "Removing ${ANDROID_PRODUCT_OUT}/${IMGNAME}..."
rm "${ANDROID_PRODUCT_OUT}/${IMGNAME}"

echo ""
echo "Image size report:"
echo "  allocated  : ${ALLOCATED_HUMAN}"
echo "  on disk    : ${ONDISK_HUMAN}"
echo "  compressed : ${XZ_HUMAN}"
echo ""
echo "Done, created ${XZDEST}!"
exit 0
