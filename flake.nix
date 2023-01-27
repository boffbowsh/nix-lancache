{
  description = "DNS server for LANCache";

  inputs.cache-domains.url = "github:uklans/cache-domains";
  inputs.cache-domains.flake = false;

  outputs = inputs@{ self, cache-domains }:
    let
      system = "x86_64-linux";
    in
    {
      nixosModules = {
        dns = import ./dns.nix { inherit cache-domains; };
      };
    };
}
