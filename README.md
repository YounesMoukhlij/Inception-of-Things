# Git Workflow — Inception-of-Things

> Repository: [`YounesMoukhlij/Inception-of-Things`](https://github.com/YounesMoukhlij/Inception-of-Things)
> Two of us work together on the same GitHub repository.

## Table of contents

- [Main branches](#main-branches)
- [Before starting work](#before-starting-work)
- [While working](#while-working)
- [Merging into `main`](#merging-into-main)
- [After a merge](#after-a-merge)
- [Important rules](#important-rules)
- [Commit convention](#commit-convention)
- [Merge conflicts](#merge-conflicts)
- [Project organization](#project-organization)
- [Goal — feature cycle](#goal--feature-cycle)
- [Command cheat sheet](#command-cheat-sheet)

---

## Main branches

| Branch    | Role                                  |
|-----------|----------------------------------------|
| `main`    | Stable branch of the project           |
| `Younes`  | Younes Moukhlij's working branch       |
| `Yassine` | Yassine Nassibi's working branch       |

> ⚠️ Golden rule: **never work directly on `main`.**

---

## Before starting work

Always pull the latest version of `main`:

```bash
git switch main
git pull origin main
```

Then switch back to your own branch and merge in the latest changes from `main`:

**Younes**

```bash
git switch Younes
git merge main
```

**Yassine**

```bash
git switch Yassine
git merge main
```

---

## While working

Each person works only on their own branch.

**Younes**

```bash
git switch Younes
```

**Yassine**

```bash
git switch Yassine
```

After making a change:

```bash
git add .
git commit -m "description of the change"
git push
```

---

## Merging into `main`

Once a task is finished:

1. Push the branch to GitHub.
2. Open a Pull Request targeting `main`.
3. The other member reviews the changes.
4. Test the feature.
5. Merge into `main` only if everything works.

```text
Younes ──────┐
             ├── Pull Request → Review → main
Yassine ─────┘
```

---

## After a merge

Both members pull the updated `main`:

```bash
git switch main
git pull origin main
```

Then update their own branch:

```bash
git switch Younes
git merge main
```

or:

```bash
git switch Yassine
git merge main
```

---

## Important rules

- [ ] Never code directly on `main`.
- [ ] Always `git pull` before starting a new session.
- [ ] Make small commits with clear messages.
- [ ] Avoid modifying the exact same file at the same time when possible.
- [ ] Test before every Pull Request.
- [ ] The other member must understand the changes before merging.
- [ ] `main` must always stay functional.

---

## Commit convention

To keep a readable history between the two of us, prefix each commit message with the type of change:

| Prefix      | Use                                          |
|-------------|-----------------------------------------------|
| `feat:`     | New feature                                    |
| `fix:`      | Bug fix                                        |
| `docs:`     | Documentation only (README, Workflow...)       |
| `chore:`    | Config, scripts, housekeeping tasks            |
| `refactor:` | Code change with no functional effect          |
| `test:`     | Adding or modifying tests                      |

Example:

```bash
git commit -m "feat: add K3s provisioning in p1/scripts"
```

---

## Merge conflicts

If a `git merge` produces a conflict:

1. Git lists the conflicting files (`git status`).
2. Open each affected file and resolve the `<<<<<<<`, `=======`, `>>>>>>>` markers.
3. Once resolved:

```bash
git add <resolved_file(s)>
git commit
```

4. Let the other member know the conflict was resolved before pushing.

> When in doubt about a conflict, discuss it together before committing rather than overwriting the other person's work.

---

## Project organization

The structure required by the subject must stay:

```text
.
├── p1/
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
├── p2/
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
├── p3/
│   ├── scripts/
│   └── confs/
└── bonus/
```

---

## Goal — feature cycle

Every feature follows this cycle:

```text
Task
 ↓
Development
 ↓
Test
 ↓
Push
 ↓
Pull Request
 ↓
Review
 ↓
Merge
 ↓
main
```

---

## Command cheat sheet

| Command                            | Effect                                               |
|--------------------------------------|--------------------------------------------------------|
| `git switch <branch>`              | Switches to a branch                                   |
| `git pull origin main`             | Fetches the latest changes from `main`                 |
| `git merge main`                   | Merges `main` into the current branch                  |
| `git add .`                        | Stages all modified files for the next commit          |
| `git commit -m "message"`          | Creates a commit with a message                        |
| `git push`                         | Pushes commits to GitHub                                |
| `git status`                       | Shows the current state (changes, conflicts...)         |
| `git log --oneline --graph --all`  | Visualizes history and branches                          |
