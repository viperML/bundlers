{
  system,
  pkgs,
  target,
  extraFlags ? [],
  extraPkgs ? [],
}: pkg:
pkgs.stdenv.mkDerivation {
  name = "${target}-single-${pkg.name}";
  buildInputs = with pkgs; [fpm fakeroot] ++ extraPkgs;

  dontUnpack = true;

  buildPhase = ''
    export HOME=$PWD
    mkdir -p nix/store
    for item in "$(cat ${pkgs.referencesByPopularity pkg})"; do
      cp -r $item nix/store/
    done
    chmod -R u+w nix
    install -Dvm755 -t usr/bin ${pkg}/bin/*
    fakeroot -- fpm \
      -s dir \
      -t ${target} \
      --name ${pkg.pname} \
      --version ${pkg.version} \
      ${pkgs.lib.concatStringsSep " " extraFlags} \
      nix usr
  '';

  installPhase = ''
    mkdir -p $out
    find . -maxdepth 1 -type f -not -name "env-vars" -exec cp {} $out \;
  '';
}
