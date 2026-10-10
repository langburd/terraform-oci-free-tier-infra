data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  # Caller's current public IP as a /32, used to scope bastion client access.
  my_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}
