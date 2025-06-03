{
  description = "DNS server for LANCache";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.cache-domains.url = "github:uklans/cache-domains";
  inputs.cache-domains.flake = false;
  inputs.monolithic.url = "github:lancachenet/monolithic";
  inputs.monolithic.flake = false;

  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      flake = let
        cache = { pkgs, monolithic, ... }:
          pkgs.callPackage ./cache.nix { inherit monolithic; };
        dns = { pkgs, cache-domains, ... }:
          pkgs.callPackage ./dns.nix { inherit cache-domains; };
      in {
        nixosModules = {
          cache = cache;
          dns = dns;
        };
      };
      perSystem = { pkgs, ... }: {
        checks = {
          lancache = pkgs.callPackage ./test.nix {
            cache =
              pkgs.callPackage ./cache.nix { monolithic = inputs.monolithic; };
            dns = pkgs.callPackage ./dns.nix {
              cache-domains = inputs.cache-domains;
            };
          };
        };
      };
    };
}
