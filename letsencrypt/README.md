Issue Letsencrypt Certificate
=============================

Issue certificate using [acme.sh client](https://github.com/Neilpang/acme.sh)

Install
```bash
git clone https://github.com/Neilpang/acme.sh.git
cd ./acme.sh
./acme.sh --install
```

Issue using dns API mode (cloudflare)
```bash
export CF_Key="API_KEY_HERE"
export CF_Email="EMAIL_HERE"
./acme.sh --issue -d nalkins.cloud -d *.nalkins.cloud --dns dns_cf
```