package wireguard

import "golang.zx2c4.com/wireguard/wgctrl/wgtypes"

type Config struct {
	ListenPort int         `json:"listen_port"`
	PrivateKey wgtypes.Key `json:"private_key"`
	NextID     uint8
	PeerMap    map[uint8]wgtypes.PeerConfig `json:"peer_map"`
}

type Data struct {
	HubConfig Config `json:"hub_config"`
}
