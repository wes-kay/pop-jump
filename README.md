# pop

Quickly `cd` to registered directories — and optionally open a file-manager
window there.

```console
$ cd ~/src/my-big-project
$ pop -a myProject        # register it

# later, from anywhere:
$ pop myProject           # cd there
$ pop -w myProject        # cd there + open a file-manager window
```

## Commands

| Command              | What it does                                             |
| -------------------- | -------------------------------------------------------- |
| `pop -a [name]`      | Register the current directory (name defaults to its basename) |
| `pop -a name /path`  | Register an arbitrary directory                           |
| `pop -a -f name /path` | Force-overwrite an existing name                        |
| `pop name`           | `cd` to the registered directory                          |
| `pop -w name`        | `cd` + open a file-manager window in that directory       |
| `pop -l`             | List registered directories (flags missing paths)         |
| `pop -r name`        | Remove a registration                                      |
| `pop -h`             | Show help                                                 |

Bare `pop` (no arguments) lists everything.

Names are matched exactly first, then by unique prefix or substring
(`pop myP` → `myProject`). Ambiguous input lists the candidates instead of
guessing.

## Install

Requires: **bash**, **jq**, and a file manager (uses `thunar`, then `nautilus`,
then `xdg-open` for `-w`).

```sh
mkdir -p ~/.local/share/pop
cp pop.bash ~/.local/share/pop/pop.bash
echo '[ -f "$HOME/.local/share/pop/pop.bash" ] && . "$HOME/.local/share/pop/pop.bash"' >> ~/.bashrc
```

Then open a new terminal (or `source ~/.bashrc`) and start registering:

```sh
pop -a work ~/Documents/Project
```

## Storage

Registrations live in `~/.config/pop/pop.json` — plain, human-editable JSON
mapping names to absolute paths:

```json
{
  "myProject": "/home/you/src/my-big-project",
  "work": "/home/you/Documents/Project"
}
```

Point it elsewhere with `POP_CONFIG=/path/to/file.json`.

## Notes

- `pop` is a shell function (not an external binary) because it needs to
  change your current shell's directory.
- Re-registering a name that already points to the same path is a no-op;
  pointing it at a different path requires `-f`.
