## Getting tools

If a command is missing, run it through Nix rather than giving up or installing it permanently.

- Project with a `flake.nix`: `nix develop -c <command> ...`
- One-off executable: `nix run nixpkgs#<package> -- <args>`
- Several packages: `nix shell nixpkgs#<pkg1> nixpkgs#<pkg2> -c <command> ...`
- A language package set: `nix-shell -p 'python3.withPackages (ps: with ps; [ requests ])' --run 'python script.py'`

Examples: `nix run nixpkgs#shellcheck -- --version`, `nix shell nixpkgs#imagemagick nixpkgs#exiftool -c 'magick identify image.png'`

## Git

Commit your work. I typically collapse local commits afterwards with `git reset --soft <base>` or interactive rebase, so don't worry about cluttering the history.

Write commit messages as a one-line, imperative subject with no body or trailers. Keep explanations of a change in the chat with me.

Check what branch you are on before committing. I often switch branches outside our session.

When a change belongs to an earlier commit, use `git commit --fixup=<sha>` (also `--squash=<sha>`, `--fixup=amend:<sha>`, `--fixup=reword:<sha>`) so I can fold it in with `git rebase --autosquash`.

Do not push. I will do that myself.
