# Git setup and team workflow

Git records changes locally. GitHub hosts a shared copy. A local commit does not
upload anything. This delivery already contains a Git repository on branch main;
it has no published GitHub remote. The bundle preserves history; the ZIP does not.

## 1. Publish the existing repository from Windows

Open PowerShell and run:

```powershell
cd 'C:\Users\marsi\Documents\Codex\2026-09-18\ece7248-setupm-pdf-pdf-eece4525-cadence\outputs\forge-silicon-eda'
git --version
git status
git log -3 --oneline
git config user.name 'YOUR NAME'
git config user.email 'YOUR GITHUB VERIFIED OR NOREPLY EMAIL'
```

Replace the two identity placeholders. These settings apply only to this repo.
On GitHub, create an **empty private repository** named `forge-silicon-eda` under
your account or the team's organization. Do not initialize README, license or
.gitignore: this repository already has history. Add team members through the
repository access settings. Use private visibility while faculty confirms what
project material can be shared; private GitHub still is not permission to upload PDKs.

Copy its HTTPS clone URL, replace OWNER below, then run:

```powershell
git remote -v
git remote add origin https://github.com/OWNER/forge-silicon-eda.git
git push -u origin main
```

If origin already exists, inspect it before changing anything. If it is wrong,
use `git remote set-url origin URL` with your intended URL. Authenticate using
Git Credential Manager's browser prompt, or `gh auth login` followed by
`gh auth setup-git` if using GitHub CLI. GitHub account passwords are not Git
HTTPS credentials. Never put a token in a remote URL. Refresh GitHub and confirm
README, docs and examples appear. If push reports non-fast-forward, stop and
inspect the remote history; do not force-push over someone else's work.

## 2. Clone on COE VLAB

In the Rocky Linux terminal, enter Bash first if the shell is csh/tcsh:

```bash
bash
cd "$HOME"
git clone https://github.com/OWNER/forge-silicon-eda.git
cd forge-silicon-eda
git status
test -f config/local.sh || cp config/site.example.sh config/local.sh
```

Private repositories require authorized authentication. Use an approved SSH key
or HTTPS credential helper. Do not enable plaintext credential storage on COE.
If authentication is inconvenient, transfer the bundle through your established
VLAB file-transfer method and clone it instead:

```bash
cd "$HOME"
git clone /PATH/TO/forge-silicon-eda.bundle forge-silicon-eda
cd forge-silicon-eda
git remote set-url origin https://github.com/OWNER/forge-silicon-eda.git
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

Inspect the reported logs. If xmsim crashes at time zero, check
`getsebool selinuxuser_execheap` on that host (see README). A compiler banner or
successful elaboration is not a passing simulation. Expect `FORGE_COUNTER_PASS checks=26` and exit zero.
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
