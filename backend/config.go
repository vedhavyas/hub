package hub

import (
	_ "embed"
	"fmt"
	"os"
	"strings"

	"github.com/BurntSushi/toml"
)

type Config struct {
	Path       string      `toml:"path"`
	Remote     Remote      `toml:"remote"`
	Components []Component `toml:"components"`
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

//go:embed base_config.toml
var baseConfig string

func LoadConfig(path string) (Config, error) {
	var config Config
	_, err := toml.Decode(baseConfig, &config)
	if err != nil {
		return config, fmt.Errorf("failed to load base config: %v", err)
	}

	_, err = toml.DecodeFile(path, &config)
	return config, err
}

func SaveConfig(config Config) error {
	f, err := os.Create(config.Path)
	if err != nil {
		return fmt.Errorf("failed to create config file: %v", err)
	}
	defer f.Close()

	enc := toml.NewEncoder(f)
	err = enc.Encode(config)
	if err != nil {
		return fmt.Errorf("failed to save config: %v", err)
	}

	return nil
}
