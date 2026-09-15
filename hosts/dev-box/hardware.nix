# Hetzner Cloud x86 (cx*/cpx*): BIOS boot, virtio-scsi root at /dev/sda1.
# Mirrors what nixos-infect generates on these boxes, kept static so the flake
# is pure. Root stays the Ubuntu partition that infect converted in place.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub.device = "/dev/sda";
  boot.initrd.availableKernelModules = [
    "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi"
    "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"
  ];
  boot.tmp.cleanOnBoot = true;

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  # Persistent Hetzner volume (stacks/dev-box/volume.tf). Label set by cloud-init.
  # neededForBoot so it is mounted in stage 1, before user/home activation.
  fileSystems."/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "ext4";
    neededForBoot = true;
  };

  zramSwap.enable = true;

  # IPv4 by DHCP (Hetzner Cloud supports it); IPv6 is disabled on the server.
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = "x86_64-linux";
}
