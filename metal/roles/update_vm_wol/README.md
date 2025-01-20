Role Name
=========

This role modifies the `/boot/config/wol.json` file on an Unraid machine to add virtual nodes specified in the inventory to allow said hosts to be powered on via WoL magic packets

Requirements
------------

This role also requires the `python3` package to be installed on the target machine for ansible to run against the target machine. This can be installed with NerdPack via the Unraid GUI in community applications.
This role also relies on the community plugin WOLforServices for Unraid, a community provided [plugin](https://github.com/SimonFair/WOLforServices/). It modifies the `wol.json` file to include any MAC addresses for virtual hosts found in the Ansible inventory.

Role Variables
--------------

This role has no variables, but it reads the Unraid address from the global ansible variables.

Dependencies
------------

[WOLforServices](https://github.com/SimonFair/WOLforServices/)

Example Playbook
----------------

N/A

License
-------

BSD

Author Information
------------------

Lauren Lajas