# Public Keys for OPENEMAGE Repositories

Each repository has its own key directory:

```
src/keys/
├── cryoet-opendata-poc.openemage.org/
│   └── cryoet-opendata-poc.openemage.org.pub
├── another-repo.openemage.org/
│   └── another-repo.openemage.org.pub
└── ...
```

## Adding Keys for a New Repository

```bash
# Create directory for the repository
mkdir -p src/keys/your-repo.openemage.org

# Copy public key from publisher
scp user@publisher:/etc/cvmfs/keys/your-repo.openemage.org.pub \
    src/keys/your-repo.openemage.org/
```

## Key Format

Keys should be RSA public keys in PEM format:

```
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END PUBLIC KEY-----
```
