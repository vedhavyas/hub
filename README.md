Thoughts:
- Basic auth to specific services through caddy basic auth - https://caddyserver.com/docs/caddyfile/directives/basicauth#basicauth
- https://vsupalov.com/upgrade-docker-compose-file-version/
  https://vsupalov.com/what-is-docker-swarm/
  
netdata
- https://blog.ssdnodes.com/blog/vps-monitoring-self-hosting/
> https://learn.netdata.cloud/docs/agent/packaging/docker/#create-a-new-netdata-agent-container
> 
> 
auto create file structure
post any post run script to see configs and make any post installation changes
https://github.com/Monitorr/Monitorr
docker versions no latest
wait until all the containers are fully up
seperate openvpn to a different container for eaiser re-use than just tranmission app


# TODO(ved): docker socket proxy. It worked but needs to be specific for portainer. For now, its fine
# TODO(ved): ensure configs are ephemeral so that restart takes new configs
# TODO(ved): https://crazymax.dev/diun/install/docker/
# TODO(ved): vpn through wireguard
## Post installation
### Netdata
- do not expose any ports. Once you have signed up using netdata.cloud, claim your node by running docker command.

### Organizr
- Set up organizr

### Bitwarden
- Setup bitwarden
- use the admin key to log in to `/admin` page

### setup jellyfin
- setup and customise

### jackett and flaresolverr
- set admin password in jackett
- add flare solverr url

### transmission
- needs to enable basic auth
### Sonarr
- setup and enable auth
- follow jackett instructions to setup
