# Common utilities shared across all platform builds

{ lib, pkgs }:

{
  # Import the dependency registry
  registry = import ./registry.nix;
  
  # Helper to get build system
  getBuildSystem = entry:
    entry.buildSystem or "autotools";
  
  # Helper to get source type
  getSource = entry: entry.source or "github";
  
  # Helper to fetch source from GitHub or GitLab
  fetchSource = entry:
    let
      getSource = entry: entry.source or "github";
      source = getSource entry;
      sha256 = entry.sha256 or lib.fakeHash;
    in
    if source == "gitlab" then
      (
      if lib.hasAttr "tag" entry then
        # For tags, use fetchgit which handles them better
        pkgs.fetchgit {
          url = "https://gitlab.freedesktop.org/${entry.owner}/${entry.repo}.git";
          rev = "refs/tags/${entry.tag}";
          sha256 = sha256;
        }
      else if lib.hasAttr "branch" entry then
        # For branches, use fetchgit with rev pointing to the branch
        pkgs.fetchgit {
          url = "https://gitlab.freedesktop.org/${entry.owner}/${entry.repo}.git";
          rev = "refs/heads/${entry.branch}";
          sha256 = sha256;
        }
      else if lib.hasAttr "rev" entry then
        pkgs.fetchFromGitLab {
          domain = "gitlab.freedesktop.org";
          owner = entry.owner;
          repo = entry.repo;
          rev = entry.rev;
          sha256 = sha256;
        }
      else
        throw "GitLab source requires 'rev', 'tag', or 'branch'"
      )
    else
      (
        # GitHub
        if lib.hasAttr "tag" entry then
          pkgs.fetchFromGitHub {
            owner = entry.owner;
            repo = entry.repo;
            rev = entry.tag;
            sha256 = sha256;
          }
        else if lib.hasAttr "rev" entry then
          pkgs.fetchFromGitHub {
            owner = entry.owner;
            repo = entry.repo;
            rev = entry.rev;
            sha256 = sha256;
          }
        else
          throw "GitHub source requires either 'rev' or 'tag'"
      );
}
