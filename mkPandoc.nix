let
  lib = {
    pkgs,
    debug ? false,
    cssFile ? "/pandoc/style.css",
    highlightFile ? ./pandoc/gruvbox-light.theme,
    lang ? "en",
    articleDirs ? [],
    standalonePages ? [],
    homemanagerModules ? null,
    nixosModules ? null,
  }: let
    templateFile = "$out/pandoc/template.html";
    evalHome = lib.evalModules {
      specialArgs = {inherit pkgs;};
      modules = [
        {
          # disabled checking that all option definitions have matching declarations
          config._module.check = false;
        }
        homemanagerModules
      ];
    };
    # generate our docs
    optionsDocHome = pkgs.nixosOptionsDoc {
      inherit (evalHome) options;
    };

    # Same for nixos
    evalNixos = lib.evalModules {
      specialArgs = {inherit pkgs;};
      modules = [
        {
          config._module.check = false;
        }
        nixosModules
      ];
    };
    optionsDocNixos = pkgs.nixosOptionsDoc {
      inherit (evalNixos) options;
    };
  in with pkgs.lib; rec {
    dependencies = with pkgs; [
      pandoc
      coreutils
      findutils
      gnused
    ];

    script = pkgs.writeShellApplication {
      name = "mk-pandoc";

      runtimeInputs = dependencies;

      text = ''
        # shellcheck disable=SC2269
        out=''${1:-"$out"}
        debug=''${2:-"${toString debug}"}
        timestamp="$(date -u '+%Y-%m-%d - %H:%M:%S %Z')"

        full_paths=()
        dirs=()
        ${strings.concatStringsSep "\n" (map (x: ''full_paths+=("${x}")'') articleDirs)}

        for path in "''${full_paths[@]}"; do
          dirs+=( "$(echo "$path" | sed -E 's:/nix/store/[a-z0-9]+-([^/]+):\1:')" )
        done

        mkdir -p "$out"
        cp -r ${./pandoc} "$out/$(echo "${./pandoc}" | sed -E 's:/nix/store/[a-z0-9]+-([^/]+):\1:')"
        for i in "''${!dirs[@]}"; do
          cp --no-preserve=mode -r "''${full_paths[i]}" "$out/''${dirs[i]}"
        done

        buildarticle () {
          file_path="$1"
          filename=$(basename -- "$file_path")
          dir_path=$(dirname "$file_path")
          filename_no_ext="''${filename%.*}"

          if [ "$debug" = 1 ] ; then
            {
              echo "$file_path"
              echo "$filename"
              echo "$dir_path"
              echo "$filename_no_ext"
              echo ""
            } >> "$out"/log.log
          fi

          mkdir -p "$out"/"$dir_path"

          pandoc \
            --standalone \
            --template "${templateFile}" \
            --css "${cssFile}" \
            --highlight-style "${highlightFile}" \
            --metadata debug="$debug" \
            --metadata timestamp="$timestamp" \
            --lua-filter ${./pandoc/lua/anchor-links.lua} \
            -V lang="${lang}" \
            -V --mathjax \
            -f markdown+smart \
            -o "$out"/"$dir_path"/"$filename_no_ext".html \
            "$file_path"
          }

          ${
            strings.concatStringsSep "\n\n" (map (x: ''
              filename=$(echo "${x.inputFile}" | sed -E 's:/nix/store/[a-z0-9]+-([^/]+):\1:')
              filename=$(basename -- "$filename")
              filename_no_ext="''${filename%.*}"

              pandoc \
                --standalone \${if x ? title then "--title ${x.title} \\\n" else ""}
                --template "${templateFile}" \
                --css "${cssFile}" \
                --highlight-style "${highlightFile}" \
                --metadata timestamp="$timestamp" \
                --metadata debug="$debug" \
                --lua-filter ${./pandoc/lua/anchor-links.lua} \
                -V lang=en \
                -V --mathjax \
                -f markdown+smart \
                -o "$out"/"$filename_no_ext".html \
                ${x.inputFile}
            '') standalonePages)
          }

          cd "$out"
          for dir in "''${dirs[@]}"; do
            find "$dir" -type f -name "*.md" | while IFS= read -r file; do
              buildarticle "$file"
            done
          done

        buildoptions() {
          filepath="$1"
          title="$2"
          filename=$(basename -- "$filepath")
          filename_no_ext="''${filename%.*}"

          pandoc \
            --standalone \
            --metadata title="$title" \
            --metadata timestamp="$timestamp" \
            --highlight-style "${highlightFile}" \
            --template "${templateFile}" \
            --css "${cssFile}" \
            --lua-filter ${./pandoc/lua/indent-code-blocks.lua} \
            --lua-filter ${./pandoc/lua/anchor-links.lua} \
            --lua-filter ${./pandoc/lua/code-default-to-nix.lua} \
            --lua-filter ${./pandoc/lua/headers-lvl2-to-lvl3.lua} \
            --lua-filter ${./pandoc/lua/remove-declared-by.lua} \
            --lua-filter ${./pandoc/lua/inline-to-fenced-nix.lua} \
            --lua-filter ${./pandoc/lua/remove-module-args.lua} \
            -V lang=en \
            -V --mathjax \
            -f markdown+smart \
            -o "$out"/"$filename_no_ext".html \
            "$filepath"
        }

        # Generate nixos md docs
        ${
          ""
          #if nixosModules != null then ''
          #  cat ${optionsDocNixos.optionsCommonMark} > "$out"/nixos.md
          #  buildoptions "$out"/nixos.md "Nixos Modules - Options Documentation"
          #'' else ""
        }

        # Generate home-manager md docs
        ${
          ""
          #if homemanagerModules != null then ''
          #  cat ${optionsDocHome.optionsCommonMark} > "$out"/home.md
          #  buildoptions "$out"/home.md "Home Manager Modules - Options Documentation"
          #'' else ""
        }
      '';
    };

    loop = pkgs.writeShellApplication {
      name = "mk-pandoc-loop";
      runtimeInputs = [ pkgs.fswatch script pkgs.fd ];
      text = ''
        set +e
        out=$(mktemp -d)

        echo "Starting python server in $out"
        python -m http.server --bind 127.0.0.1 --directory "$out" &
        SERVER_PID=$!

        # Set a trap to call the cleanup function on EXIT
        cleanup() {
            echo "Terminating the server..."
            kill "$SERVER_PID"
        }
        trap cleanup EXIT

        mk-pandoc "$out"
        echo "Listening for file changes"
        fd --extension md | xargs fswatch --event Updated | xargs -n 1 sh -c "date '+%Y-%m-%d - %H:%M:%S %Z'; mk-pandoc $out 1"
      '';
    };

    #package = let
    #  x = pkgs.writeText "my-file" ''
    #    export PATH="$coreutils/bin"
    #    mkdir $out
    #    cp -r ${./pandoc} $out
    #  '';
    #in derivation {
    #  name = "mk-pandoc-package";
    #  system = pkgs.system;
    #  coreutils = pkgs.coreutils;
    #  outputs = [ "out" ];
    #  buildInputs = [ pkgs.coreutils ];
    #  #phases = ["unpackPhase" "buildPhase" "installPhase"];
    #  builder = "${pkgs.lib.getExe pkgs.bash}";
    #  #builder = "${pkgs.lib.getExe script}";
    #  args = [ "${pkgs.lib.getExe script}" ];
    #};

    package = pkgs.stdenv.mkDerivation {
      name = "mk-pandoc-package";
      src = ./.;
      buildInputs = [ script ];
      phases = ["unpackPhase" "buildPhase"];
      buildPhase = "${pkgs.lib.getExe script}";
    };

  };
in lib
