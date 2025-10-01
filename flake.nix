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
        dirHooks = map (dir: "\nmkdir -p ${dir}") (lib.unique (map (file: file.location) files));
        textFiles = map (file: pkgs.writeTextFile {
                    name = file.name;
                    text = file.text;
                    destination = "${file.location}/${file.name}";
                }) files;
        fileHooks = map (textFile: "\nln -sf ${textFile}/${textFile.destination} ${textFile.destination}") textFiles;
        fileHook = if fileHooks == [] then "" else "\n${lib.concatStringSep " " dirHooks}\n${lib.concatStringsSep " " fileHooks}";
        optionHooks = map (hook: "\n${hook}") hooks;
        allHooks = fileHook + lib.concatStrings optionHooks ;
        pkg = packages;
    in {
        packages = pkg;

        hooks = allHooks;
    };
  in {
    lib = {
        inherit evalModules mkIf mkMerge mkOption;
    };

  };
}
