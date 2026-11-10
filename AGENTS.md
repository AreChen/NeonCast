# NeonCast development

- Work directly on `main` by default, as requested by the owner. Do not introduce feature branches or a PR requirement unless requested later.
- Run `python -m pytest tests -q` and `python tools/package.py` with the project development environment before pushing code. Keep tests and development tools in the source repository.
- Keep the private addon namespace modular. Put new player-facing text in the language packs, with English fallback.
- Root `Bindings.xml` is automatically discovered by the binding loader. Never list it in `NeonCast.toc` or include it from ordinary UI XML.
- Player ZIPs contain only runtime dependencies, explicitly listed assets and `LICENSE`, under one `NeonCast/` directory. Do not package tests, docs, previews, tools, workflows or other repository files.
- For releases, update the TOC version and CHANGELOG, push `main`, then push a matching `v<version>` tag. Release automation tests, packages and publishes versioned ZIP/checksum assets. Never move published tags or replace published version assets.
- Use alpha/beta/rc versions until the corresponding game-client behaviors are validated. Do not claim simulated UI tests establish in-game compatibility.
