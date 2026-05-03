{
  description = "rhwp-nextcloud";

  inputs = {
    # keep-sorted start
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rhwp-nix.inputs.nixpkgs.follows = "nixpkgs";
    rhwp-nix.url = "git+file:///Users/seungwon/git/rhwp-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    # keep-sorted end
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [ inputs.treefmt-nix.flakeModule ];

      perSystem =
        { pkgs, system, ... }:
        let
          rhwpPkgs = inputs.rhwp-nix.packages.${system};
          rhwpviewer = pkgs.callPackage ./packages/rhwpviewer {
            inherit (rhwpPkgs) studioBundle rhwpCli;
          };
        in
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          packages = {
            inherit rhwpviewer;
            default = rhwpviewer;
          };

          devShells.default = pkgs.mkShell { packages = [ ]; };

          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              # keep-sorted start
              deadnix.enable = true;
              keep-sorted.enable = true;
              nixfmt.enable = true;
              statix.enable = true;
              # keep-sorted end
            };
          };
        };
    };
}
