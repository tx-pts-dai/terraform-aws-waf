# Agent instructions

## Preparing a new version

- `examples/complete/current` uses the latest **released** module from the registry
  (`tx-pts-dai/waf/aws` and `tx-pts-dai/waf/aws//modules/ip_list_fetcher`).
  `examples/complete/next` uses the local source and shows unreleased features.
- When preparing a new version, bump every module `version` in
  `examples/complete/current/main.tf` to the latest release and remove the inputs that
  release dropped (its CHANGELOG "Breaking changes"). Don't add unreleased features there.
- Run `terraform init -upgrade -backend=false` in `examples/complete/current` before
  validating. The cached `.terraform` keeps the old module version, and `terraform validate`
  fails with "Module version requirements have changed". Then run `pre-commit run --all-files`.
