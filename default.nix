{ pkgs, cacert, mkYarnPackage, electron_15, clojure, curl, nodejs, openjdk11, makeWrapper, git }:
let
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
  # classp  = clojureDeps.makeClasspaths {};
in
mkYarnPackage rec {
  pname = "logseq";
  src = ./.;

  yarnPreBuild = ''
    mkdir -p $TMPDIR/home
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

        cp -r $src build
        chmod -R a+rw build
        ln -s ../node_modules -t build
        cd build

        cp -rv ${clojureDeps}/build/.cpcache ./
        chmod -R a+rw .cpcache

        cp ${./deps.edn} ./deps.edn

        clojure -Scp $(cat ${clojureDeps}/build/classpath) -M:cljs release parser-worker app electron
    '';

  nativeBuildInputs = [ makeWrapper pkgs.chromium clojure git openjdk11 nodejs ];

  distPhase = ":"; # disable useless $out/tarballs directory

  postInstall = ''
    makeWrapper ${electron_15}/bin/electron $out/bin/logseq \
    --set NODE_ENV production \
    --add-flags $dir/build/main/main.js
  '';
}
