{
  system,
  pkgs,
  target,
  extraFlags ? [],
  extraPkgs ? [],
}: pkg:
pkgs.stdenv.mkDerivation {
  name = "${target}-single-${pkg.name}";
  buildInputs = with pkgs; [fpm] ++ extraPkgs;

  dontUnpack = true;

  buildPhase = ''
    export HOME=$PWD
    mkdir -p ./nix/store/
    mkdir -p ./bin
    for item in "$(cat ${pkgs.referencesByPopularity pkg})"
    do
      cp -r $item ./nix/store/
    done
    cp -r ${pkg}/bin/* ./bin/
    chmod -R a+rwx ./nix
    chmod -R a+rwx ./bin
    fpm \
      -s dir \
      -t ${target} \
      --name ${pkg.pname} \
      --version ${pkg.version} \
      nix bin
    ls -a
  '';

  installPhase = ''
    mkdir -p $out
    find . -maxdepth 1 -type f -not -name "env-vars" -exec cp {} $out \;
  '';
}
