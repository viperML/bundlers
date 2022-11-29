# viperML/bundlers

Experimental bundlers to use with the nix API:

```console
export SOURCE="nixpkgs"
nix bundle --bundler github:viperML/bundlers#pacman --inputs-from $SOURCE $SOURCE#hello
```

## What is this?

A cleaned up version of [github.com/juliosueiras-nix/nix-utils](https://github.com/juliosueiras-nix/nix-utils).

It uses [fpm](https://github.com/jordansissel/fpm) to bundle nix packages.

## Provided bundlers

You can select the specific bundler with:

`nix bundle --bundler github:viperML/bundlers#bundlers.<system>.<fpm-target>-<type> ...`

or show every bundler available with:

`nix eval github:viperML/bundlers#bundlers.x86_64-linux`

The updated matrix can be found by reading the source in `flake.nix`

## Testing

To test a bundler for a specific package manager, you can do:

```
export SOURCE="nixpkgs"
nix bundle github:viperML/bundlers#pacman -o result --inputs-from $SOURCE $SOURCE#hello
docker run -it -v $(readlink -f result):/mnt:ro archlinux:latest
# pacman -U /mnt/*.pkg.tar.zst
```
