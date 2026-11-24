

<!-- Source: .ruler/AGENTS.md -->

# kubernetes-platform-modules

Opinionated, secure-by-default Terraform modules for Kubernetes clusters on AWS (EKS) and Azure (AKS). Both modules must work unchanged in commercial and government clouds (GovCloud / Azure Government).

## Layout

- `modules/eks-cluster/`: EKS module (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`, `tests/eks_cluster.tftest.hcl`).
- `modules/aks-cluster/`: AKS module, same file layout, tests in `tests/aks_cluster.tftest.hcl`.
- `examples/eks-complete/`, `examples/aks-complete/`: full usage examples consuming the modules via relative `source`.
- `.tflint.hcl`: tflint config (terraform `recommended` preset, aws and azurerm rulesets).
- `.github/workflows/`: `terraform.yml` (CI), `security.yml` (Trivy config scan, HIGH/CRITICAL), `release-please.yml`, `dependabot-auto-merge.yml`.
- `release-please-config.json`, `.release-please-manifest.json`, `CHANGELOG.md`: release automation.
- `.terraform.lock.hcl` files are committed in each module and example directory.

## Commands

CI pins Terraform `~1.10` and tflint `v0.64.0`; the repo requires Terraform >= 1.7. No cloud credentials are needed: all tests run against `mock_provider`.

```bash
# from repo root
terraform fmt -check -recursive

# for each module you touched (CI matrix: eks-cluster, aks-cluster)
cd modules/<module>
terraform init -backend=false
terraform validate
terraform test
cd -

# lint (from repo root)
tflint --init
tflint --recursive
```

If you changed a module's interface, also run `terraform init -backend=false` and `terraform validate` in the matching `examples/eks-complete` or `examples/aks-complete`.

## Conventions

- Secure by default: any new input that weakens a control (logging off, public access on, encryption off) defaults to the secure value and says so in its description.
- Every module change ships with a test: add or update a `run` block in `tests/*.tftest.hcl`, including the negative case for any `validation` block. Tests use `mock_provider` and `command = plan`.
- Bounded provider constraints: floor the version you need and cap the next major (e.g. `>= 5.0, < 7.0`). Keep `required_version = ">= 1.7"`.
- Build AWS ARNs from `aws_partition`; never hard-code `arn:aws:` so the EKS module plans in both `aws` and `aws-us-gov`.
- Examples and tests use a Kubernetes minor version in standard support on both EKS and AKS (currently `"1.35"` throughout).
- When a module interface changes, update that module's `README.md` inputs/outputs and the root `README.md` table.
- Use obvious placeholders in examples and fixtures (e.g. `subnet-aaaa1111`, `platform-prod`).
- PR titles are Conventional Commits (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`); mark breaking changes with `!` (e.g. `feat!:`). PRs are squash-merged and release-please derives versions from the title.
- Pin third-party GitHub Actions to a full commit SHA with a trailing version comment: `uses: org/action@<sha> # v1.2.3`.
- Keep changes focused: one concern per PR.

## Guardrails

- Never run `terraform apply`, `terraform destroy`, or any command against real AWS/Azure accounts or clusters without explicit human approval. Validation is offline only: `init -backend=false`, `validate`, `test`.
- Prefer dry-run/diff output (`terraform plan`, `fmt -check`) and show it before proposing changes that affect consumers.
- Do not hand-edit release-please outputs: `CHANGELOG.md`, `.release-please-manifest.json`, and the `?ref=vX.Y.Z` lines in `README.md` marked `# x-release-please-version`.
- No secrets in code, logs, or output: no tokens, keys, account/subscription/tenant IDs, or internal hostnames, including in examples and test fixtures. Never commit `*.tfvars` or `*.tfstate` (both are gitignored).
- Report security issues privately per `SECURITY.md`, not in public issues or PRs.
- Generated agent files (`AGENTS.md`, `CLAUDE.md`, `.gemini/settings.json` at repo root) are produced by Ruler from `.ruler/`. Edit `.ruler/AGENTS.md`, then run `npx @intellectronica/ruler@0.3.46 apply`. Never hand-edit the generated files.

## Definition of done

- `terraform fmt -check -recursive` passes.
- `terraform init -backend=false`, `terraform validate`, and `terraform test` pass in every touched module.
- `tflint --init && tflint --recursive` passes.
- Matching example validates if a module interface changed.
- New or changed behaviour is covered by a `tests/*.tftest.hcl` run (positive and negative cases).
- Module and root READMEs reflect any input/output changes.
- No secrets or real identifiers in the diff; PR title is a Conventional Commit.
