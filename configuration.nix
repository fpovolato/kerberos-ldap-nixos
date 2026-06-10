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
    ncurses
    openldap
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
        networking.firewall.allowedTCPPorts = [
          389
          88
          749
        ];
        networking.firewall.allowedUDPPorts = [ 88 ];
        services.resolved.enable = true;

        services.openldap = {
          enable = true;
          urlList = [ "ldap:///" ];

          settings = {
            attrs.olcLogLevel = "conns config";

            children = {
              "cn=schema".includes = [
                "${pkgs.openldap}/etc/schema/core.ldif"
                "${pkgs.openldap}/etc/schema/cosine.ldif"
                "${pkgs.openldap}/etc/schema/inetorgperson.ldif"
                "${pkgs.openldap}/etc/schema/nis.ldif"
              ];

              "olcDatabase={1}mdb".attrs = {
                objectClass = [
                  "olcDatabaseConfig"
                  "olcMdbConfig"
                ];
                olcdatabase = "{1}mdb";
                olcDbDirectory = "/var/lib/openldap/data";
                olcSuffix = "dc=example,dc=lan";
                olcRootDN = "cn=admin,dc=example,dc=lan";
                olcRootPw.path = pkgs.writeText "olcRootPW" "adminpass";

                olcAccess = [
                  ''
                    {0}to attrs=userPassword
                                        by self write
                                        by anonymous auth
                                        by * none''
                  ''
                    {1}to *
                                        by * read''
                ];
              };
            };
          };

          # Popola il DB al primo avvio
          declarativeContents."dc=example,dc=lan" = ''
            dn: dc=example,dc=lan
            objectClass: top
            objectClass: dcObject
            objectClass: organization
            o: Example Organization
            dc: example

            dn: ou=People,dc=example,dc=lan
            objectClass: top
            objectClass: organizationalUnit
            ou: People

            dn: ou=Groups,dc=example,dc=lan
            objectClass: top
            objectClass: organizationalUnit
            ou: Groups

            dn: uid=mario.rossi,ou=People,dc=example,dc=lan
            objectClass: inetOrgPerson
            objectClass: posixAccount
            cn: Mario Rossi
            sn: Rossi
            uid: mario.rossi
            uidNumber: 10001
            gidNumber: 10001
            homeDirectory: /home/mario.rossi
            loginShell: /bin/bash

            dn: uid=luigi.verdi,ou=People,dc=example,dc=lan
            objectClass: inetOrgPerson
            objectClass: posixAccount
            cn: Luigi Verdi
            sn: Verdi
            uid: luigi.verdi
            uidNumber: 10002
            gidNumber: 10001
            homeDirectory: /home/luigi.verdi
            loginShell: /bin/bash

            dn: cn=utenti,ou=Groups,dc=example,dc=lan
            objectClass: posixGroup
            cn: utenti
            gidNumber: 10001
            memberUid: mario.rossi
            memberUid: luigi.verdi
          '';
        };

        services.kerberos_server = {
          enable = true;
          realms."EXAMPLE_LAN".acl = [
            {
              access = "all";
              principal = "admin/admin";
            }
          ];
        };

        security.krb5 = {
          enable = true;
          settings = {
            libdefaults.default_realm = "EXAMPLE_LAN";
            realms."EXAMPLE_LAN" = {
              kdc = "srv.example.lan";
              admin_server = "srv.example.lan";
            };
            domain_realm = {
              ".example.lan" = "EXAMPLE_LAN";
              "example.lan" = "EXAMPLE_LAN";
            };
          };
        };

        environment.systemPackages = with pkgs; [
          neovim
          openldap
          krb5
        ];
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
