{
  description = "A fuzzy finder for Vim and Neovim, written in Lua; the successor of fall";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          # Vim links whichever Lua it was built with. The tests run on PUC Lua
          # (nixpkgs' default) and on LuaJIT, the two ends users have; the GUI
          # is left out because only the terminal Vim is run.
          vim = pkgs.vim-full.override { guiSupport = false; };
          vim-luajit = pkgs.writeShellScriptBin "vim-luajit" ''
            exec ${
              pkgs.vim-full.override {
                guiSupport = false;
                lua5_5 = pkgs.luajit;
              }
            }/bin/vim "$@"
          '';
        in
        {
          default = pkgs.mkShell {
            # Say why each package beyond these is here.
            packages = [
              pkgs.just
              pkgs.neovim
              vim
              vim-luajit
              pkgs.stylua
              pkgs.selene
              pkgs.lua-language-server
            ];
          };
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
