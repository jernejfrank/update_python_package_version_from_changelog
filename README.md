# 🛠️ Update pyproject.toml automatically from CHANGELOG

This GitHub Action automates version bumping in a **Python project** based on the `CHANGELOG.md`.
It updates both `pyproject.toml` and `CHANGELOG.md`, ensuring a structured release process.

## 🚀 Features
- 📜 **Extracts the next version** from `CHANGELOG.md`.
- 🔼 **Updates `pyproject.toml`** with the new version.
- 📄 Uses a customizable `CHANGELOG_TEMPLATE.md` for consistency.

---

## 📦 **Usage**
This is particularly useful for automated version control on the main branch within [giflow](https://nvie.com/posts/a-successful-git-branching-model/). Add the following workflow to your `.github/workflows/bump_version.yml`:

```yaml
name: Bump Version and Update Changelog
on:
  push:
    branches:
      - main
permissions:
  contents: write

jobs:
  bump-version:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
            ref: ${{ github.head_ref }}
            fetch-depth: 0

      - name: Update Changelog and Python Package
        uses: jernejfrank/update_python_package_version_from_changelog@main

      - name: Show new version
        run: |
            echo "${{ env.new_version }}"

      - name: Tag and Commit
        env:
            tag: "v${{ env.new_version }}"
        run: |
              git config --local user.email "github-actions[bot]@users.noreply.github.com"
              git config --local user.name "github-actions[bot]"
              git commit -a -m "Bump version to $tag"
              git tag "$tag"
              git push --atomic origin main "$tag"

      - name: Create release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          tag: "v${{ env.new_version }}"
        run: |
          gh release create "$tag" \
              --repo="$GITHUB_REPOSITORY" \
              --title="${GITHUB_REPOSITORY#*/} ${tag#v}" \
              --notes-file CHANGELOG_unreleased.md
```

This will then automatically parse the CHANGELOG and create a new release with the new
tagged version on the main branch. You may want to have a separate action check in the
PR that the CHANGELOG has been filled out.

## ⚙️ Inputs


| Name | Description | Required	| Default |
| :--- | :---------- | :------- | :------ |
| changelog_template_url | URL to CHANGELOG_TEMPLATE.md | ❌ No | Default from action repo |

## 📌 Outputs

`new_version`: The bumped version number stored in `${{ env.new_version }}` for easy access by other actions.

## 📜 CHANGELOG Template

The action uses a template to structure your CHANGELOG.md.
You can customize it in your repository or use the default. The script searches for the keywords:
`major`.`minor`.`patch` to extract the correct version bump according to [semantic versioning](https://semver.org).

```
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed (major)

### Changed - breaking (major)

### Added (minor)

### Changed - backward compatible (minor)

### Deprecated (minor)

### Fixed (patch)

### Security (patch)

```

## 📄 License

MIT License © 2024 Jernej Frank
