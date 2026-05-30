# cicd-pipeline-templates

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![Jenkins](https://img.shields.io/badge/Jenkins-D24939?logo=jenkins&logoColor=white)](https://jenkins.io)
[![GitLab CI](https://img.shields.io/badge/GitLab%20CI-FC6D26?logo=gitlab&logoColor=white)](https://docs.gitlab.com/ee/ci/)
[![Semantic Versioning](https://img.shields.io/badge/semver-2.0.0-blue)](https://semver.org)

> Battle-tested CI/CD pipeline templates for Python, Node.js, and Go — GitHub Actions, Jenkins, and GitLab CI

A production-grade collection of CI/CD pipeline templates maintained by **Barry Au Yeung**, senior DevOps engineer. These templates encode years of hard-won lessons from shipping software across startups and enterprise environments. Copy, adapt, and ship.

---

## What's Inside

| Template | Language | Platform | Features |
|----------|----------|----------|----------|
| `github-actions/python.yml` | Python 3.10+ | GitHub Actions | lint, test, coverage, Docker build, PyPI publish |
| `github-actions/nodejs.yml` | Node.js 18+ | GitHub Actions | lint, test, build, npm publish, GitHub Releases |
| `github-actions/golang.yml` | Go 1.21+ | GitHub Actions | vet, staticcheck, test, cross-compile, binary release |
| `jenkins/Jenkinsfile.python` | Python | Jenkins | multibranch, parallel stages, Slack notify |
| `jenkins/Jenkinsfile.nodejs` | Node.js | Jenkins | parallel matrix, Docker build, ECR push |
| `jenkins/Jenkinsfile.golang` | Go | Jenkins | build matrix (linux/darwin/windows), artifact archive |
| `gitlab-ci/python.gitlab-ci.yml` | Python | GitLab CI | merge request pipelines, pages coverage report |
| `gitlab-ci/nodejs.gitlab-ci.yml` | Node.js | GitLab CI | npm audit, test, Docker build, registry push |
| `gitlab-ci/golang.gitlab-ci.yml` | Go | GitLab CI | go vet, golangci-lint, release tagging |
| `scripts/semver-bump.sh` | Bash | Any | semantic version bumping with git tags |
| `scripts/release-notes.sh` | Bash | Any | auto-generate release notes from git log |
| `scripts/docker-publish.sh` | Bash | Any | multi-arch Docker build and push |

---

## Architecture

```
cicd-pipeline-templates/
├── github-actions/          # GitHub Actions workflow templates
│   ├── python.yml           #   Python: test → lint → build → publish
│   ├── nodejs.yml           #   Node.js: test → lint → build → release
│   └── golang.yml           #   Go: vet → test → cross-compile → release
│
├── jenkins/                 # Jenkins pipeline templates (Declarative)
│   ├── Jenkinsfile.python
│   ├── Jenkinsfile.nodejs
│   └── Jenkinsfile.golang
│
├── gitlab-ci/               # GitLab CI/CD templates
│   ├── python.gitlab-ci.yml
│   ├── nodejs.gitlab-ci.yml
│   └── golang.gitlab-ci.yml
│
├── scripts/                 # Shared automation scripts
│   ├── semver-bump.sh       #   Bump patch/minor/major, create git tag
│   ├── release-notes.sh     #   Generate changelog from conventional commits
│   └── docker-publish.sh    #   Build multi-arch image, push to registry
│
├── .github/workflows/
│   └── ci.yml               # This repo's own CI (validates all templates)
│
└── Makefile                 # Local development helpers
```

### Pipeline Stages (all templates follow this model)

```
 Source ──► Lint ──► Test ──► Build ──► Publish ──► Notify
   │                  │         │
   │              Coverage   Artifact
   │              Report     Archive
   │
   └─── PR/MR? ──► Skip Publish stage
```

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/barry-au-yeung/cicd-pipeline-templates.git
cd cicd-pipeline-templates
```

### 2. Copy a template into your project

```bash
# GitHub Actions — Python project
cp github-actions/python.yml /your-project/.github/workflows/ci.yml

# Jenkins — Node.js project
cp jenkins/Jenkinsfile.nodejs /your-project/Jenkinsfile

# GitLab CI — Go project
cp gitlab-ci/golang.gitlab-ci.yml /your-project/.gitlab-ci.yml
```

### 3. Set required secrets

All templates read from environment secrets. Set these in your platform:

**GitHub Actions** (Settings → Secrets and variables → Actions):
```
DOCKERHUB_USERNAME      # or GHCR token for GitHub Container Registry
DOCKERHUB_TOKEN
PYPI_API_TOKEN          # Python only
NPM_TOKEN               # Node.js only
SLACK_WEBHOOK_URL       # optional, for notifications
```

**Jenkins** (Manage Jenkins → Credentials):
```
docker-credentials      # Username/password credential ID
slack-webhook           # Secret text credential ID
aws-ecr-credentials     # For ECR push (nodejs template)
```

**GitLab CI** (Settings → CI/CD → Variables):
```
CI_REGISTRY_USER        # Usually set automatically
CI_REGISTRY_PASSWORD    # Usually set automatically
SLACK_WEBHOOK_URL
```

### 4. Customize the configuration block

Every template has a `# ── CONFIG ──` block at the top. Edit only that section:

```yaml
# ── CONFIG ──────────────────────────────────────────────
env:
  IMAGE_NAME: your-org/your-app
  PYTHON_VERSION: "3.11"
  REGISTRY: ghcr.io
# ────────────────────────────────────────────────────────
```

---

## Usage Examples

### Semantic Version Bump

Use the `semver-bump.sh` script to tag a new release. It reads the latest git tag, increments the requested component, and pushes the new tag.

```bash
# Bump patch version: 1.2.3 → 1.2.4
./scripts/semver-bump.sh patch

# Bump minor version: 1.2.3 → 1.3.0
./scripts/semver-bump.sh minor

# Bump major version: 1.2.3 → 2.0.0
./scripts/semver-bump.sh major

# Dry run — print what would happen without pushing
DRY_RUN=true ./scripts/semver-bump.sh minor
```

### Generate Release Notes

```bash
# Generate notes since last tag
./scripts/release-notes.sh

# Generate notes between two specific tags
./scripts/release-notes.sh v1.2.0 v1.3.0

# Output to file (for GitHub Releases body)
./scripts/release-notes.sh > RELEASE_NOTES.md
```

Example output:

```
## What's Changed

### Features
- feat: add OAuth2 refresh token support (#142)
- feat: export pipeline metrics to Prometheus (#138)

### Bug Fixes
- fix: race condition in worker pool shutdown (#145)
- fix: Docker layer cache busted on every build (#140)

### Chores
- chore: upgrade actions/checkout to v4 (#147)
- chore: bump Go version to 1.21 (#144)
```

### Multi-Arch Docker Build

```bash
# Build and push linux/amd64 + linux/arm64
IMAGE=your-org/your-app TAG=v1.3.0 ./scripts/docker-publish.sh

# Build only (no push), local test
PUSH=false IMAGE=your-org/your-app TAG=dev ./scripts/docker-publish.sh
```

### GitHub Actions — Python Pipeline

The `github-actions/python.yml` template runs the following on every push to `main` and on every pull request:

```yaml
jobs:
  lint:    # ruff + black --check
  test:    # pytest with coverage, uploads to Codecov
  build:   # pip build → wheel + sdist
  publish: # Publishes to PyPI on semver tags (v*.*.*), skipped on PRs
```

To use it:

```bash
cp github-actions/python.yml .github/workflows/ci.yml
# Then set PYPI_API_TOKEN in GitHub Secrets
```

### Jenkinsfile — Node.js with ECR

The Jenkins Node.js pipeline runs a parallel matrix across Node.js 18 and 20, builds a Docker image, and pushes to Amazon ECR on `main`:

```groovy
stage('Matrix Test') {
    matrix {
        axes {
            axis { name 'NODE_VERSION'; values '18', '20' }
        }
        stages {
            stage('Test') { ... }
        }
    }
}
stage('Docker Build & Push') {
    when { branch 'main' }
    steps {
        withAWS(credentials: 'aws-ecr-credentials', region: 'us-east-1') {
            sh './scripts/docker-publish.sh'
        }
    }
}
```

---

## Configuration Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `IMAGE_NAME` | `your-org/your-app` | Docker image name |
| `REGISTRY` | `ghcr.io` | Container registry host |
| `PYTHON_VERSION` | `3.11` | Python version for workflows |
| `NODE_VERSION` | `20` | Node.js version for workflows |
| `GO_VERSION` | `1.21` | Go version for workflows |
| `TEST_COVERAGE_THRESHOLD` | `80` | Minimum coverage %, fails build if below |
| `SLACK_CHANNEL` | `#deployments` | Channel for deploy notifications |
| `PUSH_ON_BRANCHES` | `main` | Branches that trigger Docker push |
| `RELEASE_TAG_PATTERN` | `v[0-9]*` | Git tag pattern that triggers publish |
| `DRY_RUN` | `false` | Set `true` to skip destructive operations |

---

## Conventional Commits

All templates expect [Conventional Commits](https://www.conventionalcommits.org/) for automated release notes:

```
feat: add new feature          → minor bump
fix: resolve bug               → patch bump
feat!: breaking change         → major bump
chore: update dependencies     → no bump (excluded from notes)
docs: update README            → no bump (excluded from notes)
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/add-rust-template`
3. Commit using Conventional Commits: `git commit -m "feat: add Rust GitHub Actions template"`
4. Push and open a pull request

Please ensure:
- Templates are tested against a real project before submitting
- Configuration blocks are clearly delineated with `# ── CONFIG ──` markers
- All secrets are referenced by name (never hardcoded)
- New templates include a README section entry

---

## License

MIT License — Copyright (c) 2026 Barry Au Yeung. See [LICENSE](LICENSE) for full text.

---

*Maintained by Barry Au Yeung. If a template saved you an afternoon, a star is appreciated.*
