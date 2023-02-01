# LanCache.net nix flake

Packages [LanCache.net][] as a NixOS module flake.

## Usage

In your NixOS `flake.nix`, include the modules:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
  inputs.lancache.url = "github:boffbowsh/nix-lancache";

  outputs = { self, nixpkgs, lancache }: {

    nixosConfigurations.pc = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules =
        [
          ./configuration.nix
          lancache.nixosModules.dns
          lancache.nixosModules.cache
        ];
    };
  };
}
```

Then set the options in your `configuration.nix`:

```nix
{ ... }:
{
  lancache = {
    dns = {
      enable = true;
      forwarders = [ "1.1.1.1" "8.8.8.8" ];
      cacheIp = "192.168.0.99";
    };
    cache = {
      enable = true;
      resolvers = [ "1.1.1.1" "8.8.8.8" ];
    };
  };
}
```


The cache module maps the [LanCache.net environment variables][envs] to
`camelCase`d Nix options, eg `CACHE_INDEX_SIZE` becomes `cacheIndexSize`. The
options for controlling the `cache-domains` repo are replaced by the
`flake.lock` file.

[LanCache.net]: https://lancache.net/
[envs]: https://lancache.net/docs/containers/monolithic/variables/

## Todo

- [ ] Sniproxy
- [ ] Monitoring
- [ ] Customising cache and log locations
