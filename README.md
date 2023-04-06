# lftp-mirror-action
GitHub action to mirror local and remote files using lftp.

It has been created for SFTP and assumes the SSH connection to be ready.
Which means a valide private key in ~/.ssh or agent loaded with it.

## Usage

```yaml
    - name: Mirror content to remote server
      id: agent
      uses: LeastAuthority/ltfp-mirror@v1
      with:
        remote: sftp://alice@example.com/www
        local_dir: ./target/html
        reverse: true
        delete: true
        mirror_options: --exclude ".*\.tmp"
```
