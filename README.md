# viperML/bundlers

Experimental bundlers to use with the nix API:

```console
export SOURCE="nixpkgs"
nix bundle github:viperML/bundlers#pacman --inputs-from $SOURCE $SOURCE#hello
```

## Provided bundlers

You can find the bundler matrix in `flake.nix`, it follows:

`bundlers.<system>.<fpm-target>-<style>`


## Testing

```
export SOURCE="nixpkgs"
nix bundle github:viperML/bundlers#pacman -o result --inputs-from $SOURCE $SOURCE#hello
docker run -it -v (readlink -f result):/mnt:ro archlinux:latest
# pacman -U /mnt/*.pkg.tar.zst
```
