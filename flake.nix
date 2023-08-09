{
  description = "A basic flake with a shell";
  inputs.nixpkgs.url = "nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      with pkgs;
      {
        devShells.default = mkShell {
          packages = [
            elixir_1_15
            papeer
            rmapi
          ];
        };
      });
}
