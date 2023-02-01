{ monolithic }: { config, lib, pkgs, ... }:
with builtins;
with lib;
let
  cfg = config.lancache.cache;

  nginxConfigs = import ./cache/nginx-configs.nix { inherit pkgs monolithic cfg; };

  nginx = pkgs.nginx.overrideAttrs (old: {
    configureFlags = old.configureFlags ++ ["--with-http_slice_module"];
  });
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
      cacheDiskSize = mkOption {
        description = "The amount of disk space we should use for caching data";
        type = with types; str;
        default = "1000g";
      };
      cacheIndexSize = mkOption {
        description = "Amount of index memory for the nginx cache manager. We recommend 250m of index memory per 1TB of cacheDiskSize";
        type = with types; str;
        default = "500m";
      };
      cacheMaxAge = mkOption {
        description = "The maximum amount of time a file should be held in cache. There is usually no reason to reduce this - the cache will automatically remove the oldest content if it needs the space.";
        type = with types; str;
        default = "3560d";
      };
      nginxWorkerProcesses = mkOption {
        description = "The number of nginx worker processes to run. Defaults to auto, which will use the number of CPU cores.";
        type = with types; str;
        default = "auto";
      };
      cacheSliceSize = mkOption {
        description = "See https://lancache.net/docs/advanced/tuning-cache/#tweaking-slice-size. Probably don't change this.";
        type = with types; str;
        default = "1m";
      };
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedOptimisation = true;
      resolver.addresses = cfg.resolvers;
      package = nginx;
      appendHttpConfig = ''
        include ${nginxConfigs}/nginx/conf.d/*.conf;
        include ${nginxConfigs}/nginx/sites-available/*.conf;
      '';
      virtualHosts = { };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
