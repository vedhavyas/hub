package hub

import (
	_ "embed"
	"fmt"
	"os"
	"strings"

	"github.com/BurntSushi/toml"
	"github.com/sirupsen/logrus"
)

var log = logrus.New()

func Logger() *logrus.Logger {
	return log
}

type Unit interface {
	Name() string
	Prepare(config Config, session *Session) error
	Sync(config Config, session *Session) error
}

type Connection struct {
	Addr   string `toml:"addr"`
	Port   uint   `toml:"port"`
	User   string `toml:"user"`
	Passwd string `toml:"passwd"`
}

type Mullvad struct {
	Account         string   `toml:"account"`
	DefaultLocation string   `toml:"default_location"`
	OtherLocations  []string `toml:"other_locations"`
}

type Gateway struct {
	EnableHost bool    `toml:"enable_host"`
	Mullvad    Mullvad `toml:"mullvad"`
}

type Network struct {
	Gateway                  Gateway `toml:"gateway"`
	WireguardListenPort      uint    `toml:"wireguard_listen_port"`
	WireGuardNetwork         string  `toml:"wireguard_network"`
	DockerHostGatewayNetwork string  `toml:"docker_host_gateway_network"`
	DockerVPNGatewayNetwork  string  `toml:"docker_vpn_gateway_network"`
	DNS                      string  `toml:"dns"`
}

type SFTPStorage struct {
	LocalMountPath string `toml:"local_mount_path"`
	Name           string `toml:"name"`
	Host           string `toml:"host"`
	User           string `toml:"user"`
	Password       string `toml:"password"`
	CryptPassword1 string `toml:"crypt_password_1"`
	CryptPassword2 string `toml:"crypt_password_2"`
}

type Config struct {
	Path         string        `toml:"path"`
	AppDir       string        `toml:"app_dir"`
	Connection   Connection    `toml:"connection"`
	Network      Network       `toml:"network_config"`
	SFTPStorages []SFTPStorage `toml:"sftp_storages"`
}

func (c Config) String() string {
	var buf strings.Builder
	enc := toml.NewEncoder(&buf)
	err := enc.Encode(c)
	if err != nil {
		panic("failed to encode config")
	}

	return buf.String()
}

//go:embed config.toml
var baseConfig string

func LoadConfig(path string) (Config, error) {
	var config Config
	_, err := toml.Decode(baseConfig, &config)
	if err != nil {
		return config, fmt.Errorf("failed to load base config: %v", err)
	}

	_, err = toml.DecodeFile(path, &config)
	if err != nil {
		log.Debugf("failed to open config from home dir. Might be missing. Ignoring...")
	}

	return config, nil
}

func SaveConfig(config Config) error {
	f, err := os.Create(config.Path)
	if err != nil {
		return fmt.Errorf("failed to create config file: %v", err)
	}
	defer f.Close()

	enc := toml.NewEncoder(f)
	enc.Indent = ""
	err = enc.Encode(config)
	if err != nil {
		return fmt.Errorf("failed to save config: %v", err)
	}

	return nil
}
