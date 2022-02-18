{ pkgs, cacert, yarn2nix-moretea, runCommand, mkYarnPackage, mkYarnModules, electron_15, clojure, curl, nodejs, openjdk11, makeWrapper, git }:
let
  version = "0.5.9";

  dugiteUselessBinaryParams = {
    url = "https://github.com/desktop/dugite-native/releases/download/v2.29.3-2/dugite-native-v2.29.3-3d467be-ubuntu.tar.gz";
    sha256 = "0ckbs4zhv783rkgcshhv5y1ppp16w8n65gw9w9rwszlwvmj3p398";
  };
  dugiteUselessBinary = builtins.fetchurl dugiteUselessBinaryParams;
  dugiteUselessBinaryName = builtins.baseNameOf dugiteUselessBinaryParams.url;

  # Helps with sanity (and not rebuilding .#logseq) while you mangle your .nix files
  filteredSrc = runCommand "logseq-source"
    {
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = "sha256-bWDzGVGeRQ4odBr+8ZWjvxW3c4hD0SX9CiZ98w6wYes=";

    } ''
    cp -r ${./.} $out
    chmod u+w $out
    find $out -name '*.nix' -delete
    find $out -name 'flake.lock' -delete
  '';

  clojureDeps = runCommand "deps"
    {
      nativeBuildInputs = [ clojure git cacert nodejs ];
      outputHashAlgo = null;
      outputHashMode = "recursive";
      outputHash = "sha256-RGgX9J3RZ7gnGvtpfPS9kNueS0HXDE3/9UEILrJZDL8=";
    } ''

    cd $TMPDIR
    mkdir -p build
    mkdir -p home
    export HOME=$PWD/home

    pushd buildsha256-bWDzGVGeRQ4odBr+8ZWjvxW3c4hD0SX9CiZ98w6wYes=
    cp ${./deps.edn} deps.edn
    clojure  -Spath -M:cljs > classpath
    cat classpath
    popd

    # Hack to remove all the actual content in headless repos, but leave the folder structure
    rm -rf $TMPDIR/.gitlibs/_repos/*/*/*/*/*
    find $TMPDIR/.gitlibs/libs -name .git -delete
    find $TMPDIR/.m2 -name  _remote.repositories -delete

    mv $TMPDIR/.{m2,gitlibs} home
    mv home $out
    mv build $out

  '';
  staticDeps =
    let
      extraBuildInputs = with pkgs; [ python3 ];

      nodeSources = runCommand "node-sources" { } ''
        tar --no-same-owner --no-same-permissions -xf "${nodejs.src}"
        mv node-* $out
      '';

    in
    mkYarnPackage {
      inherit version;
      src = ./static;

      pkgConfig = {
        better-sqlite3 = {
          buildInputs = [ pkgs.python3 ];
          dontStrip = true;
          postInstall = ''
            # build native sqlite bindings
            npm run build-release --offline --nodedir="${nodeSources}"
          '';
        };
      };
      dontStrip = true;
      buildPhase = ''

      '';
      distPhase = ":";
      preInstall = ''
        # echo preBuild!
        # echo $PATH
        # export PATH=$PATH:${pkgs.lib.makeBinPath extraBuildInputs }:$(pwd)/node_modules/.bin
        export ELECTRON_SKIP_BINARY_DOWNLOAD=1
        export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

        # export DUGITE_CACHE_DIR=$(pwd)/test
        # mkdir $DUGITE_CACHE_DIR
        # cp ${dugiteUselessBinary} $DUGITE_CACHE_DIR/${dugiteUselessBinaryName}
        cp ${./resources/package.json} node_modules/Logseq/package.json
      '';

      # installPhase = ''

      #   echo mowmwo
      #   mkdir $out
      #   mv node_modules $out
      # '';
      # inherit extraBuildInputs;

      packageJSON = ./resources/package.json;
      yarnLock = ./static/yarn.lock;
    };
  # classp  = clojureDeps.makeClasspaths {};
  logseq = mkYarnPackage rec {
    pname = "logseq";
    version = staticDeps.version;
    src = filteredSrc;

    yarnPreBuild = ''
      export ELECTRON_SKIP_BINARY_DOWNLOAD=1
      export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
    '';
    buildPhase = ''
      export HOME=$TMPDIR/home
      mkdir -p $HOME

      cp -r ${clojureDeps}/.clojure $HOME
      chmod -R a+rw $HOME/.clojure

      cp -r ${clojureDeps}/.{gitlibs,m2} $TMPDIR
      chmod -R a+rw $TMPDIR/.{gitlibs,m2}

      pushd deps/logseq
      cp -r ${clojureDeps}/build/.cpcache .
      chmod -R a+rw .cpcache

      # now for the magic trick
      rm node_modules
      ln -s ../../node_modules -t .
      clojure -Scp $(cat ${clojureDeps}/build/classpath) -M:cljs -v release parser-worker app electron

      # We won't need those though
      rm node_modules

      popd
    '';

    nativeBuildInputs = [ clojure git openjdk11 nodejs ];
    distPhase = ":"; # disable useless $out/tarballs directory
    installPhase = "
      mkdir $out
      cp -r deps/logseq $out
    ";
  };

  package = runCommand "logseq"
    {
      buildInputs = [ makeWrapper ];
    } ''

    mkdir -p $out

    pushd $out
      cp -r ${logseq}/logseq ./package
      chmod u+w -R ./package
      cp -r ${staticDeps}/libexec/Logseq/node_modules ./package/static/node_modules

      makeWrapper ${electron_15}/bin/electron $out/bin/logseq \
      --set NODE_ENV production \
      --add-flags $out/package
    popd

  '';
in
{
  inherit package staticDeps clojureDeps dugiteUselessBinary logseq;
}
