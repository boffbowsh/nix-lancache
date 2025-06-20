{ monolithic, cache-domains, cfg, pkgs }:
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
    MIN_FREE_DISK = cfg.minFreeDisk;
    LOG_FORMAT = cfg.logFormat;
    "/data/cache/cache" = cfg.cacheDir;
    "/data/logs" = cfg.logDir;
    "listen 80 reuseport;" = "listen 80 reuseport default_server;";
  };

  replacementFlags = concatStringsSep " " (lib.attrsets.mapAttrsToList (k: v: "--replace \"${k}\" \"${v}\"") replacements);

  builder = toFile "builder.sh" ''
    source $stdenv/setup
    base=$src/overlay/etc

    find $base/nginx -type f -name "*.conf" | sed 's/^.*\/etc\/nginx/nginx/g' | while read -r file; do
      mkdir -p $out/$(dirname $file)
      substitute $base/$file $out/$file \
        --replace /etc/nginx/ $out/nginx/ \
        ${replacementFlags} 2>/dev/null
    done

    # Modified from monolithic/overlay/hooks/entrypoint-pre.d/15_generate_maps.sh
    OUTPUTFILE=''${out}/nginx/conf.d/30_maps.conf
    echo "### This file is automatically generated by lancache-nginx-configs.nix" > $OUTPUTFILE

    echo "map \"\$http_user_agent£££\$http_host\" \$cacheidentifier {" >> $OUTPUTFILE
    echo "    default \$http_host;" >> $OUTPUTFILE
    echo "    ~Valve\\/Steam\\ HTTP\\ Client\\ 1\.0£££.* steam;" >> $OUTPUTFILE
    jq -r '.cache_domains | to_entries[] | .key' ${cache-domains + "/cache_domains.json"} | while read CACHE_ENTRY; do 
      #for each cache entry, find the cache indentifier
      CACHE_IDENTIFIER=$(jq -r ".cache_domains[$CACHE_ENTRY].name" ${cache-domains + "/cache_domains.json"})
      jq -r ".cache_domains[$CACHE_ENTRY].domain_files | to_entries[] | .key" ${cache-domains + "/cache_domains.json"} | while read CACHEHOSTS_FILEID; do
        #Get the key for each domain files
        jq -r ".cache_domains[$CACHE_ENTRY].domain_files[$CACHEHOSTS_FILEID]" ${cache-domains + "/cache_domains.json"} | while read CACHEHOSTS_FILENAME; do
          #Get the actual file name
          cat ${cache-domains}/''${CACHEHOSTS_FILENAME} | while read CACHE_HOST; do
            #for each file in the hosts file
            #remove all whitespace (mangles comments but ensures valid config files)
            CACHE_HOST=''${CACHE_HOST// /}
            if [ ! "x''${CACHE_HOST}" == "x" ]; then
              #Use sed to replace . with \. and * with .*
              REGEX_CACHE_HOST=$(sed -e "s#\.#\\\.#g" -e "s#\*#\.\*#g" <<< ''${CACHE_HOST})
              echo "    ~.*£££.*?''${REGEX_CACHE_HOST} ''${CACHE_IDENTIFIER};" >> $OUTPUTFILE
            fi
          done
        done
      done
    done
    echo "}" >> $OUTPUTFILE
  '';
in
stdenv.mkDerivation {
  name = "lancache-nginx-configs";
  builder = "${bash}/bin/bash";
  buildInputs = [ jq ];
  args = [ builder ];
  src = monolithic;
  system = builtins.currentSystem;
}
