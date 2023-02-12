{ cache-domains }: { config, lib, pkgs, ... }:
with lib;
with builtins;
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
      cacheNetworks = [ "192.168.0.0/24" "127.0.0.0/24" ];
      zones = listToAttrs (map (d: { name = d; value = { master = true; file = zonefile; }; }) (domains));
    };

    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.resolvconf.useLocalResolver = true;
  };
}
