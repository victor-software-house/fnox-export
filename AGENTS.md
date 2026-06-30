# fnox-export

Mise environment plugin for selective, batched fnox profile export.

## Release rules

- Patch bump by default for every change.
- Never ship a minor or major bump unless the operator explicitly approves that bump in the current task.
- Tags must be lightweight tags. Do not create annotated tags; mise plugin fetch can fail on annotated tag objects.
- Consumer examples should use the published plugin URL without a fixed `#v...` ref unless the operator explicitly asks for a pin.

## Source of truth

- This repository is canonical. Do not treat the dotfiles/chezmoi checkout as the implementation source.
- Keep local/private secret names and workspace-specific examples out of this repository. Put those in private dotfiles skills or local docs instead.

## Verification

Run before release:

```sh
bash test/run.sh
```
