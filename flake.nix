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
          networking.hostName = "rpi";
          system.stateVersion = "24.11";

          # SSH for headless access
          services.openssh.enable = true;
          services.openssh.settings.PasswordAuthentication = false;
          services.openssh.settings.KbdInteractiveAuthentication = false;
          services.openssh.settings.PermitRootLogin = "no";

          virtualisation.docker.enable = true;

          boot.swraid.enable = true;

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

          networking.wireless.networks."mywifi".psk = "mypsk";

          ## (Alternative) NetworkManager if you prefer:
          # networking.networkmanager.enable = true;

          # Useful packages on the image
          environment.systemPackages = with pkgs; [vim git htop];

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
