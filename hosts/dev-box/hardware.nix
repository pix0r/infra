# KVM guest on UpCloud (virtio disks + nic). Root layout comes from disko.nix.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true; # no NVRAM entries needed; works BIOS or UEFI
    # device comes from disko.nix (the EF02 partition on /dev/vda)
  };
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_scsi" "virtio_net" "sd_mod" ];
  boot.tmp.cleanOnBoot = true;

  # Persistent UpCloud storage (stacks/upcloud-dev-box/storage.tf). Its ext4 label
  # is set once by cloud-init before install. neededForBoot so it is mounted in
  # stage 1, before user/home activation.
  fileSystems."/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "ext4";
    neededForBoot = true;
  };

  zramSwap.enable = true;

  # UpCloud hands out the public IPv4 by DHCP.
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = "x86_64-linux";
}
