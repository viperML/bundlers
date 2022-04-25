{
  system,
  pkgs,
  target,
  extraFlags ? [],
  extraPkgs ? [],
}: let
  inherit (pkgs) lib;

  install_usr = pkg: ''
    mkdir -p usr/bin
    for binary in ${pkg}/bin/*; do
      ln -sf $binary usr/bin
    done

    mkdir -p usr/share
    cp -Rs ${pkg}/share/ usr/
    find usr -type d -exec chmod 755 {} +
  '';

  buildInputs = with pkgs; [fpm fakeroot] ++ extraPkgs;
  installPhase = ''
    mkdir -p $out
    find . -maxdepth 1 -type f -not -name "env-vars" -exec cp {} $out \;
  '';

  getPname = pkg: pkg.pname or lib.getName pkg.name;
  getVersion = pkg: "${pkg.version or lib.getVersion pkg.name}.$(echo ${pkg} | cut -d'/' -f 4 | cut -c -7)";
in {
  multi = pkg:
  /*
   Produces multiple packages:
   - A package for every dependency (including the package itself)
   - A "meta-package" containing symlinks to the original package to /usr
   */
    pkgs.stdenv.mkDerivation {
      name = "${target}-multi-${pkg.name}";
      dontUnpack = true;
      inherit buildInputs installPhase;
      buildPhase = ''
        export HOME=$PWD
        mkdir -p $out

        ln -s ${pkgs.referencesByPopularity pkg} $out/deps
        for dep in $(cat $out/deps); do
          echo ">>> Bundling dep $dep"
          mkdir -p nix/store
          cp -r $dep nix/store
          fakeroot -- fpm \
            -s dir \
            -t ${target} \
            --name "nix-bundle-$(echo $dep | cut -d'/' -f4)" \
            --version none \
            ${lib.concatStringsSep " " extraFlags} \
            nix
          rm -rf nix
        done

        for dep in $(cat $out/deps); do
          echo "nix-bundle-$(echo $dep | cut -d'/' -f4)" >> $out/deps-pkgs
        done

        ${install_usr pkg}

        fakeroot -- fpm \
          -s dir \
          -t ${target} \
          --name "${getPname pkg}" \
          --version ${getVersion pkg} \
          $(sed 's/^/--depends '/g $out/deps-pkgs) \
          usr
      '';
    };

  single-full = pkg:
  /*
   Produces a single package with:
   - All the runtime dependencies of the original package (and itself) in the store
   - Links bin and share into usr for the input package
   */
    pkgs.stdenv.mkDerivation {
      name = "${target}-single-with-deps-${pkg.name}";
      inherit buildInputs installPhase;
      dontUnpack = true;
      buildPhase = ''
        export HOME=$PWD

        mkdir -p nix/store
        for item in "$(cat ${pkgs.referencesByPopularity pkg})"; do
          cp -r $item nix/store/
        done

        ${install_usr pkg}

        fakeroot -- fpm \
          -s dir \
          -t ${target} \
          --name ${getPname pkg} \
          --version ${getVersion pkg} \
          ${lib.concatStringsSep " " extraFlags} \
          nix usr
      '';
    };
}
