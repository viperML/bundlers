{
  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;
    supportedSystems = ["x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"];
    genSystems = lib.genAttrs supportedSystems;
    pkgsFor = system: nixpkgs.legacyPackages.${system};
  in {
    bundlers = genSystems (system:
      lib.mapAttrs (name: value:
        import ./fpm.nix ({
          inherit system;
          pkgs = pkgsFor system;
        } // value)) {
        toPACMAN = {
          target = "pacman";
          extraPkgs = with pkgsFor system; [libarchive zstd];
        };
        toDEB.target = "deb";
        toRPM = {
          target = "rpm";
          extraPkgs = with pkgsFor system; [rpm];
        };
        toAPK.target = "apk";
        toTAR.target = "tar";
        toZIP.target = "zip";
      });

    devShells = genSystems (system: {
      default = with pkgsFor system;
        mkShell {
          packages = [fpm];
        };
    });
  };
}
