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
      flake = { pkgs, monolithic, cache-domains, ... }: {
        nixosModules = {
          cache =  { config, lib, pkgs, ... }:
            (import ./cache.nix { monolithic = inputs.monolithic; }) { inherit lib pkgs config; };
          dns = { config, lib, pkgs, ... }:
            (import ./dns.nix { cache-domains = inputs.cache-domains; }) { inherit lib pkgs config; };
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
