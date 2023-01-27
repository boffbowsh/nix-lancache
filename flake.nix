{
  description = "DNS server for LANCache";

  # 22.11 doesn't support withSlice for nginx
  inputs.nixpkgs.url = "github:NixOS/nixpkgs?ref=3db3666500f66a54ff904c6a8d34ea7ca90f1047";
  inputs.cache-domains.url = "github:uklans/cache-domains";
  inputs.cache-domains.flake = false;
  inputs.monolithic.url = "github:lancachenet/monolithic";
  inputs.monolithic.flake = false;

  outputs = inputs@{ self, cache-domains, monolithic, nixpkgs }:
    let
      system = "x86_64-linux";
    in
    {
      nixosModules = {
        dns = import ./dns.nix { inherit cache-domains; };
        cache = import ./cache.nix { inherit monolithic nixpkgs; };
      };
    };
}
