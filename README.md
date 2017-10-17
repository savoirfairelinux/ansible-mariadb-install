# mariadb-install

*Securely sets up mariadb*

* Installs mariadb
* Sets a root password
* Creates `/root/.my.cnf` for passwordless root login for root user
* Disable remote access to root account

## Requirements

* Ansible 2.1+
* One of the supported targets:
  * Debian jessie
  * Debian stretch
  * Ubuntu Trusty
  * Ubuntu Xenial

## Example

```
- role: mariadb-install
  mariadb_root_password: letmein
```

## Allow outbound connections

By default, this role results in a mariadb server that only listens to `localhost`. However, if you
need to allow for outbound logins, you can specify a list of users that are allowed for outbound
logins with `mariadb_accept_outbound_login_for_these_users`.

**Warning:** Setting this variable to a non-empty lists changes the IP mariadb binds to from
`127.0.0.1` to `0.0.0.0`. Make sure that your setup is sound before using this.
