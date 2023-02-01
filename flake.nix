{
  description = "DNS server for LANCache";

  inputs.cache-domains.url = "github:uklans/cache-domains";
  inputs.cache-domains.flake = false;
  inputs.monolithic.url = "github:lancachenet/monolithic";
  inputs.monolithic.flake = false;

  outputs = inputs@{ self, cache-domains, monolithic }:
    let
      system = "x86_64-linux";
    in
    {
      nixosModules = {
        dns = import ./dns.nix { inherit cache-domains; };
        cache = import ./cache.nix { inherit monolithic; };
      };
    };
}
