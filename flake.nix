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
    /*
     Nasty mapAttrs to get a bundler for every:
     - architecuture
     - fpm target
     - style (single package, multi package, etc)

     The bundler outputs are constructed such as:
     outputs.bundlers.<system>.<target>-<type>
     For example:
     outputs.bundlers.x86_64-linux.pacman-multi
     */

    bundlers = genSystems (system: let
      targets = {
        pacman = {
          target = "pacman";
          extraBuildInputs = [pkgs.libarchive pkgs.zstd];
        };
        rpm = {
          target = "rpm";
          extraBuildInputs = [pkgs.rpm];
        };
        deb.target = "deb";
        apk.target = "apk";
        tar.target = "tar";
        zip.target = "zip";
      };
      types = {
        # aka the "default"
        "" = "single-full";

        "-single-full" = "single-full";
        "-multi" = "multi";
        "-single" = "single";
      };

      pkgs = pkgsFor.${system};
      r = lib.mapAttrs (type-name: type-key:
        lib.mapAttrs' (
          target-name: target-opts:
            lib.nameValuePair "${target-name}${type-name}"
            (import ./fpm.nix ({
                inherit system pkgs;
              }
              // target-opts))
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
