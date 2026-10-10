# Cloudflare zone lookup (provider v5).
data "cloudflare_zone" "this" {
  filter = { name = local.cloudflare_zone_name }
}
