# local-models

Adds local-model providers to the Mem0 server image, exactly as the upstream
docs prescribe (`docs/open-source/setup.mdx`, "Supported providers"): add the
package to `server/requirements.txt`, extend `BUNDLED_EMBEDDER_PROVIDERS` in
`server/main.py`, rebuild.

- **`huggingface` embedder** (`sentence-transformers`): runs `BAAI/bge-m3` on the
  CPU in-process, the same model, library versions and Hugging Face snapshot
  Hindsight uses (`HINDSIGHT_API_EMBEDDINGS_PROVIDER=local`). Upstream keeps it
  out of the default image because PyTorch is ~2 GB; the pinned `+cpu` wheel from
  the PyTorch index avoids pulling the CUDA build on top of that.
- **spaCy + `en_core_web_sm`** (`mem0ai[nlp]`): Mem0 lemmatizes memories for its
  BM25 keyword search and extracts entities for its entity boost with spaCy.
  Without it both silently degrade (raw-text keyword match, no entity boost), and
  the upstream image does not include it.

Without the `main.py` line, `POST /configure` rejects `"provider": "huggingface"`
with a 400 even though the package is installed.

Regenerate after editing the clone: `git -C mem0/upstream diff > mem0/patches/local-models/mem0.patch`.
