{ pkgs, lib, config, inputs, ... }:
{
  # https://devenv.sh/packages/
  packages = with pkgs; [
    git
    powershell
  ];

  # https://devenv.sh/languages/
  languages.python = {
    enable = true;
  };

  # See full reference at https://devenv.sh/reference/options/
}
