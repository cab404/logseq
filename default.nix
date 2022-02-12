{ pkgs, cacert, yarn2nix-moretea, mkYarnPackage, mkYarnModules, electron_15, clojure, curl, nodejs, openjdk11, makeWrapper, git }:
let
  version = "0.5.9";

  fullCache = let
    locks = [ ./yarn.lock ./static/yarn.lock ];
    lockToCache = f: (pkgs.callPackage (yarn2nix-moretea.mkYarnNix { yarnLock =  f; }) {}).offline_cache;
  in pkgs.symlinkJoin { name = "offline-deps"; paths = map lockToCache locks;};

  clojureDeps = pkgs.runCommand "deps"
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

    pushd build
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
  staticDeps = mkYarnPackage {
    inherit version;
    pname = "logseq-static";
    src = ./static;
    offlineCache = fullCache;
    buildPhase = ":";
    distPhase = ":";
    yarnPreBuild = ''
        echo preBuild!
        export ELECTRON_SKIP_BINARY_DOWNLOAD=1
        export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
        export PATH=$PATH:${pkgs.lib.makeBinPath [ pkgs.nodePackages.node-gyp-build ] }
        export DUGITE_CACHE_DIR=$(pwd)/test
    '';
    extraBuildInputs = [ pkgs.nodePackages.node-gyp-build ];
    packageJSON = ./resources/package.json;
    yarnLock = ./static/yarn.lock;
    yarnFlags = [ "--pure-lockfile" "--offline" ];
  };
  # classp  = clojureDeps.makeClasspaths {};
package = mkYarnPackage rec {
  pname = "logseq";
  src = ./.;
  offlineCache = fullCache;

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
    mv node_modules node_modules_min
    ln -s ../../node_modules -t .
    clojure -Scp $(cat ${clojureDeps}/build/classpath) -M:cljs -v release parser-worker app electron

    popd
  '';

  nativeBuildInputs = [ makeWrapper clojure git openjdk11 nodejs ];

  distPhase = ":"; # disable useless $out/tarballs directory

  postInstall = ''
    ls ${staticDeps}
    makeWrapper ${electron_15}/bin/electron $out/bin/logseq \
    --set NODE_ENV production \
    --add-flags $dir/build/main/main.js
  '';
};
in {
  inherit package staticDeps clojureDeps;
}
