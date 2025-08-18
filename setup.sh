#!/bin/bash

custom_drive() {
  DISK="/dev/sda"

  EFI_SIZE="500MiB"
  SWAP_SIZE="4GiB"

  SWAP_SIZE_MIB=$(numfmt --from=iec --to=si --suffix=MiB "$SWAP_SIZE" | sed 's/MiB//')

  for swap in $(cat /proc/swaps | awk '{print $1}' | grep "$DISK"); do
      echo "Disabling swap $swap..."
      swapoff $swap
  done

  for part in $(lsblk -ln -o NAME,MOUNTPOINT | grep "$DISK" | awk '{print "/dev/"$1}'); do
      mountpoint=$(lsblk -ln -o MOUNTPOINT $part)
      if [ -n "$mountpoint" ]; then
          echo "Unmounting $part..."
          umount $part
      fi
  done

  for i in $(parted -m $DISK print | awk -F: 'NR>1 {print $1}' | sort -r); do
    parted -s $DISK rm $i
  done


  # 1. Create GPT partition table
  parted -s $DISK mklabel gpt

  # 2. Create EFI System Partition
  parted -s $DISK mkpart primary fat32 1MiB $EFI_SIZE
  parted -s $DISK set 1 esp on

  # 3. Create Swap Partition
  EFI_END=$(parted $DISK unit MiB print | awk '/^ 1 / {print $3}' | tr -d 'MiB')
  if ! [[ "$EFI_END" =~ ^[0-9]+$ ]]; then
      echo "Error: Could not get EFI partition end"
      exit 1
  fi
  SWAP_START=$(($EFI_END))
  SWAP_END=$(($SWAP_START + $SWAP_SIZE_MIB))
  parted -s $DISK mkpart primary linux-swap ${SWAP_START}MiB ${SWAP_END}MiB

  # 4. Create Root Partition (remaining)
  parted -s $DISK mkpart primary ext4 ${SWAP_END}MiB 100%

  # 5. Format partitions
  mkfs.fat -F32 ${DISK}1        # EFI
  mkswap ${DISK}2                # Swap
  mkfs.ext4 ${DISK}3              # Root

  # 6. Enable swap
  swapon ${DISK}2

  echo "[O] Partitions created:"
  parted $DISK print
}

check_internet() {
  HOST="8.8.8.8"
  if ping -c 1 -W 5 $HOST >/dev/null 2>&1; then
      echo "[O] Internet is connected"
  else
      echo "[X] No internet connection"
      exit 1
  fi
}

check_user() {
  if [ "$EUID" -ne 0 ]; then
      echo "[X] You are not root"
      exit 1
  else
      echo "[O] You are root"
  fi
}

# loadkeys us
#
check_user
check_internet
custom_drive


