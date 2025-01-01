# python_standalone

[![Role - python_standalone](https://github.com/syndr/ansible-role-python_standalone/actions/workflows/role-python_standalone.yml/badge.svg)](https://github.com/syndr/ansible-role-python_standalone/actions/workflows/role-python_standalone.yml)

_Role based upon [vmware/ansible-coreos-bootstrap](https://github.com/vmware/ansible-coreos-bootstrap) with updates for current pypy builds._

In order to effectively run ansible, the target machine needs to have a python interpreter. Some machines are minimal and do not ship with any version of python. Some machines are old, and don't have a modern version of Python packaged for them. To get around these limitations we can install [pypy](http://pypy.org/), a lightweight python interpreter. The `python_standalone` role will install pypy, which can then be configured for use by Ansible via inventory host variables or autodiscovery.

By default, the Python executable will be at `/opt/python/pypy/bin/python`. If you wish for PyPy to be installed to a different location, you can set the `python_standalone_pkg_home` variable to the base path that you desire.

Furthermore, the role can create a launcher for python at the configured `python_standalone_bin_path` location. This will allow you to run python scripts using the `python3.10` command (by default), provided that the `/usr/local/bin` directory is in your `PATH`.

# Install

## Prerequisites

This role requires Ansible 2.12 or later.

The following packages are required to be installed on the target machine:
- `curl`
- `tar`
- `bzip2`

# Role Configuration

```yaml
python_standalone_ssl_certs: "/etc/ssl/certs"
python_standalone_pkg_home: "/opt/python"

# Location to place a launcher for the Python binary (IE: /usr/local/bin/python3.10)
#  - set to "" to disable
#  WARNING: This uses a shell script launcher to execute the Python binary within the virtualenv
python_standalone_bin_path: /usr/local/bin/python3.10

# Force (re)installation even if PyPy is detected as already installed
python_standalone_pypy_force_install: false

# The pypy version from https://www.pypy.org/download.html
python_standalone_pypy_version: "3.10-v7.3.17"
# The checksum of the downloaded archive; published at https://www.pypy.org/checksums.html
python_standalone_pypy_sha256: "fdcdb9b24f1a7726003586503fdeb264fd68fc37fbfcea022dcfe825a7fee18b"

# Download base URL and system type -- should not need to be changed
python_standalone_pypy_url: "https://downloads.python.org/pypy"
python_standalone_pypy_flavor: "linux64"

# List of Python modules that should be installed
# Note that this only supports adding, and not removing packages at this time!
python_standalone_pypy_modules:
  - docker-py
  - requests>2.32.0   # Requests 2.32.2+ requires community.docker 3.10.2+ -- see https://github.com/ansible-collections/community.docker/issues/860


# The virtualenv version from here: https://github.com/pypa/get-virtualenv/releases
python_standalone_venv_version: "20.28.0"
# The sha256sum of the downloaded .pyz file
python_standalone_venv_sha256: "479a2d9187b93fe6574ca5aa25df723749811d12ece46d500ae52dc04bc02e17"

# The URL from which to download virtualenv -- should not need to be changed
python_standalone_venv_url: "https://github.com/pypa/get-virtualenv/blob/{{ python_standalone_venv_version }}/public/virtualenv.pyz?raw=true"
```

If a different version of Pypy or Virtualenv is specified, the role will reinstall the application with the specified versions of each.

Pypy modules will also be installed as needed based upon the specified list.

# Host Configuration

If the `python_standalone_bin_path` option is not used, Ansible will need to be configured to use an alternative python interpreter for CoreOS hosts. 

This is done by specifying the `ansible_python_interpreter` variable, which can be defined in various locations. One such was is by adding a `coreos` group to your inventory file and setting the group's vars to use the new python interpreter. This way, you can use Ansible to manage CoreOS and non-CoreOS hosts. Simply put every host that has CoreOS into the `coreos` inventory group and it will automatically use the specified python interpreter.
```
[coreos]
host-01
host-02

[coreos:vars]
ansible_ssh_user=core
ansible_python_interpreter="/opt/python/pypy/bin/python"
```

This will configure ansible to use the python interpreter at `/opt/python/pypy/bin/python` which will be created by this role.

For AWX/Tower users, the `ansible_python_interpreter` variable will be configured in the "Variables" field of the appropriate inventory or group.

# Using the Role

Now you can simply add the following to your playbook file and include it in your `site.yml` so that it runs on all hosts in the coreos group.

```yaml
- hosts: coreos
  gather_facts: False
  roles:
    - syndr.python_standalone
```

You can also include it the task level using `include_role` or `import_role`, such as:

```yaml
- hosts: coreos
  gather_facts: false
  tasks:
    - name: Install pypy
      ansible.builtin.include_role:
        name: syndr.python_standalone
      vars:
        python_standalone_pypy_version: 3.9-v7.3.11
        python_standalone_pypy_sha256: d506172ca11071274175d74e9c581c3166432d0179b036470e3b9e8d20eae581
```

Using `include_role` has the benefit of allowing greater control of when the role is run.

Variables are located in `defaults/main.yml` and should be overridden as needed in your playbook either globally via something like AWX, or when importing this role.

Make sure that `gather_facts` is set to false, otherwise Ansible will try to first gather system facts using python which is not yet installed!

# License

MIT

# Author Information

- [syndr](https://github.com/syndr)

