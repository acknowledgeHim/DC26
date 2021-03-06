#
# instance.tf
#

# Generate a new SSH key for guacamole access

resource "null_resource" "ssh_key" {
  provisioner "local-exec" {
    command = <<EOF
mkdir -p ssh
rm -rf ssh/*
ssh-keygen -t rsa -b 2048 -P '' -f ssh/ssh_key -C 'user@example.com'
EOF
  }
}

resource "aws_instance" "workstation" {
  count         = "${var.workstation_count}"
  #ami           = "ami-a4dc46db" # public ubuntu image
  #ami           = "ami-ee8c9391" # private workstation image
  ami           = "ami-0c45e6b9dbaa16589" # new workstation image
  instance_type = "t2.medium"
  key_name      = "${var.aws_ssh_key_name}"
  depends_on    = ["null_resource.ssh_key"]

  associate_public_ip_address = true

  subnet_id                   = "${aws_subnet.default.id}"
  vpc_security_group_ids      = [ "${element(aws_security_group.workstation.*.id, count.index)}" ]

  root_block_device {
    volume_type = "gp2"
    delete_on_termination = true
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = "${file(var.aws_ssh_key_file)}"
  }


  # upload public key to workstation
  provisioner "file" {
    source      = "ssh/ssh_key.pub"
    destination = "/tmp/ssh_key.pub"
  }

  provisioner "file" {
    source      = "../workstation/workstation.sh"
    destination = "/tmp/workstation.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo useradd -m -s /bin/bash -p $(echo \"${element(random_string.password.*.result, count.index)}\" | openssl passwd -1 -stdin) ${element(keys(data.external.user_list.result), count.index)}",
      "sudo usermod -aG sudo ${element(keys(data.external.user_list.result), count.index)}",
      "sudo su - ${element(keys(data.external.user_list.result), count.index)} /bin/bash -c 'ls -la /home; mkdir -p $HOME/.ssh; echo \"$(cat /tmp/ssh_key.pub)\" >> $HOME/.ssh/authorized_keys'",
      "sudo /bin/bash -c 'echo export CONTROLLER_IP=${element(aws_instance.controller.*.private_ip, count.index)} > /etc/profile.d/workstation.sh'",
      "sudo bash /tmp/workstation.sh",
      "cd /home/${element(keys(data.external.user_list.result), count.index)}",
      "sudo sed -i -e 's/#force_color_prompt=yes/force_color_prompt=yes/g' .bashrc",
      "sudo su - ${element(keys(data.external.user_list.result), count.index)} /bin/bash -c 'source .bashrc'",
      "sudo su - ${element(keys(data.external.user_list.result), count.index)} /bin/bash -c 'git clone https://github.com/ackSec/DC26.git'",
      "sudo su - ${element(keys(data.external.user_list.result), count.index)} /bin/bash -c 'git clone https://github.com/ackSec/sdnpwn.git'",
      "cd sdnpwn/",
      "sudo chmod +x sdnpwn.py",
      "sudo chmod +x setup.sh",
      "sudo rm /tmp/ssh_key.pub"
    ]
  }

  volume_tags = "${merge(
    local.common_tags,
    map(
      "Name", "${local.instance_name_runtime}-${count.index + 1}-volume",
      "user", "${element(keys(data.external.user_list.result), count.index)}"
    )
  )}"

  tags = "${merge(
    local.common_tags,
    map(
      "Name", "${local.instance_name_runtime}-${count.index + 1}",
      "user", "${element(keys(data.external.user_list.result), count.index)}",
      "ssh_key_id", "${null_resource.ssh_key.id}"
    )
  )}"
}
