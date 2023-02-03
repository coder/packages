packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "coder_version" {
  type = string
}

local "safe_version" {
  expression = replace(var.coder_version, "v", "")
}

variable "append_version" {
  type    = string
  default = ""
}

source "amazon-ebs" "ubuntu" {
  ami_name        = "coder-v${local.safe_version}${var.append_version}"
  ami_description = <<EOF
  Coder v${local.safe_version}${var.append_version}: Self-Hosted Remote Development Environments

  Ubuntu 22.04 AMI with Coder pre-installed, Docker, and TLS public tunnel.

  https://github.com/coder/packer-images
  EOF
  instance_type   = "t2.large"
  region          = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
  tags = {
    Name       = "Coder"
    OS_Version = "Ubuntu"
  }
}

build {
  name = "coder"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "shell" {
    inline = ["cloud-init status --wait"]
  }

  provisioner "shell" {
    inline = ["mkdir -p /tmp/packer"]
  }

  provisioner "file" {
    destination = "/tmp/packer/etc/"
    source      = "files/etc/"
  }

  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive", "LC_ALL=C", "LANG=en_US.UTF-8", "LC_CTYPE=en_US.UTF-8"]
    inline           = ["apt-get -qqy update", "apt -qqy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' full-upgrade", "apt-get -qqy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install apt-transport-https ca-certificates curl jq linux-image-extra-virtual software-properties-common", "apt-get -qqy clean"]
    execute_command  = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
  }

  provisioner "file" {
    destination = "/tmp/packer/etc/"
    source      = "files/etc/"
  }

  provisioner "shell" {
    inline          = ["rsync -a  /tmp/packer/ / && rm -rf /tmp/packer/"]
    execute_command = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
  }


  provisioner "shell" {
    environment_vars = ["VERSION=${local.safe_version}", "DEBIAN_FRONTEND=noninteractive", "LC_ALL=C", "LANG=en_US.UTF-8", "LC_CTYPE=en_US.UTF-8"]
    scripts = [
      "files/scripts/010-docker.sh",
      "files/scripts/011-grub-opts.sh",
      "files/scripts/012-ufw-config.sh",
      "files/scripts/013-postgresql.sh",
      "files/scripts/014-coder.sh"
    ]
    execute_command = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
  }


  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive", "LC_ALL=C", "LANG=en_US.UTF-8", "LC_CTYPE=en_US.UTF-8"]
    scripts          = ["files/scripts/999-cleanup.sh"]
    execute_command  = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
  }

  # Store details in packer-manifest.json
  # to retrieve AMI
  post-processor "manifest" {
  }
}
