package wireguard

import (
	_ "embed"
	"fmt"
	"log"
	"net"
	"strings"
	"text/template"
	"time"

	"hub"

	"github.com/BurntSushi/toml"
	"golang.zx2c4.com/wireguard/wgctrl/wgtypes"
)

type Data struct {
	Server *Server `toml:"server"`
}

//go:embed wireguard_server.goconf
var serverConfTmpl string

func (d Data) ServerConf() (string, error) {
	t := template.Must(template.ParseGlob(serverConfTmpl))
	var buf strings.Builder
	return buf.String(), t.Execute(&buf, d.Server)
}

type Network struct {
	dataDir string
	config  hub.Network
}

func New(dataDir string, config hub.Network) (Network, error) {
	dataDir = strings.TrimSuffix(dataDir, "/")
	return Network{dataDir: fmt.Sprintf("%s/wireguard", dataDir), config: config}, nil
}

func (n Network) Sync(session *hub.Session) error {
	var data Data
	_, err := toml.DecodeFile(fmt.Sprintf("%s/data.toml", n.dataDir), &data)
	if err != nil {
		log.Println("Creating wireguard server conf...")
		data.Server, err = createServer(n.config.WireGuardNetwork, n.config.DNS, n.config.WireguardListenPort)
		if err != nil {
			return fmt.Errorf("failed to creare wireguard server: %v", err)
		}
	}
	serverConf, err := data.ServerConf()
	if err != nil {
		return fmt.Errorf("failed to create server conf: %v", err)
	}

	err = session.WriteDataToFile([]byte(serverConf), "/etc/wireguard/wg-hub.conf")
	if err != nil {
		return fmt.Errorf("failed to write server conf: %v", err)
	}

	return nil
}

func createServer(network, dns string, serverPort uint) (*Server, error) {
	ip, ipnet, err := net.ParseCIDR(network)
	if err != nil {
		return nil, fmt.Errorf("failed to parse netowrk: %v", err)
	}

	priv, err := wgtypes.GeneratePrivateKey()
	if err != nil {
		return nil, fmt.Errorf("failed to generate server secret: %v", err)
	}

	return &Server{
		NetworkAddress: *ipnet,
		Address:        ipAddrFromID(ip, 1),
		DNS:            net.ParseIP(dns),
		ListenPort:     serverPort,
		PrivateKey:     priv,
		NextID:         2,
		PeerMap:        make(map[uint8]Peer),
	}, nil
}

func ipAddrFromID(ip net.IP, value uint8) net.IP {
	ip[3] = byte(value)
	return ip
}

type Peer struct {
	ID                          uint8         `toml:"id"`
	Address                     net.IP        `toml:"address"`
	PrivateKey                  wgtypes.Key   `toml:"private_key"`
	PresharedKey                wgtypes.Key   `toml:"preshared_key"`
	Endpoint                    net.UDPAddr   `toml:"endpoint"`
	DNS                         net.IP        `toml:"dns"`
	PersistentKeepaliveInterval time.Duration `toml:"persistent_keepalive_interval"`
	AllowedIPs                  net.IPNet     `toml:"allowed_ips"`
	CreatedAt                   time.Time     `toml:"created_at"`
}

type Server struct {
	NetworkAddress net.IPNet      `toml:"network_address"`
	Address        net.IP         `toml:"address"`
	DNS            net.IP         `toml:"dns"`
	ListenPort     uint           `toml:"listen_port"`
	PrivateKey     wgtypes.Key    `toml:"private_key"`
	NextID         uint8          `toml:"next_id"`
	PeerMap        map[uint8]Peer `toml:"peer_map"`
}

type clientConfWrapper struct {
	Server Server
	Peer   Peer
}
