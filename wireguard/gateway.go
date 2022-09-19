package wireguard

type (
	Conf struct {
		PrivateKey  string `json:"private_key"`
		PeerAddress string `json:"peer_address"`
		PeerPubKey  string `json:"peer_pub_key"`
	}

	Gateway struct {
		Country Country `json:"country"`
		City    City    `json:"city"`
		Conf    Conf    `json:"conf"`
	}

	Country   string
	City      string
	Locations map[Country][]City

	GatewayProvider interface {
		Locations() (Locations, error)
		AllocatePeer(country Country, city City) (Conf, error)
		AllocatePort(country Country, city City) (int, error)
	}
)

func Create() {

}
