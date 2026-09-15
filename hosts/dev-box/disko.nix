# Root disk layout, applied by nixos-anywhere/disko at install time only.
# Hybrid BIOS + UEFI so it boots on any KVM host. The persistent /data volume is
# deliberately NOT declared here: disko formats everything it owns, and /data
# must survive reinstalls (it is mounted by label in hardware.nix instead).
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/vda"; # UpCloud attaches the template disk on virtio
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02"; # grub MBR stage for BIOS boot
        };
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
