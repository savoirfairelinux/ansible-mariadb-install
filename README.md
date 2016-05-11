# mariadb-install

*Securely sets up mariadb*

* Installs mariadb
* Sets a root password
* Creates `/root/.my.cnf` for passwordless root login for root user
* Disable remote access to root account

## Requirements

* Ansible 2.0+
* Debian jessie target


## Example

```
- role: mariadb-install
  mariadb_root_password: letmein
```
