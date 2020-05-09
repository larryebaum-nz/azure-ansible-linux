## file inventory.tpl

http:
  hosts:
    ${http_pub_ip}
  vars:
    ansible_ssh_user: ${ans_ssh_user}
