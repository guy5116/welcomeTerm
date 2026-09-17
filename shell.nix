# nix-shell → a shell with everything `welcome` needs (NixOS / any distro with nix)
{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  packages = [
    (pkgs.python3.withPackages (ps: with ps; [ rich pyfiglet ]))
    pkgs.figlet
  ];
}
