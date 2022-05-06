# Hub

## Installing local certs to the CA
- Find root.crt under `caddy_data/caddy/pki/authorities/local/root.crt`
- Copy that to the local system
- Rename it to rootCA.pem
- install mkcert https://github.com/FiloSottile/mkcert
- CAROOT=`directory where rootCA.pem is present` mkcert -install
- If you would like to delete it, `CAROOT=`directory where rootCA.pem is present` mkcert -delete` 
