#!/usr/bin/env bash
# Set up GitHub SSH access for this checkout on COE VLAB, step by step.
#
# Usage: bash scripts/setup-github-ssh.sh
#
# It asks for your GitHub username, name and email, creates an SSH key
# (~/.ssh/id_ed25519_github), shows the public key for you to add to GitHub
# from your own PC, checks that GitHub accepts it, then switches this
# repository's remote from HTTPS to SSH. Safe to rerun: existing keys and
# settings are reused, not replaced.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd -P)
key="$HOME/.ssh/id_ed25519_github"
config="$HOME/.ssh/config"
known="$HOME/.ssh/known_hosts"
# GitHub's published host keys (docs.github.com, "GitHub's SSH key
# fingerprints"); ED25519 is SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU.
github_host_keys='github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg='

bold=$(tput bold 2>/dev/null || true); plain=$(tput sgr0 2>/dev/null || true)
step() { printf '\n%s== %s ==%s\n' "$bold" "$*" "$plain"; }
die() { printf '\nsetup-github-ssh: %s\n' "$*" >&2; exit 1; }
ask() {  # ask VAR "Prompt" [default]
    local reply
    if [[ -n ${3:-} ]]; then read -r -p "$2 [$3]: " reply; reply=${reply:-$3}
    else read -r -p "$2: " reply; fi
    printf -v "$1" '%s' "$reply"
}
[[ -t 0 ]] || die "run this in a terminal; it asks questions."
for tool in git ssh ssh-keygen; do command -v "$tool" >/dev/null || die "$tool is not installed."; done
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || die "$repo is not a Git checkout; clone the repository first."

step "1/5  Your details"
echo "Your GitHub username is shown at the top right of github.com (click your picture)."
while :; do
    ask gh_user "GitHub username"
    [[ $gh_user =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]] && break
    echo "  That is not a valid GitHub username (letters, digits and single hyphens)."
done
ask git_name "Your full name, for commit history" "$(git -C "$repo" config user.name || true)"
echo "Use an email on your GitHub account, or your private no-reply address from"
echo "github.com/settings/emails (looks like 12345678+$gh_user@users.noreply.github.com)."
while :; do
    ask git_email "Email for commits" "$(git -C "$repo" config user.email || true)"
    [[ $git_email == *@*.* && $git_email != *' '* ]] && break
    echo "  Enter an email address."
done
git -C "$repo" config user.name "$git_name"
git -C "$repo" config user.email "$git_email"
echo "Set this repository's commit name and email."

step "2/5  SSH key"
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
if [[ -f $key && -f $key.pub ]]; then
    echo "Reusing your existing key $key."
else
    echo "Creating $key."
    echo "ssh-keygen will ask for a passphrase. A passphrase protects the key if someone"
    echo "copies your files, but you then type it on every pull and push. Press Enter"
    echo "twice for no passphrase."
    ssh-keygen -q -t ed25519 -C "$gh_user-coe-vlab" -f "$key"
fi
chmod 600 "$key"

# Point github.com at this key, unless the user already configured it.
touch "$config"; chmod 600 "$config"
if grep -qiE '^[[:space:]]*Host([[:space:]]+[^#]*)?[[:space:]]github\.com([[:space:]]|$)' "$config"; then
    grep -qF "$key" "$config" || grep -qF '~/.ssh/id_ed25519_github' "$config" ||
        echo "Note: $config already has a 'Host github.com' entry; leaving it as is."
else
    [[ ! -s $config || -z $(tail -c 1 -- "$config") ]] || echo >> "$config"
    printf 'Host github.com\n    User git\n    IdentityFile ~/.ssh/id_ed25519_github\n    IdentitiesOnly yes\n' >> "$config"
    echo "Added a github.com entry to $config."
fi
touch "$known"; chmod 600 "$known"
if ! ssh-keygen -F github.com -f "$known" >/dev/null; then
    printf '%s\n' "$github_host_keys" >> "$known"
    echo "Added GitHub's published host keys to $known."
fi

show_key() {
    step "3/5  Add the key to GitHub from your own PC"
    cat <<EOF
VLAB cannot copy text to your PC, so copy the key below with a screenshot:

  1. Take a screenshot of the key line below (Windows: Win+Shift+S;
     Mac: Cmd+Shift+4).
  2. Turn the screenshot into text: Windows Snipping Tool "Text actions",
     Mac Preview/Photos Live Text (select the text), or Google Lens.
  3. Paste the text into a plain editor and check it:
       - it is ONE line: ssh-ed25519 AAAA... $gh_user-coe-vlab
       - remove any line breaks or extra spaces the screenshot added
       - look closely at look-alikes: 0/O, 1/l/I, 5/S, 8/B, rn/m
  4. On your PC open https://github.com/settings/keys > "New SSH key".
     Title: COE VLAB.  Key type: Authentication Key.  Paste it, "Add SSH key".

${bold}Your public key (safe to share; the private key never leaves VLAB):${plain}

$(cat "$key.pub")

After adding it, GitHub shows a fingerprint for the key. It must match:
  $(ssh-keygen -lf "$key.pub" | awk '{print $2}')
If it differs, the text conversion changed a character; delete that key on
GitHub, fix the text and add it again.
EOF
}
show_key

step "4/5  Check that GitHub accepts the key"
while :; do
    read -r -p "Press Enter once the key is added (r = show key again, q = quit): " choice
    case $choice in
        r|R) show_key; continue;;
        q|Q) echo "Stopped. Rerun this script to continue; your key is kept."; exit 1;;
    esac
    out=$(ssh -T -o StrictHostKeyChecking=yes -o CheckHostIP=no -o ConnectTimeout=15 git@github.com 2>&1 || true)
    if [[ $out =~ Hi\ ([^!]+)! ]]; then
        echo "GitHub accepted the key for user ${BASH_REMATCH[1]}."
        [[ ${BASH_REMATCH[1],,} == "${gh_user,,}" ]] ||
            echo "Note: that is not '$gh_user'; the key is on the account ${BASH_REMATCH[1]}."
        break
    fi
    echo "GitHub did not accept the key yet:"
    sed 's/^/  /' <<< "$out"
    echo "Check that the key was saved on github.com/settings/keys and that its"
    echo "fingerprint matches the one above, then press Enter to try again."
done

step "5/5  Switch this repository to SSH"
url=$(git -C "$repo" remote get-url origin)
if [[ $url =~ ^https://github\.com/([^/]+)/([^/]+)$ ]]; then
    slug="${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    git -C "$repo" remote set-url origin "git@github.com:$slug.git"
    git -C "$repo" config --unset-all remote.origin.pushurl 2>/dev/null || true
    echo "origin: $url -> git@github.com:$slug.git"
elif [[ $url == git@github.com:* ]]; then
    git -C "$repo" config --unset-all remote.origin.pushurl 2>/dev/null || true
    echo "origin already uses SSH: $url"
else
    die "origin is $url, not a github.com URL; change it by hand with git remote set-url."
fi
if git -C "$repo" ls-remote origin HEAD >/dev/null 2>&1; then
    echo "Connected: git pull and git push now use SSH."
else
    cat <<EOF
GitHub accepted the key but this repository is not reachable. Ask an owner of
the GitHub organization to add '$gh_user' to the repository, or, if GitHub
mentions SSO, open github.com/settings/keys, choose "Configure SSO" next to
the key and authorize the organization. Then run: git -C $repo fetch
EOF
    exit 1
fi
