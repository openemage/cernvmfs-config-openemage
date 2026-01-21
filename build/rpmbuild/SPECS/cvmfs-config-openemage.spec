Summary: CernVM-FS configuration for OPENEMAGE repositories
Name: cvmfs-config-openemage
Version: 1.0.0
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
* $(date '+%a %b %d %Y') OPENEMAGE Team <info@openemage.org> - 1.0.0-1
- Release 1.0.0
