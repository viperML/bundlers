{
  system,
  pkgs,
  target,
  extraFlags ? [],
  extraBuildInputs ? [],
}: let
  inherit (pkgs) lib;

  install_usr = pkg: ''
    if [ -d ${pkg}/bin ] && [ "$(ls -A ${pkg}/bin)" ]; then
      mkdir -p usr/bin
      for binary in ${pkg}/bin/*; do
        ln -sf $binary usr/bin
      done
    fi

    if [ -d ${pkg}/share ] && [ "$(ls -A ${pkg}/share)" ]; then
      mkdir -p usr/share
      cp -Rs ${pkg}/share/ usr/
      find usr -type d -exec chmod 755 {} +
    fi
  '';

  buildInputs = with pkgs; [fpm fakeroot] ++ extraBuildInputs;
  installPhase = ''
    mkdir -p $out
    find . -maxdepth 1 -type f -not -name "env-vars" -exec cp {} $out \;
  '';

  getPname = pkg:
    if lib.hasAttr "pname" pkg
    then pkg.pname
    else lib.getName pkg.name;
  getVersion = pkg: ''${
      if lib.hasAttr "version" pkg
      then pkg.version
      else lib.getVersion pkg.name
    }.$(echo ${pkg} | cut -d'/' -f 4 | cut -c -7)'';
in {
  multi = pkg:
  /*
   Produces multiple packages:
   - Packages "nix-bundle" containing each store item for runtime deps
   - Symlinks in /usr/bin and /usr/share to the input package in the store
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
            --version 0.0 \
            ${lib.concatStringsSep " " extraFlags} \
            nix
          chmod -R u+w nix
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
   - All runtime deps from the store
   - Symlinks in /usr/bin and /usr/share to the input package in the store
   */
    pkgs.stdenv.mkDerivation {
      name = "${target}-single-full-${pkg.name}";
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

  single = pkg:
    pkgs.stdenv.mkDerivation {
      /*
       Produces a single package with:
       - All the contents of the input in the store, nothing more
       */
      name = "${target}-single-${pkg.name}";
      inherit buildInputs installPhase;
      dontUnpack = true;

      buildPhase = ''
        export HOME=$PWD

        mkdir -p nix/store
        cp -r ${pkg} nix/store

        fakeroot -- fpm \
          -s dir \
          -t ${target} \
          --name "nix-bundle-$(echo ${pkg} | cut -d'/' -f4)" \
          --version 0.0 \
          ${lib.concatStringsSep " " extraFlags} \
          nix
      '';
    };
}
