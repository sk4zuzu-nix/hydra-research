{
  outputs = { self, nixpkgs, ... }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in {
      defaultPackage.x86_64-linux = self.packages.x86_64-linux.hydra-research;

      packages.x86_64-linux.hydra-research =
        let
          script = (pkgs.writeScriptBin "hydra-research" (builtins.readFile ./hydra-research.sh)).overrideAttrs(old: {
            buildCommand = "${old.buildCommand}\n patchShebangs $out";
          });
        in pkgs.symlinkJoin {
          name        = "hydra-research";
          paths       = with pkgs; [ cowsay ddate ] ++ [ script ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild   = "wrapProgram $out/bin/hydra-research --prefix PATH : $out/bin";
        };

      checks.x86_64-linux.hydra-research = pkgs.runCommand
        "hydra-research-test"
        { buildInputs = [ self.packages.x86_64-linux.hydra-research ]; }
        ''
          hydra-research
          touch $out
        '';

      #hydraJobs = {
      #  inherit (self)
      #    packages;
      #};
    };
}
