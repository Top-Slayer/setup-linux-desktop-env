#!/bin/bash

custom_drive() {
  DISK="/dev/sdx"

  EFI_SIZE="1GiB"
  SWAP_SIZE="4GiB"

  # 1. Create GPT partition table
  sudo parted -s $DISK mklabel gpt

  # 2. Create EFI System Partition
  sudo parted -s $DISK mkpart primary fat32 1MiB $EFI_SIZE
  sudo parted -s $DISK set 1 esp on

  # 3. Create Swap Partition
  EFI_END=$(sudo parted $DISK unit MiB print | awk '/^ 1 / {print $3}' | tr -d 'MiB')
  if ! [[ "$EFI_END" =~ ^[0-9]+$ ]]; then
      echo "Error: Could not get EFI partition end"
      exit 1
  fi
  SWAP_START=$(($EFI_END))
  SWAP_END=$(($SWAP_START + 4096))  # 4 GiB
  sudo parted -s $DISK mkpart primary linux-swap ${SWAP_START}MiB ${SWAP_END}MiB

  # 4. Create Root Partition (remaining)
  sudo parted -s $DISK mkpart primary ext4 ${SWAP_END}MiB 100%

  # 5. Format partitions
  sudo mkfs.fat -F32 ${DISK}1        # EFI
  sudo mkswap ${DISK}2                # Swap
  sudo mkfs.ext4 ${DISK}3              # Root

  # 6. Enable swap
  sudo swapon ${DISK}2

  echo "✅ Partitions created:"
  sudo parted $DISK print
}

check_internet() {
  HOST="8.8.8.8"
  if ping -c 1 -W 5 $HOST >/dev/null 2>&1; then
      echo "✅ Internet is connected"
  else
      echo "❌ No internet connection"
      exit 1
  fi
}

check_user() {
  if [ "$EUID" -ne 0 ]; then
      echo "❌ You are not root"
      exit 1
  else
      echo "✅ You are root"
  fi
}

# loadkeys us
#
check_user
check_internet
custom_drive


