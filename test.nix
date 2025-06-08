{cache, dns, pkgs, ...}:
    pkgs.nixosTest {
      name = "lancache";

      nodes = {
        upstream = {pkgs, lib, config, nodes, ...}: 
        let
          ip = nodes.upstream.networking.primaryIPAddress;
          zonefile = builtins.toFile "zonefile" "
\$TTL    600
@       IN  SOA ns1 dns.steamcontent.net. (
            2025050501
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
          services.nginx = {
            enable = true;
            virtualHosts = {
              "lancache.steamcontent.com" = {
                locations."/" = {
                  root = pkgs.writeTextDir "index.html" "Hello, world!";
                };
              };
            };
          };

          services.bind = {
            enable = true;
            zones = {
              "steamcontent.com" = {
                name = "steamcontent.com";
                master = true;
                file = zonefile;
              };
            };
          };
          
          networking.firewall.allowedTCPPorts = [ 80 443 ];
          networking.firewall.allowedUDPPorts = [ 53 ];
        };

        server = {pkgs, lib, config, nodes, ...}: {
          imports = [
            cache
            dns
          ];

          environment.systemPackages = [
            pkgs.dig
          ];

          services.lancache = {
            dns = {
              forwarders = [ nodes.upstream.networking.primaryIPAddress ];
              enable = true;
              cacheIp = nodes.server.networking.primaryIPAddress;
            };
            cache = {
              enable = true;
              resolvers = [ nodes.upstream.networking.primaryIPAddress ];
            };
          };

          networking.firewall.allowedTCPPorts = [ 80 443 ];
        };
        client = {pkgs, lib, nodes, ...}: {
          environment.systemPackages = [
            pkgs.dig
          ];
          networking.nameservers = [
            nodes.server.networking.primaryIPAddress
          ];
        };
      };

      testScript = {nodes, ...}: 
      ''
        start_all()

        upstream.wait_for_open_port(80)

        server.wait_for_unit("nginx.service")

        server.succeed("dig +short lancache.steamcontent.com @${nodes.upstream.networking.primaryIPAddress}")

        client.succeed("ping -c 1 server")
        client.succeed("dig +short lancache.steamcontent.com @${nodes.server.services.lancache.dns.cacheIp} | grep -q ${nodes.server.services.lancache.dns.cacheIp}")
        client.succeed("curl -s -o /dev/null -w '%{http_code}' http://lancache.steamcontent.com | grep -q 200")
        client.succeed("curl -s -o /dev/null -w '%{http_code}' http://lancache.steamcontent.com | grep -q 200")

        server.succeed("curl http://127.0.0.1:9200/metrics | grep -q 'lancache_requests_total{cache=\"steam\",status=\"200\",cache_status=\"MISS\"}'")
        server.succeed("curl http://127.0.0.1:9200/metrics | grep -q 'lancache_requests_total{cache=\"steam\",status=\"200\",cache_status=\"HIT\"}'")
      ''; 
    }
