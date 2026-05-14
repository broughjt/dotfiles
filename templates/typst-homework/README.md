# Typst homework template

A small Typst + Nix template for math/CS homework.

```sh
nix develop
typst compile main.typ homework.pdf
# or
typst watch main.typ homework.pdf
```

The template includes the packages used across prior homework repositories:

- `theorion` for theorem/proposition/lemma/proof blocks
- `curryst` for proof trees/inference rules
- `fletcher` for diagrams
