# Self CA

## Generate a self-signed CA certificate and private key

```bash
mkdir -p root_ca
cfssl gencert -initca root_ca.json | cfssljson -bare root_ca/ca
```
