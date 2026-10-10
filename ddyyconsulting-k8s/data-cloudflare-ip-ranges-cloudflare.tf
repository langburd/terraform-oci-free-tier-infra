# Cloudflare's published edge ranges. Used ONLY for the Traefik entrypoint's trusted
# forwarded-headers list, so the origin trusts XFF from Cloudflare and nobody else.
# (Service.loadBalancerSourceRanges is deliberately not used — the OCI CCM ignores it
# for NLBs; the network-level lockdown lives in lb_nsg/worker_nsg in ../ddyyconsulting.)
# IPv4 only: the origin NLB has no IPv6 address and the A record has no AAAA peer,
# so Cloudflare always reaches it over IPv4.
# NOTE: ../ddyyconsulting derives the same list from https://www.cloudflare.com/ips-v4
# instead. If the two ever disagree, an edge IP the NSG admits but trustedIPs omits
# makes Traefik discard XFF, and the ipAllowList then 403s legitimate clients.
data "cloudflare_ip_ranges" "cloudflare" {}
