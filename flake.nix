{
  description = "DNS server for LANCache";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.cache-domains.url = "github:uklans/cache-domains";
  inputs.cache-domains.flake = false;
  inputs.monolithic.url = "github:lancachenet/monolithic";
  inputs.monolithic.flake = false;

  outputs = inputs@{ self, cache-domains, monolithic, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      test = pkgs.callPackage ./test.nix;
      cache = pkgs.callPackage ./cache.nix { inherit monolithic; };
      dns = pkgs.callPackage ./dns.nix { inherit cache-domains; };
    in
    {
      nixosModules = {
        cache = cache;
        dns = dns;
      };
      checks.${system} = {
        lancache = pkgs.callPackage ./test.nix { inherit cache dns; };
      };
    };
}
