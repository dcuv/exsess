# EXSESS Git Workflow Guide

## Repository Setup

This repository contains the **EXSESS experimentation season control system**—a secure tool for managing scientific experiments with encrypted data storage.

**Git Configuration:**
- **User:** David Conde Lagoa (dclagoa@gmail.com)
- **Initial Branch:** master
- **Initial Commit:** ff14257

## Security & Data Protection

### What's Tracked (In Git)
- ✅ Shell scripts (`scripts/`, `extra/vc.sh`)
- ✅ Documentation (README.md, GIT_WORKFLOW.md)
- ✅ Configuration templates
- ✅ Code changes and improvements

### What's NOT Tracked (Ignored)
- ❌ VeraCrypt container files (`*.hc`, `*.vc`, `subes.*`)
- ❌ Session data directory (`data/`)
- ❌ Active session markers (`.session`)
- ❌ Mounted volume paths (`mnt/`)
- ❌ Editor temp files (`.*.swp`, `*~`)
- ❌ Logs and backups

**See `.gitignore` for complete exclusion list.**

## Development Workflow

### Standard Branch Strategy

```
master          → Production-ready, tested code
  ├── feature/* → New features (e.g., feature/data-export)
  ├── fix/*     → Bug fixes (e.g., fix/timer-precision)
  └── docs/*    → Documentation (e.g., docs/calibration-guide)
```

### Creating a Feature Branch

```bash
git checkout -b feature/your-feature-name
# ... make changes ...
git add <files>
git commit -m "Add your feature description"
git push origin feature/your-feature-name
```

### Naming Conventions

- **Features:** `feature/brief-description` (e.g., `feature/csv-export`, `feature/gum-ui`)
- **Bug Fixes:** `fix/brief-description` (e.g., `fix/timer-hangs`, `fix/csv-formatting`)
- **Documentation:** `docs/brief-description` (e.g., `docs/calibration-guide`)
- **Hotfixes:** `hotfix/brief-description` (e.g., `hotfix/session-crash`)

### Commit Message Format

Follow this structure for clear commit history:

```
[type] Brief description (50 chars max)

Optional detailed explanation. Explain what and why, not how.
Wrap at 72 characters for readability.

Fixes #123 (if related to an issue)
Co-authored-by: Name <email@example.com>
```

**Types:** feat, fix, docs, refactor, test, perf, chore, ci

### Examples

```bash
# Add new feature
git commit -m "feat: Add data export to JSON format

Enable users to export session and exercise data in JSON format
for integration with external analysis tools."

# Bug fix
git commit -m "fix: Correct ISO 8601 timestamp format

ISO 8601 timestamps were missing UTC indicator. Added 'Z' suffix
to all timestamp outputs in ex.sh and ses.sh."

# Documentation
git commit -m "docs: Add calibration guide for sensors"
```

## Workflow Scenarios

### Scenario 1: Adding a New Script Feature

```bash
# Create feature branch
git checkout -b feature/add-data-validation

# Make changes to scripts
# ... edit files ...

# Test your changes
./extra/vc.sh mount
cd ~/mnt/vera
./scripts/ses.sh open
# ... test the feature ...
./scripts/ses.sh close
./extra/vc.sh umount

# Commit changes
git add scripts/ses.sh
git commit -m "feat: Add input validation to session creation

Add checks to ensure session directories have required permissions
before creating session.yml file."

# Push to remote (if applicable)
git push origin feature/add-data-validation
```

### Scenario 2: Fixing a Bug

```bash
git checkout -b fix/timer-precision

# Edit the script
vim scripts/ex.sh

# Test the fix
# ... verify timer works correctly ...

git add scripts/ex.sh
git commit -m "fix: Improve timer precision

Use nanosecond precision for elapsed time calculation to match
sensor data timestamps more accurately."

git push origin fix/timer-precision
```

### Scenario 3: Updating Documentation

```bash
git checkout -b docs/add-troubleshooting

# Edit README or create new doc
vim README.md

git add README.md
git commit -m "docs: Add advanced troubleshooting section

Include solutions for common VeraCrypt mount issues and permission
problems when working with encrypted volumes."

git push origin docs/add-troubleshooting
```

## Remote Repository (Optional)

### Adding a Remote

```bash
# GitHub
git remote add origin https://github.com/username/exsess.git

# GitLab
git remote add origin https://gitlab.com/username/exsess.git

# Bitbucket
git remote add origin https://bitbucket.org/username/exsess.git
```

### Pushing to Remote

```bash
# Initial push
git push -u origin master

# After that
git push origin master
git push origin feature/your-feature
```

## Important Reminders

### Before Committing

1. **Never commit sensitive data:**
   - VeraCrypt container files
   - Session data or experimental records
   - Passphrases or encryption keys
   - Personal information

2. **Check `.gitignore` is working:**
   ```bash
   git status
   # Verify data/, .session, *.hc, etc. are not listed
   ```

3. **Test your changes:**
   ```bash
   ./extra/vc.sh mount
   # Test scripts in mounted volume
   ./extra/vc.sh umount
   ```

### Git Best Practices

- **Commit often:** Small, logical commits are easier to review and revert
- **Write clear messages:** Future you will thank you
- **Pull before push:** Avoid merge conflicts: `git pull origin master`
- **Keep master clean:** Only merge tested, working code
- **Use tags for releases:** `git tag -a v1.0.0 -m "Release version 1.0.0"`

## Viewing History

```bash
# View commit log
git log --oneline -10              # Last 10 commits
git log --graph --all --oneline    # Visual branch history
git log --author="David"           # Commits by author
git log scripts/ex.sh              # Changes to specific file

# View changes
git diff master feature/my-feature  # Compare branches
git show ff14257                    # View specific commit
git diff HEAD~1                     # View uncommitted changes
```

## Reverting Changes

```bash
# Undo uncommitted changes
git checkout -- scripts/ses.sh

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Revert a specific commit
git revert ff14257
```

## Collaboration

### Pull Request / Merge Request Workflow

1. Create feature branch locally
2. Push to remote
3. Create PR/MR with:
   - Clear title describing the change
   - Detailed description of what and why
   - Testing steps
   - Any security considerations
4. Address review feedback
5. Merge when approved

### Code Review Checklist

- [ ] Scripts execute without errors
- [ ] No sensitive data committed
- [ ] Changes follow shell script conventions
- [ ] Documentation updated
- [ ] Tested with VeraCrypt volume mounted
- [ ] Commit message is clear

## Security Considerations

### Protecting Credentials

If you need to handle passphrases or configuration:

1. **Never commit credentials** to git
2. **Use environment variables** in scripts
3. **Document examples** but not actual values
4. **Use `.gitignore`** to protect config files

Example `.gitignore` entry:
```
# Never commit these
.env
.env.local
*.key
secrets/
```

## Useful Aliases

Add to `~/.gitconfig` for faster workflows:

```ini
[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = log --graph --oneline --all
```

Then use:
```bash
git st          # instead of git status
git co -b feature/name  # instead of git checkout -b ...
```

## Questions?

For more information:
- Git Basics: https://git-scm.com/book/en/v2
- GitHub Docs: https://docs.github.com/
- GitLab Docs: https://docs.gitlab.com/
