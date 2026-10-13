# dotfiles

This repo is a fork of `mathiasbynens/dotfiles`. My copy is `joeyzia/dotfiles`.

- **Never open a PR, issue or comment on `mathiasbynens/dotfiles`.** `gh`
  defaults to that upstream parent, so every `gh` write command passes
  `--repo joeyzia/dotfiles` (and `gh pr create` also passes
  `--head <branch> --base main`).
- `.claude/` mirrors `~/.claude`. When a file there changes, copy it to the
  live location too, and the other way round.
