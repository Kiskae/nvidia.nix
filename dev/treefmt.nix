{pkgs, ...}: {
  projectRootFile = ".git/config";
  programs.alejandra.enable = true;
  programs.black.enable = true;
  programs.isort = {
    enable = true;
    profile = "black";
  };
}
