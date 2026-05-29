{ pkgs, ... }:

{
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = false;

  fileSystems."/" = {
    device = "/dev/disk/by-label/rootpart";
    fsType = "f2fs";
    options = [
      "compress_algorithm=zstd:3"
      "noatime"
      "nodiratime"
      "atgc"
      "gc_merge"
      "lazytime"
      "inline_xattr"
    ];
  };

  hardware.enableRedistributableFirmware = true;
  networking.networkmanager.enable = true;
  services.timesyncd.enable = true;
  zramSwap.enable = true;

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  users.users.root.initialPassword = "root";
  users.users.alarm = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "alarm";
  };

  environment.systemPackages = with pkgs; [
    alsa-utils
    networkmanager
    pipewire
    rmtfs
  ];

  system.stateVersion = "26.05";
}
