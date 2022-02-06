{ pkgs, cacert, mkYarnPackage, electron_15, clojure, curl, nodejs, openjdk11, makeWrapper, git }: let
    clojureDeps = pkgs.stdenvNoCC.mkDerivation {
        name = "deps";
        src = ./deps.edn;
        nativeBuildInputs = [ clojure git cacert ];
        outputHashAlgo = null;
        outputHashMode = "recursive";
        outputHash = "sha256-SqhckofXrUTz9eq3o+d7iYVhj9kiCb6aXYR8fbHz0/U=";
        preferLocalBuild = false;
        unpackPhase = ''
            cp $src deps.edn
        '';
        buildPhase = ''
            mkdir build
            mv deps.edn build
            cd build
            export HOME=$PWD
            clojure -P
        '';
        installPhase = ''
            cd ..
            mv build $out
        '';
    };
    # classp  = clojureDeps.makeClasspaths {};
in clojureDeps
# mkYarnPackage rec {
#     pname = "logseq";
#     src = ./.;

#     yarnPreBuild = ''
#         mkdir -p $TMPDIR/home
#         export ELECTRON_SKIP_BINARY_DOWNLOAD=1
#     '';
#     buildPhase = ''
#         export HOME=$TMPDIR/home
#         echo ${clojureDeps}

#         # requires nodejs
#         clojure -M:cljs release worker-parser app electron
#     '';

#     yarnFlags = [ "--offline" "--production" ];

#     nativeBuildInputs = [ makeWrapper clojure git openjdk11 nodejs ];

#     distPhase = ":"; # disable useless $out/tarballs directory

#     postInstall = ''
#         makeWrapper ${electron_15}/bin/electron $out/bin/logseq \
#         --set NODE_ENV production \
#         --add-flags $dir/build/main/main.js
#     '';
# }
