# AGENTS

Dieses Repo verwendet Linter:

- Markdown: `markdownlint-cli2` mit `--fix`, Line Length max 80
- YAML: `yamllint` (extends relaxed, line-length max 140)
- Links: `lychee` mit `--accept 429,200`, `--exclude http://localhost.*`,
  `--exclude-path .npm-cache`, `--max-concurrency 4`, `--retry-wait-time 2`,
  `--timeout 20`, `--cache`

- Lasse nach jeder Änderung `pre-commit` laufen und behebe alle Änderungen selbstständig.
