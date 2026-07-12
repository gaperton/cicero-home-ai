# models/

HuggingFace models live in this folder (gitignored `*.gguf`).

- `list.txt` — the list of models: one `<local-folder><TAB><hf-repo><TAB><filename>[<TAB><local-rename>]` per line. Each model downloads into its own `models/<local-folder>/`. The optional 4th column renames the file locally — needed when two repos ship a file with the same basename into the same folder (e.g. both Gemma 4 repos' `mtp-gemma-4-31B-it.gguf` MTP drafters).
- `install.sh` — run once: installs the `hf` CLI (`huggingface_hub[cli]`) used to download models.
- `update.sh` — downloads/updates every model in `list.txt` from HuggingFace (skips unchanged files). Called by the top-level `update.sh`.

To add or remove a model, edit `list.txt` — no script changes needed.

Run `hf auth login` once after `install.sh` — without it, downloads work but are rate-limited as an anonymous user.
