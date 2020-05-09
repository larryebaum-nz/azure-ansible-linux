## file inventory.tf

data "template_file" "inventory" {
    template = "${file("./inventory.tpl")}"

    vars = {
       http_pub_ip = "${azurerm_public_ip.publicip.ip_address}"
       ans_ssh_user = "${var.admin_username}"
    }
}

resource "local_file" "save_inventory" {
  content  = "${data.template_file.inventory.rendered}"
  filename = "./ansible/http_inventory.yaml"
}
