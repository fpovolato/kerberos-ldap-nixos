{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "host";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Rome";

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    initialPassword = "passwd";
    packages = with pkgs; [
      tree
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    gh
    vim
    wget
    neovim
  ];

  services.openssh.enable = true;

  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "enp0s1";
  };

  networking.extraHosts = ''
    192.168.100.11 srv srv.example.lan
    192.168.100.12 client client.example.lan
  '';

  containers.srv = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.10";
    localAddress = "192.168.100.11";

    config =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;
        environment.systemPackages = with pkgs; [ neovim ];
        system.stateVersion = "26.05";
      };
  };

  containers.client = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.10";
    localAddress = "192.168.100.12";

    config =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;
        environment.systemPackages = with pkgs; [ neovim ];
        system.stateVersion = "26.05";
      };
  };

  system.stateVersion = "26.05"; # Did you read the comment?

}
