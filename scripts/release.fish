#!/usr/bin/env fish

set -l repo_root (git rev-parse --show-toplevel)
set -l sparkle_bin "$repo_root/.sparkle-tools/bin"
set -l build_dir "$repo_root/build"
set -l release_dir "$build_dir/Build/Products/Release"

if not test -x "$sparkle_bin/sign_update"
    echo "Error: Sparkle tools not found at $sparkle_bin"
    echo "Download from: gh release download 2.9.0 -R sparkle-project/Sparkle -p 'Sparkle-*.tar.xz'"
    exit 1
end

# --- Parse arguments ---

set -l rel_version ""
set -l skip_build false
set -l dry_run false

for arg in $argv
    switch $arg
        case --skip-build
            set skip_build true
        case --dry-run
            set dry_run true
        case '--*'
            echo "Unknown option: $arg"
            exit 1
        case '*'
            set rel_version $arg
    end
end

if test -z "$rel_version"
    echo "Usage: scripts/release.fish <version> [--skip-build] [--dry-run]"
    echo ""
    echo "  <version>      Version string (e.g. 1.2.0)"
    echo "  --skip-build   Skip xcodebuild, use existing build artifacts"
    echo "  --dry-run      Build and sign but don't push tag or create release"
    exit 1
end

echo "==> Releasing Elapsed v$rel_version"

# --- 1. Update Info.plist version ---

# Sparkle compares CFBundleVersion (sparkle:version) to decide whether to offer
# an update, so it must increase every release. It cannot reuse the marketing
# version: installs from the old CI workflow carry run-number build versions
# (e.g. "3"), which the standard comparator ranks above "1.0.x". Encode the
# version as a single integer instead: major*10000 + minor*100 + patch.
set -l ver_parts (string split . $rel_version)
if test (count $ver_parts) -ne 3
    echo "Error: version must be MAJOR.MINOR.PATCH (got: $rel_version)"
    exit 1
end
set -l build_number (math "$ver_parts[1] * 10000 + $ver_parts[2] * 100 + $ver_parts[3]")

echo "==> Updating Info.plist version to $rel_version (build $build_number)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $rel_version" "$repo_root/Elapsed/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$repo_root/Elapsed/Info.plist"

# --- 2. Build ---

if not $skip_build
    echo "==> Building Release (universal binary)..."
    xcodebuild -project "$repo_root/Elapsed.xcodeproj" \
        -scheme Elapsed \
        -configuration Release \
        -derivedDataPath "$build_dir" \
        -arch arm64 -arch x86_64 \
        ONLY_ACTIVE_ARCH=NO \
        build 2>&1 | tail -5

    if test $status -ne 0
        echo "Error: Build failed."
        exit 1
    end
end

# --- 3. Re-sign app bundle (ad-hoc, including embedded frameworks) ---

echo "==> Re-signing Elapsed.app with ad-hoc identity..."
codesign --force --deep --sign - "$release_dir/Elapsed.app"

# --- 4. Create ZIP ---

set -l zip_name "Elapsed-$rel_version.zip"
set -l zip_path "$release_dir/$zip_name"

echo "==> Creating $zip_name"
cd "$release_dir"
rm -f "$zip_name"
ditto -c -k --keepParent Elapsed.app "$zip_name"
cd "$repo_root"

# --- 5. Sign with EdDSA & generate appcast ---

echo "==> Signing update with EdDSA..."
set -l sign_output ("$sparkle_bin/sign_update" "$zip_path" 2>&1)
echo $sign_output

echo "==> Generating appcast.xml..."
mkdir -p "$release_dir/appcast_staging"
cp "$zip_path" "$release_dir/appcast_staging/"

if test -f "$repo_root/appcast.xml"
    cp "$repo_root/appcast.xml" "$release_dir/appcast_staging/"
end

# Zips are attached to the GitHub Release, not committed to the repo, so the
# enclosure URL must point at the release asset.
"$sparkle_bin/generate_appcast" \
    --download-url-prefix "https://github.com/ta21cos/elapsed/releases/download/v$rel_version/" \
    "$release_dir/appcast_staging" 2>&1
cp "$release_dir/appcast_staging/appcast.xml" "$repo_root/appcast.xml"
rm -rf "$release_dir/appcast_staging"

echo "==> appcast.xml updated"

if $dry_run
    echo ""
    echo "==> Dry run complete. Artifacts:"
    echo "    ZIP:     $zip_path"
    echo "    Appcast: $repo_root/appcast.xml"
    exit 0
end

# --- 6. Commit appcast, tag, and push ---

echo "==> Committing appcast.xml and tagging v$rel_version"
git add "$repo_root/appcast.xml" "$repo_root/Elapsed/Info.plist"
git commit -m "chore: release v$rel_version"
git tag "v$rel_version"
git push origin main --tags

# --- 7. Create GitHub Release ---

# Published immediately (not draft): the appcast already points at the asset
# URL, which resolves only for published releases.
echo "==> Creating GitHub Release..."
gh release create "v$rel_version" "$zip_path" \
    --title "v$rel_version" \
    --generate-notes

echo ""
echo "==> Done! Release published: v$rel_version"
echo "    https://github.com/ta21cos/elapsed/releases/tag/v$rel_version"
