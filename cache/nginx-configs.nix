{ monolithic, cfg, pkgs }:
with builtins;
with pkgs;
let
  replacements = {
    CACHE_INDEX_SIZE = cfg.cacheIndexSize;
    CACHE_DISK_SIZE = cfg.cacheDiskSize;
    CACHE_MAX_AGE = cfg.cacheMaxAge;
    CACHE_SLICE_SIZE = cfg.cacheSliceSize;
    NGINX_WORKER_PROCESSES = cfg.nginxWorkerProcesses;
    UPSTREAM_DNS = concatStringsSep " " cfg.resolvers;
    "/data/cache/cache" = cfg.cacheDir;
    "listen 80 reuseport;" = "listen 80 reuseport default_server;";
  };

  replacementFlags = concatStringsSep " " (lib.attrsets.mapAttrsToList (k: v: "--replace \"${k}\" \"${v}\"") replacements);

  builder = toFile "builder.sh" ''
    source $stdenv/setup
    base=$src/overlay/etc

    find $base/nginx -type f -name "*.conf" | sed 's/^.*\/etc\/nginx/nginx/g' | while read -r file; do
      echo $file
      mkdir -p $out/$(dirname $file)
      substitute $base/$file $out/$file \
        --replace /etc/nginx/ $out/nginx/ \
        ${replacementFlags} 2>/dev/null

    done
  '';
in
stdenv.mkDerivation {
  name = "lancache-nginx-configs";
  builder = "${bash}/bin/bash";
  args = [ builder ];
  src = monolithic;
  system = builtins.currentSystem;
}
