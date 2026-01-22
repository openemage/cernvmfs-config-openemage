#!/bin/bash
set -e

VERSION=${1:-0.1.0}
BUILDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILDER_DIR}/build"
OUTPUT_DIR="${BUILDER_DIR}/output"
PACKAGE_DIR="${BUILD_DIR}/package"
POSTINST="${BUILD_DIR}/postinst"

if [ -x "/opt/homebrew/opt/gnu-tar/libexec/gnubin/tar" ]; then
    PATH="/opt/homebrew/opt/gnu-tar/libexec/gnubin:${PATH}"
elif [ -x "/usr/local/opt/gnu-tar/libexec/gnubin/tar" ]; then
    PATH="/usr/local/opt/gnu-tar/libexec/gnubin:${PATH}"
fi

FPM_BIN="$(command -v fpm || true)"
if command -v ruby >/dev/null 2>&1; then
    GEM_USER_DIR="$(ruby -e 'print Gem.user_dir' 2>/dev/null || true)"
    if [ -n "${GEM_USER_DIR}" ] && [ -x "${GEM_USER_DIR}/bin/fpm" ]; then
        FPM_BIN="${GEM_USER_DIR}/bin/fpm"
    fi
fi

if [ -z "${FPM_BIN}" ]; then
    echo "ERROR: fpm is required for packaging (https://github.com/jordansissel/fpm)"
    echo "Install it (e.g., gem install fpm) and retry."
    exit 1
fi

if "${FPM_BIN}" --version 2>/dev/null | grep -qi "Fortran package manager"; then
    echo "ERROR: Detected the Fortran 'fpm' on PATH, not the Ruby package manager."
    echo "Install Ruby fpm (gem install fpm) or ensure it comes first in PATH."
    exit 1
fi

echo "========================================="
echo "Building cvmfs-config-openemage v${VERSION}"
echo "========================================="
echo ""

# Clean previous builds
rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" "${PACKAGE_DIR}"

# Check if we have any keys
if [ ! -d "${BUILDER_DIR}/src/keys" ] || [ -z "$(find "${BUILDER_DIR}/src/keys" -name '*.pub' 2>/dev/null)" ]; then
    echo "WARNING: No public keys found in src/keys/"
    echo "Add repository public keys before building packages."
    echo ""
fi

# List repositories that will be included
echo "Repositories configured:"
for conf in "${BUILDER_DIR}"/src/etc/cvmfs/config.d/*.openemage.org.conf; do
    if [ -f "$conf" ] && [ "$(basename "$conf")" != "TEMPLATE.openemage.org.conf" ]; then
        repo=$(basename "$conf" .conf)
        echo "  - $repo"

        # Check if key exists
        if [ -d "${BUILDER_DIR}/src/keys/$repo" ]; then
            key_count=$(find "${BUILDER_DIR}/src/keys/$repo" -name '*.pub' 2>/dev/null | wc -l)
            echo "    Keys: $key_count"
        else
            echo "    Keys: MISSING - create src/keys/$repo/ and add keys"
        fi
    fi
done
echo ""

#============================================
# Assemble package payload (like EESSI)
#============================================
echo "[1/4] Assembling package payload..."
mkdir -p "${PACKAGE_DIR}/etc/cvmfs"
cp -r "${BUILDER_DIR}/src/etc/cvmfs"/* "${PACKAGE_DIR}/etc/cvmfs/"
if [ -d "${BUILDER_DIR}/src/keys" ]; then
    mkdir -p "${PACKAGE_DIR}/etc/cvmfs/keys"
    cp -r "${BUILDER_DIR}/src/keys"/* "${PACKAGE_DIR}/etc/cvmfs/keys/" 2>/dev/null || true
fi
echo "  ✓ Assembled: ${PACKAGE_DIR}/etc"
echo ""

#============================================
# Post-install message (kept for parity)
#============================================
cat > "${POSTINST}" << 'POSTINST_EOF'
#!/bin/bash
set -e

echo ""
echo "========================================================================="
echo "OPENEMAGE CernVM-FS configuration installed"
echo "========================================================================="
echo ""
echo "Configured repositories:"
for conf in /etc/cvmfs/config.d/*.openemage.org.conf; do
    if [ -f "$conf" ] && [ "$(basename "$conf")" != "TEMPLATE.openemage.org.conf" ]; then
        repo=$(basename "$conf" .conf)
        echo "  - $repo"
    fi
done
echo ""
echo "Next steps:"
echo "1. Add repositories to /etc/cvmfs/default.local:"
echo "   CVMFS_REPOSITORIES='cryoet-opendata-poc.openemage.org'"
echo ""
echo "2. Run setup:"
echo "   sudo cvmfs_config setup"
echo ""
echo "3. Test mount:"
echo "   sudo cvmfs_config probe"
echo ""
echo "========================================================================="
echo ""
exit 0
POSTINST_EOF
chmod 755 "${POSTINST}"

#============================================
# Build packages via fpm
#============================================
DESCRIPTION="CernVM-FS configuration for OPENEMAGE repositories"
LONG_DESCRIPTION="Configuration package for CernVM-FS to access OPENEMAGE open spatial biology data repositories. Includes configuration for all *.openemage.org repositories with S3 backends and external data support. Each repository has separate S3 buckets for metadata and large files, with direct client access to reduce bandwidth costs."

echo "[2/4] Building tarball..."
"${FPM_BIN}" -s dir -C "${PACKAGE_DIR}" \
    -n cvmfs-config-openemage -v "${VERSION}" -a all -t tar \
    --description "${DESCRIPTION}" \
    --license "Apache-2.0" \
    --url "https://info.openemage.org" \
    -p "${OUTPUT_DIR}/cvmfs-config-openemage-${VERSION}.tar" \
    etc >/dev/null
gzip -f "${OUTPUT_DIR}/cvmfs-config-openemage-${VERSION}.tar"
echo "  ✓ Created: cvmfs-config-openemage-${VERSION}.tar.gz"
echo ""

echo "[3/4] Building DEB package..."
"${FPM_BIN}" -s dir -C "${PACKAGE_DIR}" \
    -n cvmfs-config-openemage -v "${VERSION}" -a all -t deb \
    --description "${LONG_DESCRIPTION}" \
    --license "Apache-2.0" \
    --url "https://info.openemage.org" \
    --depends "cvmfs (>= 2.9.0)" \
    --maintainer "OPENEMAGE Team <info@openemage.org>" \
    --after-install "${POSTINST}" \
    --iteration 1 \
    -p "${OUTPUT_DIR}/cvmfs-config-openemage_${VERSION}-1_all.deb" \
    etc >/dev/null
echo "  ✓ Created: cvmfs-config-openemage_${VERSION}-1_all.deb"
echo ""

echo "[4/4] Building RPM package..."
"${FPM_BIN}" -s dir -C "${PACKAGE_DIR}" \
    -n cvmfs-config-openemage -v "${VERSION}" -a all -t rpm \
    --description "${LONG_DESCRIPTION}" \
    --license "Apache-2.0" \
    --url "https://info.openemage.org" \
    --depends "cvmfs >= 2.9.0" \
    --maintainer "OPENEMAGE Team <info@openemage.org>" \
    --after-install "${POSTINST}" \
    --iteration 1 \
    -p "${OUTPUT_DIR}/cvmfs-config-openemage-${VERSION}-1.noarch.rpm" \
    etc >/dev/null
echo "  ✓ Created: cvmfs-config-openemage-${VERSION}-1.noarch.rpm"
echo ""

#============================================
# Summary
#============================================
echo "========================================="
echo "Build complete!"
echo "========================================="
echo ""
echo "Packages created in: ${OUTPUT_DIR}"
ls -lh "${OUTPUT_DIR}"
echo ""
echo "To add a new repository:"
echo "1. Create src/etc/cvmfs/config.d/<repo>.openemage.org.conf"
echo "2. Create src/keys/<repo>.openemage.org/ and add public key"
echo "3. Run: ./build.sh ${VERSION}"
echo ""
