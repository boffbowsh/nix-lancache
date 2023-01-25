{
  description = "DNS server for LANCache";

  inputs.cache-domains.url = "github:uklans/cache-domains";
  inputs.cache-domains.flake = false;

  outputs = inputs@{ self, cache-domains }:
    with builtins;
    let
      system = "x86_64-linux";
    in
    {
      nixosModules = {
        dns = { config, lib, pkgs, ... }:
          with lib;
          let
            cfg = config.lancache.dns;

            domains = filter
              (d: d != "" && match "^#.*" d == null)
              (lib.lists.flatten (
                map
                  (f: split "\n" (
                    readFile (cache-domains + "/${f}")
                  )
                  )
                  (filter (f: match ".*txt$" f != null) (attrNames (readDir cache-domains)))
              ));

            ip = cfg.cacheIp;
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
          in
          {
            options = {
              lancache.dns = {
                enable = mkEnableOption "Enables the Lancache DNS server";
                forwarders = mkOption {
                  description = "Upstream DNS servers. Defaults to CloudFlare and Google public DNS";
                  type = with types; listOf str;
                  default = [ "1.1.1.1" "8.8.8.8" ];
                };
                cacheIp = mkOption {
                  description = "IP of cache server to advertise via DNS";
                  type = with types; str;
                };
              };
            };

            config = mkIf cfg.enable {
              services.bind = {
                enable = true;
                forwarders = cfg.forwarders;
                zones = listToAttrs (map (d: { name = d; value = { master = true; file = zonefile; }; }) (domains));
              };

              networking.firewall.allowedTCPPorts = [ 53 ];
              networking.resolvconf.useLocalResolver = false;
            };
          };
      };
    };
}
