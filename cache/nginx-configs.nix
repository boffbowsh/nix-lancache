{ monolithic, replacements, pkgs }:
with builtins;
with pkgs;
let
  replacementFlags = concatStringsSep " " (lib.attrsets.mapAttrsToList (k: v: "--replace \"${k}\" \"${v}\"") replacements);

  builder = toFile "builder.sh" ''
    source $stdenv/setup
    base=$src/overlay/etc

    find $base/nginx -type f -name "*.conf" | sed 's/^.*\/etc\/nginx/nginx/g' | while read -r file; do
      echo $file
      mkdir -p $out/$(dirname $file)
      substitute $base/$file $out/$file \
        --replace /etc/nginx/ $out/nginx/ \
        ${replacementFlags} 2>/dev/null

    done
  '';
in
stdenv.mkDerivation {
  name = "lancache-nginx-configs";
  builder = "${bash}/bin/bash";
  args = [ builder ];
  src = monolithic;
  system = builtins.currentSystem;
}
