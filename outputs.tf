############
### Key Pair
############
output "private_key" {
  value     = tls_private_key.DemoPrivateKey.private_key_pem
  sensitive = true
}