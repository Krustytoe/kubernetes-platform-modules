# Contributing

Thanks for taking a look. Issues and PRs are welcome. For anything bigger than a small fix, open an issue first so we can agree on the approach before you write code.

## Workflow

1. Branch from `main` (fork first if you don't have write access).
2. Make the change and run the local checks below. They're the same ones CI runs.
3. Open a PR using the template. **The PR title must be a [Conventional Commit](https://www.conventionalcommits.org/)** (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`, `feat!:` for breaking changes). PRs are squash-merged, so the title becomes the commit, and [release-please](https://github.com/googleapis/release-please) uses it to pick the next version and write the changelog.
4. CI must be green and the PR reviewed before merge.

## Local checks

Requires Terraform >= 1.7 (for `mock_provider`) and [tflint](https://github.com/terraform-linters/tflint) (CI pins v0.64.0). No cloud credentials needed. Every test runs against a mocked provider.

```bash
terraform fmt -check -recursive

# for each module you touched
cd modules/<module>
terraform init -backend=false
terraform validate
terraform test
cd -

tflint --init
tflint --recursive
```

If you changed a module's interface, also validate the matching example (`examples/eks-complete` or `examples/aks-complete`).

## Module conventions

- **Secure by default.** A new input that weakens a control (logging off, public access on, encryption off) must default to the secure value and say so in its description.
- **Every module change ships with a test.** Add or update a `tests/*.tftest.hcl` run that asserts the behaviour, including the negative case for any `validation` block.
- **Bounded provider constraints.** Floor the version you actually need and cap the next major (e.g. `>= 5.0, < 7.0`) so a provider major can't break consumers silently.
- Update the module's README inputs/outputs and the root README table when the interface changes. Breaking interface changes need `!` in the PR title.
- **Supported Kubernetes versions only.** Examples and tests should use a minor version that's in *standard* support on both EKS and AKS. Check the [EKS](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) and [AKS](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions) calendars.

## Ground rules

- **No secrets in the repo, ever.** That includes tokens, keys, account/subscription/tenant IDs, and internal hostnames in examples or test fixtures. Use obvious placeholders.
- **Pin third-party GitHub Actions to a full commit SHA** with the version as a trailing comment (`uses: org/action@<sha> # v1.2.3`) so Dependabot can bump them.
- Keep changes focused: one concern per PR makes review and rollback easy.

## Security issues

Don't open a public issue. See [SECURITY.md](SECURITY.md).
