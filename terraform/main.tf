##########################################
# VPC
##########################################
resource "google_compute_network" "vpc" {
  name                    = "dci-vpc"
  auto_create_subnetworks = false
}

##########################################
# PUBLIC SUBNET
##########################################
resource "google_compute_subnetwork" "public" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

##########################################
# FIREWALL RULE — OPEN PORT 5000
##########################################
resource "google_compute_firewall" "allow_flask" {
  name    = "allow-flask"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = ["0.0.0.0/0"]
}

##########################################
# COS VM + CONTAINER
##########################################
resource "google_compute_instance" "backend" {
  name         = "backend-instance"
  machine_type = "e2-medium"
  zone         = var.zone

  ########################################
  # Boot disk — COS stable
  ########################################
  boot_disk {
    auto_delete = true
    initialize_params {
      image = "projects/cos-cloud/global/images/family/cos-stable"
      size  = 10
      type  = "pd-standard"
    }
  }

  ########################################
  # Network
  ########################################
  network_interface {
    subnetwork = google_compute_subnetwork.public.id

    # Assign public IP
    access_config {}
  }

  ########################################
  # CONTAINER DECLARATION (VALID YAML)
  ########################################
  metadata = {
    "gce-container-declaration" = <<EOF
spec:
  containers:
    - name: flask-backend
      image: "${var.docker_image}"
      env:
        - name: PORT
          value: "5000"
      ports:
        - containerPort: 5000
  restartPolicy: Always
EOF
  }

  tags = ["flask-backend"]
}

##########################################
# OUTPUT — PUBLIC IP
##########################################
output "public_ip" {
  description = "Public IP of the backend VM"
  value       = google_compute_instance.backend.network_interface[0].access_config[0].nat_ip
}

