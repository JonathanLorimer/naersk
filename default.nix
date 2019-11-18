{ lib
, runCommand
, symlinkJoin
, stdenv
, writeText
, jq
, rsync
, darwin
, remarshal
, cargo
, rustc
, zstd
}:

with
  { libb = import ./lib.nix { inherit lib writeText runCommand remarshal; }; };

let
  defaultBuildAttrs =
      { inherit
          jq
          runCommand
          lib
          darwin
          writeText
          stdenv
          rsync
          remarshal
          symlinkJoin
          cargo
          rustc
          zstd;
      }; in

let
  builtinz =
      builtins //
      import ./builtins
        { inherit lib writeText remarshal runCommand ; }; in

# Crate building
let
  mkConfig = src: attrs:
    import ./config.nix { inherit lib src attrs libb builtinz; };
  buildPackage = src: attrs:
    let config = (mkConfig src attrs); in
    import ./build.nix src
      (defaultBuildAttrs //
        { pname = config.packageName;
          version = config.packageVersion;
          inherit (config) cratePaths crateDependencies preBuild cargoBuild cargoTestCommands compressTarget;
        } //
        (removeAttrs attrs [ "usePureFromTOML" "cargotomls" "singleStep" ]) //
        { builtDependencies = lib.optional (! config.isSingleStep)
            (
              import ./build.nix
              (libb.dummySrc
                { cargoconfig =
                    if builtinz.pathExists (toString src + "/.cargo/config")
                    then builtins.readFile (src + "/.cargo/config")
                    else null;
                  cargolock = config.cargolock;
                  cargotomls = config.cargotomls;
                  inherit (config) patchedSources;
                }
              )
              (defaultBuildAttrs //
                { pname = "${config.packageName}-deps";
                  version = config.packageVersion;
                  inherit (config) cratePaths crateDependencies cargoBuild compressTarget;
                } //
              (removeAttrs attrs [ "usePureFromTOML" "cargotomls"  "singleStep"]) //
              { preBuild = "";
                cargoTestCommands = map (cmd: "${cmd} || true") config.cargoTestCommands;
                copyTarget = true;
                copyBins = false;
                copyDocsToSeparateOutput = false;
              }
              )
            );
        });
in
{
  inherit buildPackage;
}
