# lftp-mirror-action
GitHub action to mirror local and remote files using lftp.

It has been created for SFTP, though it might work with other scheme.

## Usage

> :warning: Beware this action expects SSH_AUTH_SOCK to be set
            to contact an ssh agent loaded with a valid private key.

```yaml
    - name: Mirror content from remote server
      id: agent
      uses: LeastAuthority/ltfp-mirror@v1
      with:
        src: sftp://alice@example.com/www/html/
        dst: ./target/site/
```

Alternatively, the transfer can be reversed by flipping `src` and `dst`.
And the private key can be specify along other advanced options. 

```yaml
    - name: Mirror content to remote server
      id: agent
      uses: LeastAuthority/ltfp-mirror@v1
      with:
        src: ./target/site/
        dst: sftp://alice@example.com/www/html/
        connect_program: 'ssh -o StrictHostKeyChecking=no -i /path/key'
        delete: true
        mirror_options: --exclude ".*\.tmp"
```
