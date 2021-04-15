# This is my cloud server

## How to start one?
- Ensure, you have the .env file filled accordingly
- use `make up` to start the services.

## Post Installation
- Netdata
  - Once installed, you can use netdata cloud to monitor your node by using their docker claim node command
  
- Portainer
  - you can login using admin password provided in the .env file
  
- Bitwarden
  - Create an account
  - Verify the account
  - Then login and disable registrations 
  - use the admin key provided in the .env to log in to `/admin` page
  
- Jackett
  - Use basic auth to login 
  - Add the indexers you like
  - Connect to flaresolverr and any other changes
  
- Transmission
  - Nothing needs to be changed unless you kno what you are doing
  
- Sonarr and Radarr
  - Add root folder
  - Connect jackett with the indexers
  - Connect transmission download client

- Jellyfin
  - Create a new admin user
  - Add libraries
  
- Organizr
  - Connect jellyfin, sonarr etc...
  


TODO:
- Cleanup and backup: 
  - Jellyfin: https://github.com/terrelsa13/media_cleaner
- Checkout Monitorr https://github.com/Monitorr/Monitorr
- Separate openvpn/wireguard to a different container so that multiple containers can route traffic through VPN
- Secure Docker socket proxy. It worked but needs to be specific for portainer.
- Checkout https://crazymax.dev/diun/install/docker/
