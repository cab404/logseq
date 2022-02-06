{ pkgs, cacert, mkYarnPackage, electron_15, clojure, curl, nodejs, openjdk11, makeWrapper, git }:
let
  clojureDeps = pkgs.runCommand "deps"
    {
      nativeBuildInputs = [ clojure git cacert ];
      outputHashAlgo = null;
      outputHashMode = "recursive";
      outputHash = "sha256-gj/2b+Fk9GLz0qfeIG5YWhN4GUnWeL3jlq1y5ZA5lcU=";
    } ''
    cd $TMPDIR
    mkdir -p build
    mkdir -p home
    export HOME=$PWD/home

    pushd build
    cp ${./deps.edn} deps.edn
    clojure -P
    popd

    rm -rvf .gitlibs/_repos/*/*/*/*/*
    find .gitlibs/libs -name .git -print -delete
    mv {.m2,.gitlibs} build
    find ./build -name  _remote.repositories -print -delete

    mkdir $out;
    mv build home $out;

  '';
  # classp  = clojureDeps.makeClasspaths {};
in
mkYarnPackage rec {
  pname = "logseq";
  src = ./.;

  yarnPreBuild = ''
    mkdir -p $TMPDIR/home
    export ELECTRON_SKIP_BINARY_DOWNLOAD=1
  '';
  buildPhase = ''

        ls -hal
        echo $pwd
        cd $TMPDIR
        tar -xzf ${clojureDeps}

        export HOME=$TMPDIR/home
        mv build/.{gitlibs,m2} $HOME
        ls -halR $HOME/.gitlibs
        mv build/.cpcache $OLDPWD
        mv build/deps.edn $OLDPWD

        # requires nodejs
        ls -hal $TMPDIR
        echo home $HOME
        ls -hal $HOME
        echo oldpwd $OLDPWD
        ls -hal $OLDPWD
        cd $OLDPWD
        echo $PATH

        clojure -M:cljs release worker-parser app electron --offline
    '';

  yarnFlags = [ "--offline" "--production" ];

  nativeBuildInputs = [ makeWrapper clojure git openjdk11 nodejs ];

  distPhase = ":"; # disable useless $out/tarballs directory

  postInstall = ''
    makeWrapper ${electron_15}/bin/electron $out/bin/logseq \
    --set NODE_ENV production \
    --add-flags $dir/build/main/main.js
  '';
}
