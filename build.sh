#!/bin/bash
set -e

VERSION=${1:-1.0.0}
BUILDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILDER_DIR}/build"
OUTPUT_DIR="${BUILDER_DIR}/output"

echo "========================================="
echo "Building cvmfs-config-openemage v${VERSION}"
echo "========================================="
echo ""

# Clean previous builds
rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

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
# Build Tarball
#============================================
echo "[1/3] Building tarball..."
cd "${BUILDER_DIR}/src"
tar czf "${OUTPUT_DIR}/cvmfs-config-openemage-${VERSION}.tar.gz" \
    etc/ keys/
echo "  ✓ Created: cvmfs-config-openemage-${VERSION}.tar.gz"
echo ""

#============================================
# Build DEB package
#============================================
echo "[2/3] Building DEB package..."
DEB_BUILD="${BUILD_DIR}/deb"
mkdir -p "${DEB_BUILD}/DEBIAN"
mkdir -p "${DEB_BUILD}/etc/cvmfs"

# Copy files
cp -r "${BUILDER_DIR}/src/etc/cvmfs"/* "${DEB_BUILD}/etc/cvmfs/"
if [ -d "${BUILDER_DIR}/src/keys" ]; then
    mkdir -p "${DEB_BUILD}/etc/cvmfs/keys"
    cp -r "${BUILDER_DIR}/src/keys"/* "${DEB_BUILD}/etc/cvmfs/keys/" 2>/dev/null || true
fi

# Create control file
cat > "${DEB_BUILD}/DEBIAN/control" << EOF
Package: cvmfs-config-openemage
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: all
Depends: cvmfs (>= 2.9.0)
Maintainer: OPENEMAGE Team <info@openemage.org>
Homepage: https://openemage.org
Description: CernVM-FS configuration for OPENEMAGE repositories
 Configuration package for CernVM-FS to access OPENEMAGE open spatial
 biology data repositories. Includes configuration for all *.openemage.org
 repositories with S3 backends and external data support.
 .
 Each repository has separate S3 buckets for metadata and large files,
 with direct client access to reduce bandwidth costs.
EOF

# Create postinst
cat > "${DEB_BUILD}/DEBIAN/postinst" << 'POSTINST_EOF'
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
echo "For documentation: https://openemage.org/docs"
echo "========================================================================="
echo ""

#DEBHELPER#
exit 0
POSTINST_EOF

chmod 755 "${DEB_BUILD}/DEBIAN/postinst"

# Build package
dpkg-deb --build "${DEB_BUILD}" "${OUTPUT_DIR}/cvmfs-config-openemage_${VERSION}_all.deb" >/dev/null
echo "  ✓ Created: cvmfs-config-openemage_${VERSION}_all.deb"
echo ""

#============================================
# Build RPM package
#============================================
echo "[3/3] Building RPM package..."

# Setup rpmbuild structure
RPM_BUILD="${BUILD_DIR}/rpmbuild"
mkdir -p "${RPM_BUILD}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Copy source files
cp -r "${BUILDER_DIR}/src/etc" "${RPM_BUILD}/SOURCES/"
if [ -d "${BUILDER_DIR}/src/keys" ]; then
    cp -r "${BUILDER_DIR}/src/keys" "${RPM_BUILD}/SOURCES/"
fi

# Create spec file
cat > "${RPM_BUILD}/SPECS/cvmfs-config-openemage.spec" << 'SPEC_EOF'
Summary: CernVM-FS configuration for OPENEMAGE repositories
Name: cvmfs-config-openemage
Version: VERSION_PLACEHOLDER
Release: 1
License: Apache-2.0
Group: Applications/System
URL: https://openemage.org
BuildArch: noarch
Requires: cvmfs >= 2.9.0

%description
Configuration package for CernVM-FS to access OPENEMAGE open spatial
biology data repositories. Includes configuration for all *.openemage.org
repositories with S3 backends and external data support.

Each repository has separate S3 buckets for metadata and large files,
with direct client access to reduce bandwidth costs.

%prep
# Nothing to prepare

%build
# Nothing to build

%install
rm -rf $RPM_BUILD_ROOT

# Install configuration
mkdir -p $RPM_BUILD_ROOT/etc/cvmfs
cp -r %{_sourcedir}/etc/cvmfs/* $RPM_BUILD_ROOT/etc/cvmfs/

# Install keys
if [ -d "%{_sourcedir}/keys" ]; then
    mkdir -p $RPM_BUILD_ROOT/etc/cvmfs/keys
    cp -r %{_sourcedir}/keys/* $RPM_BUILD_ROOT/etc/cvmfs/keys/
fi

%files
%defattr(-,root,root,-)
/etc/cvmfs/domain.d/openemage.org.conf
%dir /etc/cvmfs/config.d
/etc/cvmfs/config.d/*.openemage.org.conf
%dir /etc/cvmfs/keys
/etc/cvmfs/keys/*

%post
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
echo "For documentation: https://openemage.org/docs"
echo "========================================================================="
echo ""

%changelog
* $(date '+%a %b %d %Y') OPENEMAGE Team <info@openemage.org> - VERSION_PLACEHOLDER-1
- Release VERSION_PLACEHOLDER
SPEC_EOF

# Replace version placeholder
sed -i "s/VERSION_PLACEHOLDER/${VERSION}/g" "${RPM_BUILD}/SPECS/cvmfs-config-openemage.spec"

# Build RPM
rpmbuild --define "_topdir ${RPM_BUILD}" \
         -bb "${RPM_BUILD}/SPECS/cvmfs-config-openemage.spec" >/dev/null 2>&1

# Copy to output
cp "${RPM_BUILD}/RPMS/noarch/cvmfs-config-openemage-${VERSION}-1.noarch.rpm" "${OUTPUT_DIR}/"
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
