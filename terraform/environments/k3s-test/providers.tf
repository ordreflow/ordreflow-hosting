# Credentials come from HCLOUD_TOKEN, CLOUDFLARE_API_TOKEN, and GITHUB_TOKEN.
provider "hcloud" {}

provider "cloudflare" {}

provider "github" {
  owner = "ordreflow"
}
