let
  exports = {
    pkgs,
    # self.lastModified
    timestamp ? null,
    # self.src
    src ? ./.,
    debug ? false,
    cssFile ? "/pandoc/style.css",
    highlightFile ? ./pandoc/gruvbox-light.theme,
    lang ? "en",
    articleDirs ? [],
    includedDirs ? [],
    standalonePages ? [],
    navbar ? [],
    favicons ? {},
    headerTitle ? "",
    homemanagerModules ? null,
    nixosModules ? null,
  }: let
    templateFile = import ./template.nix {
      pkgs = pkgs;
      headerTitle = headerTitle;
      navbar = navbar;
      favicons = favicons;
    };
    evalHome = pkgs.lib.evalModules {
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
    evalNixos = pkgs.lib.evalModules {
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
  in
    with pkgs.lib; rec {
      dependencies = with pkgs; [
        pandoc
        coreutils
        findutils
        gnused
        rsync
        git
      ];

      script = pkgs.writeShellApplication {
        name = "mk-pandoc";

        runtimeInputs = dependencies;

        text = ''
          # shellcheck disable=SC2269
          in=''${1:-${src}}
          out=''${2:-"$out"}
          debug=''${3:-"${toString debug}"}

          cd "$in"

          ${
            if timestamp != null
            then ''
              timestamp="$(date -d "@${toString timestamp}" -u "+%Y-%m-%d - %H:%M:%S %Z")"
            ''
            else ''timestamp=""''
          }

          article_dirs_full_paths=()
          article_dirs=()
          ${strings.concatStringsSep "\n" (map (x: ''article_dirs_full_paths+=("${x}")'') articleDirs)}
          for path in "''${article_dirs_full_paths[@]}"; do
            article_dirs+=( "$(basename "$(echo "$path" | sed 's/\/$//g' | sed -E 's:/nix/store/[a-z0-9]+-([^/]+):\1:')")" )
          done

          included_dirs_full_paths=()
          included_dirs=()
          ${strings.concatStringsSep "\n" (map (x: ''included_dirs_full_paths+=("${x}")'') includedDirs)}
          for path in "''${included_dirs_full_paths[@]}"; do
            included_dirs+=( "$(echo "$path" | sed 's/\/$//g' | sed -E 's:/nix/store/[a-z0-9]+-([^/]+):\1:')" )
          done

          mkdir -p "$out"
          pandoc_out="$out/$(echo "${./pandoc}" | sed -E 's:/nix/store/[a-z0-9]+-([^/]+):\1:')"
          rsync -tr --size-only --chmod=u+w --no-perms --modify-window=1 --delete "${./pandoc}/" "$pandoc_out"
          for i in "''${!article_dirs[@]}"; do
            mkdir -p "$out/''${article_dirs[i]}"
            rsync -tr --size-only --chmod=u+w --no-perms --modify-window=1 "''${article_dirs_full_paths[i]}/" "$out/''${article_dirs[i]}"
          done
          for i in "''${!included_dirs[@]}"; do
            mkdir -p "$out/''${included_dirs[i]}"
            rsync -tr --size-only --chmod=u+w --no-perms --modify-window=1 "''${included_dirs_full_paths[i]}/" "$out/''${included_dirs[i]}"
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
                output_file="$out"/${
                  if x ? outputFile
                  then x.outputFile
                  else ''"$filename_no_ext".html''
                }

                pandoc ${
                  if x ? title
                  then "--metadata title=\"${x.title}\""
                  else ""
                } \
                  --standalone \
                  --template "${templateFile}" \
                  --css "${cssFile}" \
                  --highlight-style "${highlightFile}" \
                  --metadata timestamp="$timestamp" \
                  --metadata debug="$debug" \
                  --lua-filter ${./pandoc/lua/anchor-links.lua} \
                  -V lang=en \
                  -V --mathjax \
                  -f markdown+smart \
                  -o "$output_file" \
                  ${x.inputFile}
              '')
              standalonePages)
          }

          cd "$out"
          for dir in "''${article_dirs[@]}"; do
            find "$dir" -type f -name "*.md" | while IFS= read -r file; do
              buildarticle "$file"
            done
          done

          buildoptions() {
            file_path="$1"
            title="$2"
            filename=$(basename -- "$file_path")
            dir_path=$(dirname "$file_path")
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
              -o "$out"/"$dir_path"/"$filename_no_ext".html \
              "$file_path"
          }

          # Generate nixos md docs
          ${
            if nixosModules != null
            then ''
              mkdir -p "$out/nixos-options"
              cat ${optionsDocNixos.optionsCommonMark} > nixos-options/index.md
              buildoptions nixos-options/index.md "Nixos Modules - Options Documentation"
            ''
            else ""
          }

          # Generate home-manager md docs
          ${
            if homemanagerModules != null
            then ''
              mkdir -p "$out/home-manager-options"
              cat ${optionsDocHome.optionsCommonMark} > home-manager-options/index.md
              buildoptions home-manager-options/index.md "Home Manager Modules - Options Documentation"
            ''
            else ""
          }
        '';
      };

      loop = pkgs.writeShellApplication {
        name = "mk-pandoc-loop";
        runtimeInputs = [pkgs.fswatch script pkgs.fd];
        text = ''
          set +e
          in="''${1:-$PWD}"
          out="$(mktemp -d)/out"

          python -m http.server --bind 127.0.0.1 --directory "$out" > /dev/null 2>&1 &
          SERVER_PID=$!
          echo "Started python server with process id $SERVER_PID in dir $out, at localhost:8000"

          # Set a trap to call the cleanup function on EXIT
          cleanup() {
              echo "Terminating the server..."
              kill "$SERVER_PID"
          }
          trap cleanup EXIT

          mk-pandoc "$in" "$out"
          echo "Listening for file changes"
          fd --extension md | xargs fswatch --event Updated | xargs -n 1 sh -c "date '+%Y-%m-%d - %H:%M:%S %Z'; mk-pandoc \"$in\" \"$out\" 1"
        '';
      };

      package = pkgs.stdenv.mkDerivation {
        name = "mk-pandoc-package";
        src = ./.;
        buildInputs = [script];
        phases = ["unpackPhase" "buildPhase"];
        buildPhase = "${pkgs.lib.getExe script}";
      };
    };
in
  exports
