# Git setup and team workflow

Git records changes locally. GitHub hosts a shared copy. A local commit does not
upload anything. This repository is published on branch main at
<https://github.com/Forge-NU/Silicon-Design-FL26>. Clone it rather than importing
the original bundle or ZIP, so everyone shares one history.

## 1. Identify yourself to Git

Run this once in your checkout. These settings apply only to this repository.

```bash
git --version
git status
git log -3 --oneline
git config user.name 'YOUR NAME'
git config user.email 'YOUR GITHUB VERIFIED OR NOREPLY EMAIL'
```

Ask an organization owner to add you to Forge-NU through the repository access
settings. Keep the repository private while faculty confirms what project
material can be shared; private GitHub still is not permission to upload PDKs.

## 2. Clone on COE VLAB

In the Rocky Linux terminal, enter Bash first if the shell is csh/tcsh:

```bash
bash
cd "$HOME"
git clone https://github.com/Forge-NU/Silicon-Design-FL26.git
cd Silicon-Design-FL26
git status
test -f config/local.sh || cp config/site.example.sh config/local.sh
```

Private repositories require authorized authentication. Use an approved SSH key
or HTTPS credential helper. Do not enable plaintext credential storage on COE.
Authenticate with `gh auth login` followed by `gh auth setup-git`, or a
credential helper's browser prompt. GitHub account passwords are not Git HTTPS
credentials. Never put a token in a remote URL. If authentication is
inconvenient, transfer a bundle through your established VLAB file-transfer
method and clone that instead:

```bash
cd "$HOME"
git clone /PATH/TO/Silicon-Design-FL26.bundle Silicon-Design-FL26
cd Silicon-Design-FL26
git remote set-url origin https://github.com/Forge-NU/Silicon-Design-FL26.git
```

Choose one clone method, not both. Each student uses their own home checkout.
To use a ZIP instead, extract it, enter its directory, run `git init -b main`,
configure your identity, `git add .`, then `git commit -m "Initial import"`.
That creates new history; cloning the existing GitHub repo or bundle is preferable.

## 3. Configure this account and test

Edit `config/local.sh`. On the account previously repaired, uncomment the
FORGE_MOTIF_ROOT and FORGE_HSPICE_ROOT paths pointing to
`$HOME/forge_repair_20260918`. Other members must build their own private copies
using the bootstrap instructions in README. Do not use another student's home.

```bash
bash scripts/smoke.sh
echo "Smoke exit: $?"
bash scripts/run-counter.sh
echo "Counter exit: $?"
```

Inspect the reported logs. The counter currently depends on COE fixing the
recorded Xcelium runtime crash. A compiler banner or successful elaboration is
not a passing simulation. Expect `FORGE_COUNTER_PASS checks=26` and exit zero.
The smoke test covers startup and small jobs, not a full physical design flow.

## 4. Make and share changes

```bash
git switch main
git pull --ff-only
git switch -c counter-validation
# Edit source or documentation, then review changes.
git diff
git status --short
git add examples/counter/counter4.v docs/next-steps.md
git diff --cached
git commit -m "Record counter validation changes"
git push -u origin counter-validation
```

Stage only files you actually changed. Open a pull request on GitHub for a teammate
to review. After merging: switch to main and pull again. Keep generated databases,
waveforms, logs, local paths, PDKs, foundry decks and licensed standard-cell files
out of commits. `.gitignore` is a convenience, not a license review or a way to
remove files already tracked. Share a small redacted results summary instead.

References: [GitHub import guide](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github),
[remote repositories](https://docs.github.com/en/get-started/git-basics/about-remote-repositories).
