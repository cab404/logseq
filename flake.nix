{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    # clj2nix.url = "github:hlolli/clj2nix";
  };

  outputs = { nixpkgs, self, utils }: utils.lib.eachDefaultSystem (system:
    let
    pkgs = import nixpkgs { inherit system; };
    # clj2nixBin = clj2nix.defaultPackage.${system};
    in
    {
      packages = pkgs.callPackage ./. { };
      nixpkgs = pkgs;
    });

}
