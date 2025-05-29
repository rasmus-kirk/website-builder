# website-builder

This is a repo for generating static websites using nix using pandoc. Notably,
it's able to automatically generate documentation for passed Home Manager/NixOS
modules. Below, the arguments can be seen for the site builder.

- `pkgs`: Required - The nixpkgs instance.
- `src`: `Path`, Required - Source for the repo, should be set to `./.`.
- `timestamp`: `Integer`, optional - A unix timestamp for the document. Should be set to `self.lastModified` if set.
- `debug`: `Boolean`, optional - Whether to include debug information, defaults to `false`.
- `cssFile`: `Path`, optional - Stylesheet for pandoc to use, defaults `/pandoc/style.css` in this repo.
- `highlightFile`: `Path`, optional - The syntax highlighting file to use, defaults to `/pandoc/gruvbox-light.theme` in this repo.
- `lang`: `String`, optional - Language information for the HTML build, defaults to `en`
- `articleDirs`: `[Path]`, optional - List of directories to compile with pandoc, defaults to `[]`.
- `includedDirs`: `[Path]`, optional - List of directories to include in the build without compilation, defaults to `[]`.
- `standalonePages`: `[Path]`, optional - List of files to compile using pandoc, defaults to `[]`.
- `navbar`: `[{ title = String; location = StringPath }]`, optional - List of navbar elemnts, defaults to `[]`.
- `favicons`: `{ String = Path }`, optional - Defines the favicons, see the example, defaults to `{}`.
- `headerTitle`: `String`, optional - The header title of the site, defaults to `""`.
- `homemanagerModules`: `Path`, optional - Path to the Home Manager modules to generate automatic documentation for.
- `nixosModules`: `Path`, optional - Path to the NixOS modules to generate automatic documentation for.

## Examples

### Nixarr

[link](https://nixarr.com/)

```nix
  packages = forAllSystems ({pkgs}: let
    website = website-builder.lib {
      pkgs = pkgs;
      src = "${self}";
      timestamp = self.lastModified;
      headerTitle = "Nixarr";
      standalonePages = [
        {
          title = "Nixarr - Media Server Nixos Module";
          inputFile = ./README.md;
          outputFile = "index.html";
        }
      ];
      includedDirs = ["docs"];
      articleDirs = ["docs/wiki"];
      navbar = [
        {
          title = "Home";
          location = "/";
        }
        {
          title = "Options";
          location = "/nixos-options";
        }
        {
          title = "Wiki";
          location = "/wiki";
        }
        {
          title = "Github";
          location = "https://github.com/rasmus-kirk/nixarr";
        }
      ];
      favicons = {
        # For all browsers
        "16x16" = "/docs/img/favicons/16x16.png";
        "32x32" = "/docs/img/favicons/32x32.png";
        # For Google and Android
        "48x48" = "/docs/img/favicons/48x48.png";
        "192x192" = "/docs/img/favicons/192x192.png";
        # For iPad
        "167x167" = "/docs/img/favicons/167x167.png";
        # For iPhone
        "180x180" = "/docs/img/favicons/180x180.png";
      };
      nixosModules = ./nixarr;
    };
  in {
    default = website.package;
    debug = website.loop;
  });
```

### My Website

[link](https://rasmuskirk.com/)

```nix
  packages = forAllSystems ({pkgs}: let
    website = website-builder.lib {
      pkgs = pkgs;
      src = ./.;
      headerTitle = "Rasmus Kirk";
      includedDirs = [ "documents" ];
      articleDirs = ["articles" "misc"];
      standalonePages = [{inputFile = ./index.md;}];
      navbar = [
        {
          title = "About";
          location = "/";
        }
        {
          title = "Articles";
          location = "/articles";
        }
        {
          title = "Misc";
          location = "/misc";
        }
        {
          title = "Github";
          location = "https://github.com/rasmus-kirk";
        }
      ];
    };
  in {
    default = website.package;
    debug = website.loop;
  });
```

### My Nix Configuration

[link](https://nix.rasmuskirk.com/)

```nix
  packages = forAllSystems ({pkgs}: let
    website = website-builder.lib {
      pkgs = pkgs;
      src = ./.;
      headerTitle = "Rasmus Kirk";
      includedDirs = [ "documents" ];
      articleDirs = ["articles" "misc"];
      standalonePages = [{inputFile = ./index.md;}];
      navbar = [
        {
          title = "About";
          location = "/";
        }
        {
          title = "Articles";
          location = "/articles";
        }
        {
          title = "Misc";
          location = "/misc";
        }
        {
          title = "Github";
          location = "https://github.com/rasmus-kirk";
        }
      ];
    };
  in {
    default = website.package;
    debug = website.loop;
  });
```
