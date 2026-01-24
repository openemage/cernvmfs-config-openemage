# CVMFS Config Package Builder for OPENEMAGE

Build system for creating CVMFS client configuration packages for OPENEMAGE repositories.

## Quick Start

```bash
# 1. Add your repository's public key
mkdir -p src/etc/cvmfs/keys/cryoet-opendata-poc.openemage.org
cp /path/to/cryoet-opendata-poc.openemage.org.pub \
   src/etc/cvmfs/keys/cryoet-opendata-poc.openemage.org/

# 2. Build packages (requires fpm)
./build.sh 0.1.0

# 3. Packages appear in output/
ls output/
```

## Directory Structure

```
cvmfs-config-openemage-builder/
├── README.md                   # This file
├── build.sh                    # Main build script
│
├── src/                        # Source files for packages
│   └── etc/cvmfs/
│       ├── domain.d/
│       │   └── openemage.org.conf          # Domain-wide settings
│       ├── config.d/
│       │   ├── cryoet-opendata-poc.openemage.org.conf   # Per-repo config
│       │   └── TEMPLATE.openemage.org.conf               # Template
│       └── keys/
│           ├── cryoet-opendata-poc.openemage.org/
│           │   └── cryoet-opendata-poc.openemage.org.pub
│           └── <other-repo>.openemage.org/
│               └── <other-repo>.openemage.org.pub
│
├── build/                      # Temporary build files (generated)
└── output/                     # Final packages (generated)
    ├── cvmfs-config-openemage-VERSION.tar.gz
    ├── cvmfs-config-openemage_VERSION-1_all.deb
    └── cvmfs-config-openemage-VERSION-1.noarch.rpm
```

## Adding a New Repository

### Step 1: Create Repository Configuration

Create `src/etc/cvmfs/config.d/<repo-name>.openemage.org.conf`:

```bash
cat > src/etc/cvmfs/config.d/spatial-omics.openemage.org.conf << 'EOF'
# Spatial Omics Data Repository
# Repository: spatial-omics.openemage.org

# S3 backend for CVMFS metadata
CVMFS_SERVER_URL="https://spatial-omics-metadata.s3.eu-west-1.amazonaws.com/spatial-omics.openemage.org"

# S3 bucket for external data
CVMFS_EXTERNAL_URL="https://spatial-omics-data.s3.eu-west-1.amazonaws.com/spatial-omics.openemage.org"

# Public key location
CVMFS_KEYS_DIR="/etc/cvmfs/keys/spatial-omics.openemage.org"
EOF
```

### Step 2: Add Public Key

```bash
# Create key directory
mkdir -p src/etc/cvmfs/keys/spatial-omics.openemage.org

# Copy public key from publisher
scp user@publisher:/etc/cvmfs/keys/spatial-omics.openemage.org.pub \
    src/etc/cvmfs/keys/spatial-omics.openemage.org/
```

### Step 3: Build Packages

```bash
./build.sh 0.1.1
```

## Repository Configuration Details

### Domain Config (`domain.d/openemage.org.conf`)
- Shared settings for ALL `*.openemage.org` repositories
- Default proxy settings
- Cache quotas
- Timeouts

### Repository Config (`config.d/<repo>.openemage.org.conf`)
- Repository-specific URLs
- Each repo has its own:
  - Metadata S3 bucket (for CVMFS catalogs)
  - Data S3 bucket (for large external files)
  - Public key directory

### Key Structure
- Each repository has its own key directory
- Keys are included IN the packages
- Format: `/etc/cvmfs/keys/<repo-name>.openemage.org/<repo-name>.openemage.org.pub`

## Building Packages

Prerequisite: install `fpm` (https://github.com/jordansissel/fpm), e.g. `gem install fpm`.
On macOS, also install `gnu-tar` (for DEB) and `rpm` (for RPM) via Homebrew.

```bash
./build.sh [VERSION]

# Examples:
./build.sh 0.1.0    # First release
./build.sh 0.1.1    # Added new repository
./build.sh 0.2.0    # Major update
```

## Package Contents

All packages include:
1. Domain configuration (shared settings)
2. Per-repository configurations
3. Public keys for all configured repositories
4. Documentation and templates

## Installation (For End Users)

### Red Hat/Rocky/Alma/Fedora:
```bash
sudo yum install cvmfs
sudo rpm -ivh cvmfs-config-openemage-0.1.0-1.noarch.rpm
echo 'CVMFS_REPOSITORIES="cryoet-opendata-poc.openemage.org"' | sudo tee -a /etc/cvmfs/default.local
sudo cvmfs_config setup
sudo cvmfs_config probe
```

### Debian/Ubuntu:
```bash
sudo apt install cvmfs
sudo dpkg -i cvmfs-config-openemage_0.1.0-1_all.deb
echo 'CVMFS_REPOSITORIES="cryoet-opendata-poc.openemage.org"' | sudo tee -a /etc/cvmfs/default.local
sudo cvmfs_config setup
sudo cvmfs_config probe
```

### Manual (Tarball):
```bash
sudo tar -xzf cvmfs-config-openemage-0.1.0.tar.gz -C /
echo 'CVMFS_REPOSITORIES="cryoet-opendata-poc.openemage.org"' | sudo tee -a /etc/cvmfs/default.local
sudo cvmfs_config setup
sudo cvmfs_config probe
```

## Design Philosophy

This follows the EESSI model:
- **Domain config**: Shared defaults for the domain
- **Repository configs**: Specific URLs and keys per repo
- **Separate S3 buckets**: Each repo can use different buckets/regions
- **Keys included**: No manual key distribution needed

## Maintenance

### Updating a Repository

1. Update config file in `src/etc/cvmfs/config.d/`
2. Update public key if needed in `src/etc/cvmfs/keys/`
3. Rebuild with new version number
4. Distribute updated packages

### Adding S3 Mirrors

Edit repository config to add mirrors:

```bash
# In src/etc/cvmfs/config.d/<repo>.openemage.org.conf
CVMFS_SERVER_URL="https://bucket1.s3.region1.amazonaws.com/@fqrn@;https://bucket2.s3.region2.amazonaws.com/@fqrn@"
```

## License

GPLv3

## Contact

OPENEMAGE Team <info@openemage.org>
https://info.openemage.org
