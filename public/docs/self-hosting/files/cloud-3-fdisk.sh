#!/bin/bash

# --- Configuration ---
# ⚠️ 请确保以下磁盘名称配置正确！
LOCAL_DISK="vdb"          # 用于本地存储（/data）的磁盘
CSI_DISK="vdc"            # 用于CSI的LVM存储的磁盘
MOUNT_POINT="/data"       # 本地存储的挂载路径
VG_NAME_LOCAL="vg_data"   # /data 使用的卷组名称
LV_NAME_LOCAL="lv_data"   # /data 使用的逻辑卷名称
VG_NAME_CSI="vg_k8s"      # CSI使用的卷组名称

# --- Helper functions ---

# Print info messages
info() {
  echo "[INFO] $1"
}

# Print error messages
error() {
  echo "[ERROR] $1" >&2
}

# Check if a block device exists and is not mounted
check_device_is_ready() {
  local device="/dev/$1"
  if [ ! -b "$device" ]; then
    error "Block device $device does not exist."
    return 1
  fi
  if lsblk -no MOUNTPOINT "$device" | grep -q '/'; then
    error "Device $device is currently mounted. Please unmount it first."
    return 1
  fi
  return 0
}

# Setup LVM on a disk for a specific mount point (e.g., /data)
setup_lvm_for_mountpoint() {
  local device="/dev/$LOCAL_DISK"
  local vg_name="$VG_NAME_LOCAL"
  local lv_name="$LV_NAME_LOCAL"
  local mount_point="$MOUNT_POINT"

  info "Setting up LVM for local storage on device: $device"

  # Remove any existing partition table or LVM signatures
  sgdisk --zap-all "$device"
  wipefs -a "$device"

  # Create Physical Volume (PV)
  pvcreate "$device"
  info "Created physical volume on $device"

  # Create Volume Group (VG)
  vgcreate "$vg_name" "$device"
  info "Created volume group: $vg_name"

  # Create Logical Volume (LV) using all available space
  lvcreate -l 100%FREE -n "$lv_name" "$vg_name"
  local lv_path="/dev/$vg_name/$lv_name"
  info "Created logical volume: $lv_path"

  # Format the new logical volume
  mkfs.ext4 -F "$lv_path"
  info "Formatted $lv_path with ext4"

  # Create mount point and mount the logical volume
  mkdir -p "$mount_point"
  mount "$lv_path" "$mount_point"
  info "Mounted $lv_path to $mount_point"

  # Add entry to /etc/fstab for persistent mount using UUID
  local uuid=$(blkid -s UUID -o value "$lv_path")
  echo "UUID=$uuid $mount_point ext4 defaults 0 0" >> /etc/fstab
  info "Added entry to /etc/fstab for $mount_point"
}

# Setup LVM on a disk for CSI
setup_lvm_for_csi() {
  local device="/dev/$CSI_DISK"
  local vg_name="$VG_NAME_CSI"

  info "Setting up LVM for CSI on device: $device"

  # Remove any existing partition table or LVM signatures
  sgdisk --zap-all "$device"
  wipefs -a "$device"

  # Create physical volume (PV)
  pvcreate "$device"
  info "Created physical volume on $device"

  # Create or extend volume group (VG)
  if ! vgdisplay "$vg_name" &>/dev/null; then
    vgcreate "$vg_name" "$device"
    info "Created volume group: $vg_name"
  else
    vgextend "$vg_name" "$device"
    info "Extended existing volume group: $vg_name"
  fi
}

# --- Main logic ---
main() {
  # Validate local disk configuration
  check_device_is_ready "$LOCAL_DISK" || exit 1
  info "Selected local storage disk: /dev/$LOCAL_DISK"

  # Set up /data with LVM
  setup_lvm_for_mountpoint
  if [ $? -ne 0 ]; then
    error "Local storage LVM setup failed."
    exit 1
  fi

  # Conditional check and setup for CSI_DISK
  if [ -n "$CSI_DISK" ]; then
    info "Selected CSI storage disk: /dev/$CSI_DISK"
    check_device_is_ready "$CSI_DISK" || exit 1
    setup_lvm_for_csi
    if [ $? -ne 0 ]; then
      error "CSI LVM setup failed."
      exit 1
    fi
  else
    info "CSI_DISK is not set. Skipping LVM storage setup for CSI."
  fi

  info "Setup complete. Please verify /etc/fstab and reboot to ensure changes persist."
}

# Run the main logic
main