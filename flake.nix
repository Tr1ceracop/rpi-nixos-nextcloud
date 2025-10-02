{
  description = "Raspberry Pi NixOS SD image";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "aarch64-linux"; # RPi uses ARM64
    lib = nixpkgs.lib;
  in {
    nixosConfigurations.rpi = lib.nixosSystem {
      inherit system;

      # You can pass custom args to all modules via specialArgs if needed:
      # specialArgs = { ... };

      modules = [
        # SD-card image support (provides .config.system.build.sdImage)
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"

        # (Optionally) a Raspberry Pi profile; pick the one that matches your model.
        # It sets the right firmware/boot bits.
        # "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-raspberrypi.nix"

        # Your actual system config for the live/installed system
        ({
          config,
          pkgs,
          ...
        }: {
          networking.hostName = "nextcloud";
          system.stateVersion = "24.11";

          boot.swraid.enable = true;

          # Tell systemd-cryptsetup to unlock the LUKS container with the keyfile
          # NAME  DEVICE                      KEYFILE                      OPTIONS
          environment.etc."crypttab".text = ''
            ncdata UUID=8511a302-809a-484b-a6fb-53504c9b3655 /etc/keys/data-raid.key luks,tries=3,timeout=30s
          '';

          # Mount the decrypted mapper device
          fileSystems."/mnt/nextcloud_data" = {
            device = "/dev/mapper/ncdata";
            fsType = "ext4"; # or xfs/btrfs/zfs dataset etc.
            # noauto,x-systemd.automount can be used if you want lazy on-demand mounts:
            # options = [ "x-systemd.automount" "noauto" ];
          };

          # SSH for headless access
          services.openssh.enable = true;
          services.openssh.settings.PasswordAuthentication = false;
          services.openssh.settings.KbdInteractiveAuthentication = false;
          services.openssh.settings.PermitRootLogin = "no";

          virtualisation.docker.enable = true;

          programs.zsh = {
            enable = true;
            ohMyZsh = {
              enable = true;
              theme = "robbyrussell"; # pick any oh-my-zsh theme
              plugins = ["git" "docker" "kubectl" "sudo"]; # available oh-my-zsh plugins
            };
          };

          users.defaultUserShell = pkgs.zsh;
          # Create a user you can SSH into
          users.users.pi = {
            isNormalUser = true;
            extraGroups = ["wheel" "networkmanager" "docker"];
            openssh.authorizedKeys.keys = [
              # ⬇️ paste your real public key here
            ];
            # Lock the local password: no TTY/serial/console password login possible
            hashedPassword = "!";
          };

          users.users.root.hashedPassword = "!";

          security.sudo.wheelNeedsPassword = false;

          # Choose one network approach:

          ## A) ETHERNET-only out of the box (simplest)
          # nothing to do; just plug it in.

          ## B) Headless Wi-Fi with wpa_supplicant (simple & robust)
          networking.wireless.enable = true;

          # networking.wireless.networks."mywifi".psk = "mypsk";

          time.timeZone = "Europe/Berlin";

          systemd.services."daily-reboot" = {
            description = "Reboot the system daily at 02:00";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.systemd}/bin/systemctl reboot";
            };
          };

          systemd.timers."daily-reboot" = {
            wantedBy = ["timers.target"];
            timerConfig = {
              # Every day at 02:00 local time
              OnCalendar = "02:00";
              # If the Pi was off/asleep at 02:00, run it shortly after boot
              Persistent = true;
            };
          };

          # Useful packages on the image
          environment.systemPackages = with pkgs; [vim git htop alejandra sops age tmux];

          # Firmware
          hardware.enableRedistributableFirmware = true;

          # (Optional) Tweak the generated filename
          # iso/sd-image options live under config.image / config.sdImage
          sdImage.imageName = "nixos-rpi-${system}.img";
        })
      ];
    };
  };
}
