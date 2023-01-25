{
  description = "DNS server for LANCache";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
  inputs.cache-domains.url = "github:uklans/cache-domains";
  inputs.cache-domains.flake = false;

  outputs = inputs@{ self, nixpkgs, cache-domains }:
    let
      system = "x86_64-linux";
      inherit (builtins) listToAttrs mapAttrs attrNames attrValues flatten split match readFile readDir filter toFile substring;
    in {
      dns = { config, lib, pkgs, ... }:
      let
        domains = filter
          (d: d != "" && match "^#.*" d == null)
          (lib.lists.flatten (
            map (f: split "\n" (
                readFile (cache-domains + "/${f}")
              )
            )
            (filter (f: match ".*txt$" f != null) (attrNames (readDir cache-domains)))
          ));

        ip = "1.2.3.7";
        zonefile = toFile "zonefile" "
\$TTL    600
@       IN  SOA ns1 dns.lancache.net. (
            ${substring 0 8 cache-domains.lastModifiedDate}
            604800
            600
            600
            600 )
@       IN  NS  ns1
ns1     IN  A   ${ip}

@       IN  A   ${ip}
*       IN  A   ${ip}
";
      in {
        config = {
          services.bind = {
            enable = true;
            forwarders = [ "1.1.1.1" "8.8.8.8" ];
            zones = listToAttrs (map (d: { name = d; value = { master = true; file = zonefile; }; }) (domains));
          };

          networking.firewall.allowedTCPPorts = [ 53 ];
          networking.resolvconf.useLocalResolver = false;
        };
      };
    };
}
