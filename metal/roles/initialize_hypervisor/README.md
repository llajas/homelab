Role Name
=========

This role checks that the libvirt service is listening on 0.0.0.0 and that the libvirt service is running. If the configuration is not correct, the role will correct it and restart the service, else it will do nothing.

Requirements
------------

This role requires the `libvirt` package to be installed on the target machine. This is the default hypervisor for Unraid.
This role also requires the `python3` package to be installed on the target machine for ansible to run against the target machine. This can be installed with NerdPack via the Unraid GUI in community applications.

Role Variables
--------------

This role has no variables, but it reads the Unraid address from the global ansible variables.

Dependencies
------------

N/A

Example Playbook
----------------

N/A

License
-------

BSD

Author Information
------------------

Lauren Lajas