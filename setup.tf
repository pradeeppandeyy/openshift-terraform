provider "google" {
  region = "${var.region}"
  project = "${var.project_name}"
  credentials = "${file("${var.credentials_file_path}")}"
}

resource "google_compute_network" "default" {
  name = "openshift-compute-network"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "default-us-east1" {
  name          = "openshift-subnetwork-us-east1"
  ip_cidr_range = "10.12.0.0/16"
  network       = "${google_compute_network.default.self_link}"
  region        = "us-east1"
  private_ip_google_access = "true"
}

resource "google_compute_firewall" "default" {
  name    = "allow-openshift-vm-ssh"
  network = "${google_compute_network.default.name}"
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags = ["netgateway"]
}

resource "google_compute_firewall" "internal" {
  name    = "allow-openshift-internal-network"
  network = "${google_compute_network.default.name}"
  allow {
    protocol = "tcp"
    ports = ["1-65535"]
  }
  allow {
    protocol = "udp"
    ports = ["1-65535"]
  }
  source_ranges = ["10.12.0.0/16"]
}

resource "google_compute_instance" "default" {
  name         = "openshift-netgateway"
  machine_type = "f1-micro"
  zone         = "${var.region_zone}"
  tags = ["netgateway", "bastion-host" , "nat"]
  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7-v20180129"
      size = "15"
    }
  }
  network_interface {
//    network = "${google_compute_network.default.name}"
    subnetwork = "${google_compute_subnetwork.default-us-east1.name}"
    access_config {
      // Ephemeral IP
    }
  }
  metadata_startup_script = "echo 1 > /proc/sys/net/ipv4/ip_forward"
  metadata {
  ssh-keys = "root:${file("${var.public_key_path}")}"
  }
  service_account {
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring.write",
        "https://www.googleapis.com/auth/servicecontrol",
        "https://www.googleapis.com/auth/service.management.readonly",
        "https://www.googleapis.com/auth/trace.append"]
  }
  can_ip_forward = "true"
}

resource "google_compute_route" "default" {
  name        = "openshift--no-ip-route"
  dest_range  = "0.0.0.0/0"
  network     = "${google_compute_network.default.name}"
  next_hop_instance = "openshift-netgateway"
  next_hop_instance_zone = "us-east1-b"
  priority    = 800
  tags = ["openshift-no-ip"]
}

resource "google_compute_disk" "master-docker-disk-1" {
  name  = "master-docker-disk-1"
  type  = "pd-standard"
  zone  = "us-east1-b"
  size  = "25"
}

resource "google_compute_instance" "master-1" {
  name         = "ocp-master-1"
  machine_type = "n1-standard-2"
  zone         = "${var.region_zone}"
  tags = ["openshift-no-ip" , "ocp-master"]
  boot_disk {
    initialize_params {
      image = "rhel-cloud/rhel-7-v20180129"
      size = "10"
    }
  }
  attached_disk {
    source = "${google_compute_disk.master-docker-disk-1.self_link}"
  }
  network_interface {
    subnetwork = "${google_compute_subnetwork.default-us-east1.name}"
    address = "10.12.0.3"

  }
  metadata {
  ssh-keys = "root:${file("${var.public_key_path}")}"
  }
  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_compute_disk" "node-docker-disk-1" {
  name  = "node-docker-disk-1"
  type  = "pd-standard"
  zone  = "us-east1-b"
  size  = "25"
}

resource "google_compute_instance" "node-1" {
  name         = "ocp-node-1"
  machine_type = "n1-standard-1"
  zone         = "${var.region_zone}"
  tags = ["openshift-no-ip" , "ocp-node"]
  boot_disk {
    initialize_params {
      image = "rhel-cloud/rhel-7-v20180129"
      size = "10"
    }
  }
  attached_disk {
    source = "${google_compute_disk.node-docker-disk-1.self_link}"
  }
  network_interface {
    subnetwork = "${google_compute_subnetwork.default-us-east1.name}"
    address = "10.12.0.10"

  }
  metadata {
  ssh-keys = "root:${file("${var.public_key_path}")}"
  }
  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
