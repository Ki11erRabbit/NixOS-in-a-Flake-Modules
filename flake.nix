{
  description = "A small reimplementation of nixos/lib/modules.nix as a flake for NixOS in a Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.05";
  };

  outputs = { self, nixpkgs, ... }: 
  let 
    lib = nixpkgs.lib;
    # like in nixpkgs/lib/modules.nix
    mkIf = cond: attrs: if cond then attrs else {};
    
    mkMerge = list: lib.foldl' (a: b: lib.recursiveUpdate a b) {} list;
    
    evalModules = { modules, specialArgs ? {}, pkgs }:
        let 
            evaluated = map (m: 
                if builtins.isFunction m
                then m ({ inherit pkgs lib; } // specialArgs)
                else m
            ) modules;

            merged = mkMerge evaluated;
        in merged;

    mkOption = { pkgs, packages ? [], files ? [], hooks ? [] }: let 
        files = map (file: lib.writeTextFile {
                    name = file.name;
                    text = file.text;
                    destination = "${file.location}/${file.name}";
                }) files;
        fileHooks = map (textFile: "\nln -sf ${textFile}/${textFile.destination} ${textFile.destination}") files;
        fileHook = if fileHooks == [] then "" else "\n${concatStringsSep " " fileHooks}";
        optionHooks = map (hook: "\n${hook}") hooks;
        allHooks = fileHook + concatStrings optionHooks ;
    in {
        packages = packages;
        hookscript = pkgs.writeShellScriptBin "hookscript" ''
            #!${pkgs.stdenv.shell}
            set -e
            ${allHooks}
        '';
    };
  in {
    lib = {
        inherit evalModules mkIf mkMerge mkOption;
    };

  };
}
