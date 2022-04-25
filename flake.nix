{
  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;
    supportedSystems = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    genSystems = lib.genAttrs supportedSystems;
    pkgsFor = nixpkgs.legacyPackages;

    recursiveMerge = attrList:
      with lib; let
        f = attrPath:
          zipAttrsWith (
            n: values:
              if tail values == []
              then head values
              else if all isList values
              then unique (concatLists values)
              else if all isAttrs values
              then f (attrPath ++ [n]) values
              else last values
          );
      in
        f [] attrList;
  in {
    # Nasty mapAttrs to get a bundler for every:
    # - architecuture
    # - fpm target
    # - style (single package, multi package, etc)
    bundlers = genSystems (system: let
      pkgs = pkgsFor.${system};
      targets = {
        pacman = {
          target = "pacman";
          extraPkgs = with pkgs; [libarchive zstd];
        };
        rpm = {
          target = "rpm";
          extraPkgs = with pkgs; [rpm];
        };
        deb.target = "deb";
        apk.target = "apk";
        tar.target = "tar";
        zip.target = "zip";
      };
      types = {
        # aka the "default"
        "" = "single-with-deps";

        "-single-with-deps" = "single-with-deps";
        "-multi" = "multi";
      };

      r = lib.mapAttrs (type-name: type-key:
        lib.mapAttrs' (
          target-name: target-opts:
            lib.nameValuePair "${target-name}${type-name}"
            (import ./fpm.nix {
              inherit system pkgs;
              inherit (target-opts) target extraPkgs;
            })
            .${type-key}
        )
        targets)
      types;
    in
      recursiveMerge (lib.attrValues r));

    devShells = genSystems (system: {
      default = with pkgsFor.${system};
        mkShell {
          packages = [fpm];
        };
    });
  };
}
