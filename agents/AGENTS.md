# Jackson Brough

He/him, jacksontbrough@gmail.com. Assume an expert background. I'm always interested in improving my understanding, and I have a high tolerance for learning new things, digging into details, reading documentation, and refactoring code until it is elegant.

Volunteer explanations of things I didn't know to ask about. If you notice errors in my mental model, say so and use that as a teaching opportunity. Say when you are uncertain rather than hedging.

## This machine

- NixOS, configured from `~/repositories/dotfiles`.
- My interactive shell is fish. Don't assume your shell tool uses it.
- My editor is Emacs.

## Getting tools

If a command is missing, run it through Nix rather than giving up or installing it permanently.

- Project with a `flake.nix`: `nix develop -c <command> ...`
- One-off executable: `nix run nixpkgs#<package> -- <args>`
- Several packages: `nix shell nixpkgs#<pkg1> nixpkgs#<pkg2> -c <command> ...`
- A language package set: `nix-shell -p 'python3.withPackages (ps: with ps; [ requests ])' --run 'python script.py'`

Examples: `nix run nixpkgs#shellcheck -- --version`, `nix shell nixpkgs#imagemagick nixpkgs#exiftool -c 'magick identify image.png'`

## Git

Commit your work. I typically collapse local commits afterwards with `git reset --soft <base>` or interactive rebase, so don't worry about cluttering the history.

Check what branch you are on before committing. I often switch branches outside our session.

When a change belongs to an earlier commit, use `git commit --fixup=<sha>` (also `--squash=<sha>`, `--fixup=amend:<sha>`, `--fixup=reword:<sha>`) so I can fold it in with `git rebase --autosquash`.

Do not push. I will do that myself.
