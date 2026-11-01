# Private overlay

This page shows how to add setup that must stay out of this public repo,
such as a cluster account or a server's backup jobs. That setup lives in a
separate private repo, and `scripts/private.sh` plugs it in on the machines
that need it.

## Add the private repo to a machine

1. Put the private repo's URL in `~/.dotfiles/.env`. Git ignores this file.

   ```sh
   cd ~/.dotfiles
   echo 'DOTFILES_PRIVATE_REPO=https://github.com/<you>/<private-repo>.git' > .env
   ```

2. Clone the repo and link its env files.

   ```sh
   sh scripts/private.sh
   ```

   The script prints one line for each file it links, for example
   `private: linked mise.work.local.toml -> private/mise.work.toml`.

3. If the private repo has an env that the OS does not turn on, turn it on.
   `mise.macos.toml` and `mise.linux.toml` load without this step.

   ```sh
   echo 'env = ["work"]' >> ~/.config/mise/miserc.local.toml
   ```

4. Preview and apply.

   ```sh
   mise bootstrap --dry-run
   mise bootstrap
   ```

`mise run sync` runs `scripts/private.sh` on each host before it bootstraps,
so later changes to the private repo reach every machine that has a `.env`.
A machine without `.env` and without `private/` skips the step.

## What the script does

`scripts/private.sh` clones `DOTFILES_PRIVATE_REPO` into `~/.dotfiles/private`,
or pulls it when the clone exists. Then it links each `private/mise.<env>.toml`
to `~/.dotfiles/mise.<env>.local.toml`, and deletes any
`mise.<env>.local.toml` link whose target is gone. mise loads
`mise.<env>.local.toml` beside `mise.toml` whenever `<env>` is active. Git
ignores `.env`, `private/`, and the links.

## Write a private env file

A private env file takes the same tables as a public one. Its paths are
relative to `~/.dotfiles`, so they start with `private/`.

```toml
[dotfile_groups.work]
root = "private/work"

[bootstrap]
dotfile_groups = ["linux", "work"]

[dotfiles]
"~/.profile" = { enabled = false }

[bootstrap.files."~/.config/systemd/user/backup.service"]
source = "./private/work/systemd/backup.service"
```

- `private/work/` holds files at their paths under `~`, like `home/`.
- `dotfile_groups` replaces the list from the OS file, so include the OS
  group too.
- `enabled = false` turns off a public entry only when that entry has its own
  line in `mise.toml`, such as `~/.profile` or `~/.atuin/config.toml`. mise
  ignores it for a file that comes from the `home/` folder link.
- `[bootstrap.packages]`, `[bootstrap.repos]`, `[bootstrap.services]`, and
  `[doctor.checks]` work as they do in the public files.

`tests/test-dotfiles.sh` builds a sample overlay and checks these rules.
