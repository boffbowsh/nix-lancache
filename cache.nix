{ monolithic, nixpkgs }: { config, lib, pkgs, ... }:
with builtins;
with lib;
let
  replacements = {
    CACHE_INDEX_SIZE = "500m";
    CACHE_DISK_SIZE = "1000g";
    CACHE_MAX_AGE = "3560d";
    CACHE_SLICE_SIZE = "1m";
    BEAT_TIME = "1h";
    LOGFILE_RETENTION = "3560";
    NGINX_WORKER_PROCESSES = "auto";
    UPSTREAM_DNS = concatStringsSep " " config.lancache.cache.resolvers;
  };

  cfg = config.lancache.cache;

  nginxConfigs = import ./cache/nginx-configs.nix { inherit pkgs monolithic replacements; };
in
{
  options = {
    lancache.cache = {
      enable = mkEnableOption "Enables the Lancache monolithic cache server";
      cacheIp = mkOption {
        description = "IP of cache server to advertise via DNS";
        type = with types; str;
      };
      resolvers = mkOption {
        description = "Upstream DNS servers. Defaults to CloudFlare and Google public DNS";
        type = with types; listOf str;
        default = [ "1.1.1.1" "8.8.8.8" ];
      };
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedOptimisation = true;
      resolver.addresses = cfg.resolvers;
      package = nixpkgs.legacyPackages.x86_64-linux.nginxStable.override { withSlice = true; };
      appendHttpConfig = ''
        include ${nginxConfigs}/nginx/conf.d/*.conf;
        include ${nginxConfigs}/nginx/sites-available/*.conf;
      '';
      virtualHosts = { };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
