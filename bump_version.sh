#!/bin/bash
set -e  # Exit on error

TEMPLATE_FILE="CHANGELOG_TEMPLATE.md"
CHANGELOG="CHANGELOG.md"
VERSION_FILE="pyproject.toml"
CURRENT_DATE=$(date +%Y-%m-%d)

echo "Checking if pyproject.toml exists..."
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "Error: $VERSION_FILE not found!" >&2
  exit 1
fi

echo "Extracting current version from pyproject.toml..."
CURRENT_VERSION=$(awk -F' = "' '/^version =/ {print $2}' "$VERSION_FILE" | tr -d '"')

# Check if extraction was successful
if [[ -z "$CURRENT_VERSION" ]]; then
  echo "Error: Could not extract version from $VERSION_FILE" >&2
  exit 1
fi

echo "Current version: $CURRENT_VERSION"
# Check if the version section was found
if ! grep -q "## \[$CURRENT_VERSION\]" $CHANGELOG; then
  echo "Error: No section with version $CURRENT_VERSION found in $CHANGELOG"
  exit 1
fi

# Escape dots in version number for awk pattern matching
VERSION_ESCAPED=$(echo "$CURRENT_VERSION" | sed 's/\./\\./g')
# Split changelog into unreleased and released parts
awk -v ver="$VERSION_ESCAPED" '
    BEGIN { p=0 }
    $0 ~ "## \\[" ver "\\] - [0-9]{4}-[0-9]{2}-[0-9]{2}" { p=NR }
    p==0 { print > "CHANGELOG_unreleased.md" }
    p!=0 { print > "CHANGELOG_old.md" }
' CHANGELOG.md

# Removes template to only get user input
awk 'NR > 7' "CHANGELOG_unreleased.md" >temp_changelog.md \
  && mv temp_changelog.md "CHANGELOG_unreleased.md"

# Process the changelog to remove empty sections
awk '
    # Store the current line
    { current = $0 }

    # If we see a section header, store it and skip to next line
    /^### / {
        section = $0
        getline

        # If next line is empty or another section header, skip printing the section
        if ($0 ~ /^$/ || $0 ~ /^### /) {
            next
        }
        # Otherwise print both section and content
        else {
            print section
            print $0
        }
        next
    }

    # Print any non-section-header line that we havent handled above
    !/^### / { print }
' CHANGELOG_unreleased.md >UNRELEASED.tmp && mv UNRELEASED.tmp CHANGELOG_unreleased.md

# Initialize variables to track if we found each type
FOUND_MAJOR=0
FOUND_MINOR=0
FOUND_PATCH=0

# Check for each type of section
if grep -q "### .*major" CHANGELOG_unreleased.md; then
  FOUND_MAJOR=1
  VERSION_TYPE="major"
elif grep -q "### .*minor" CHANGELOG_unreleased.md; then
  FOUND_MINOR=1
  VERSION_TYPE="minor"
elif grep -q "### .*patch" CHANGELOG_unreleased.md; then
  FOUND_PATCH=1
  VERSION_TYPE="patch"
else
  echo "Error: No version-affecting changes found in CHANGELOG"
  exit 1
fi

echo "Found changes of type: $VERSION_TYPE"
# Extract major, minor, and patch versions
IFS='.' read -r MAJOR MINOR PATCH <<<"$CURRENT_VERSION"

# Bump the correct version
if [[ $FOUND_MAJOR -eq 1 ]]; then
  MAJOR=$((MAJOR + 1))
  MINOR=0
  PATCH=0
elif [[ $FOUND_MINOR -eq 1 ]]; then
  MAJOR=$((MAJOR))
  MINOR=$((MINOR + 1))
  PATCH=0
elif [[ $FOUND_PATCH -eq 1 ]]; then
  MAJOR=$((MAJOR))
  MINOR=$((MINOR))
  PATCH=$((PATCH + 1))
fi

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
echo "$NEW_VERSION"

CURRENT_DATE=$(date +%Y-%m-%d)
echo "Updating [Unreleased] to [$NEW_VERSION] - $CURRENT_DATE"
awk -v date="$CURRENT_DATE" \
  -v new_version="$NEW_VERSION" '
    {
      if ($0 ~ /## \[Unreleased\]/) {
        print "## [" new_version "] - " date
      }
      else {
        print
      }
    }' CHANGELOG_unreleased.md >temp_changelog.md && mv temp_changelog.md CHANGELOG_unreleased.md

echo "Updating version in pyproject.toml"
awk -v new_version="$NEW_VERSION" '
/^version = / {
    print "version = \"" new_version "\""
    next
}
{ print }
' pyproject.toml >temp_pyproject.toml && mv temp_pyproject.toml pyproject.toml

echo 'Copying template to the top of the changelog'
{
  cat $TEMPLATE_FILE
  echo -e "\n\n"
  cat CHANGELOG_unreleased.md
  cat CHANGELOG_old.md
} >temp_changelog.md && mv temp_changelog.md $CHANGELOG

# # Cleanup temp files
rm CHANGELOG_old.md
rm $TEMPLATE_FILE

# Output new version to a file that GitHub Actions can read
echo "Saving new version into env var."
# Output the new version for GitHub Actions to capture
echo "New version: $NEW_VERSION"
# Make sure to set the output value for the next steps to use
echo "new_version=$NEW_VERSION" >> $GITHUB_ENV
echo 'Changelog and version update completed!'
