{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  description = "Flake for websites";

  outputs = {nixpkgs, ...}: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {inherit system;};
        });
  in {
    lib = import ./mkPandoc.nix;
    formatter = forAllSystems ({pkgs}: pkgs.alejandra);
  };
}
