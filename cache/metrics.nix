{ pkgs, lib, ... }:
let
  luaPrometheus = pkgs.stdenv.mkDerivation {
    name = "nginx-lua-prometheus";
    src = pkgs.fetchzip {
      url = "https://github.com/knyar/nginx-lua-prometheus/archive/refs/tags/0.20240525.tar.gz";
      sha256 = "sha256-ovLpOQKgTfrrgCxCF/OtdPUuAQ9J4RtT9F68Bbzu1XQ=";
    };
    installPhase = "cp -r . $out";
    };
  in
{
  config.systemd.services.nginx = {
    # Needed so LuaJIT can compile and run code
    serviceConfig.MemoryDenyWriteExecute = lib.mkForce false;
  };

  config.services.nginx = {
    appendHttpConfig = ''
      lua_package_path "${luaPrometheus}/?.lua;;";
      lua_shared_dict prometheus_metrics 10m;

      init_worker_by_lua_block {
        prometheus = require("prometheus").init("prometheus_metrics");
        metric_requests = prometheus:counter("lancache_requests_total", "Total number of HTTP requests processed by Nginx", {"origin", "status", "cache_status"});

        metric_requests:inc(1, {"lancache", "200", "MISS"});
      }

      log_by_lua_block {
        metric_requests:inc(1, {
          ngx.var.upstream_addr or "unknown",
          ngx.var.status or "500",
          ngx.var.cache_status or "MISS"
        });
      }
    '';

    virtualHosts.metrics = {
      listen = [{ addr = "0.0.0.0"; port = 9200; extraParameters = [ "default_server" ]; }];
      locations."/metrics" = {
        extraConfig = ''
          content_by_lua_block {
            prometheus:collect()
          }
        '';
      };
    };
  };
}
