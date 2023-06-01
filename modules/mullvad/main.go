package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"golang.zx2c4.com/wireguard/wgctrl/wgtypes"
	"io"
	"math/rand"
	"net/http"
	"os"
	"strings"
	"time"
)

func main() {
	acc := os.Getenv("MULLVAD_ACCOUNT")
	// citycode is {country_code}-{city_code} from relay
	// or, it could be just country_code
	// use ',' to add multiple codes.
	// if set as "random" then we pick a random one form the all relays
	cityCode := os.Getenv("MULLVAD_CITY_CODE")

	if acc == "" || cityCode == "" {
		panic("MULLVAD_ACCOUNT and(or) MULLVAD_CITY_CODE not set.")
	}

	// login
	data := try(login(acc))

	//// remove all ports
	//for _, port := range data.Account.CityPorts {
	//	fmt.Printf("Removing port[%v] in City[%s]\n", port.Port, port.CityCode)
	//	err := removePort(data.AuthToken, port.Port, port.CityCode)
	//	if err != nil {
	//		panic(err)
	//	}
	//}

	// remove all peers
	for _, peer := range data.Account.WgPeers {
		fmt.Printf("Removing peer: %v\n", peer.Key.Public)
		err := removePeer(data.AuthToken, peer.Key.Public)
		if err != nil {
			panic(err)
		}
	}

	// get relays
	relayMap := try(wireguardRelays())

	// filter relay
	var relays []Relay
	switch cityCode {
	case "random":
		for _, r := range relayMap {
			relays = append(relays, r...)
		}
	default:
		cityCodes := strings.Split(cityCode, ",")
		for _, code := range cityCodes {
			relays = append(relays, relayMap[code]...)
		}
	}

	if len(relays) < 1 {
		for code := range relayMap {
			fmt.Println(code)
		}
		panic("Wireguard relays are not available. Pick a different Country or City.")
	}
	relay := relays[rand.Intn(len(relays))]
	fmt.Printf("Picked relay: %s\n", relay.Pubkey)

	// add peer
	priv := try(wgtypes.GeneratePrivateKey())
	pub := priv.PublicKey()
	fmt.Println("Adding peer...")
	peerAddr := try(addPeer(data.AuthToken, pub.String()))

	//// add port
	//fmt.Println("Adding port...")
	//port := try(addPort(data.AuthToken, pub.String(), relay.CityCode))

	// create wg conf
	fmt.Println("Writing conf...")
	if err := createWGConf(priv.String(), relay.Pubkey, relay.Endpoint); err != nil {
		panic(err)
	}

	// create env file
	fmt.Println("Writing envs...")
	if err := createEnvFile(peerAddr, 0); err != nil {
		panic(err)
	}
}

func createWGConf(priv, peerPub, peerEndpoint string) error {
	data := fmt.Sprintf(`[Interface]
PrivateKey = %s

[Peer]
PublicKey = %s
AllowedIPs = 0.0.0.0/0
Endpoint = %s
PersistentKeepalive = 25
`, priv, peerPub, peerEndpoint)
	return os.WriteFile("/data/mullvad.conf", []byte(data), 0777)
}

func createEnvFile(ifAddr string, port int) error {
	data := fmt.Sprintf(`# mullvad source files
MULLVAD_VPN_ID_ADDR=%s
MULLVAD_VPN_FORWARDED_PORT=%d
`, ifAddr, port)
	return os.WriteFile("/data/mullvad.env", []byte(data), 0777)
}

func try[T any](res T, err error) T {
	if err != nil {
		panic(err)
	}

	return res
}

type AccountData struct {
	AuthToken string `json:"auth_token"`
	Account   struct {
		Active     bool `json:"active"`
		ExpiryUnix int  `json:"expiry_unix"`
		CityPorts  []struct {
			Port     int    `json:"port"`
			CityCode string `json:"city_code"`
		} `json:"city_ports"`
		WgPeers []struct {
			Key struct {
				Public string `json:"public"`
			} `json:"key"`
		} `json:"wg_peers"`
	} `json:"account"`
}

func login(acc string) (ld AccountData, err error) {
	url := fmt.Sprintf("https://api.mullvad.net/www/accounts/%s/", acc)
	err = call("GET", url, "", nil, &ld)
	return ld, err
}

type Relay struct {
	CityCode string `json:"city"`
	Endpoint string `json:"ipv4_addr_in"`
	Pubkey   string `json:"pubkey"`
}

func wireguardRelays() (relays map[string][]Relay, err error) {
	url := "https://api-www.mullvad.net/www/relays/all/"
	var response []struct {
		CountryCode    string `json:"country_code"`
		CityCode       string `json:"city_code"`
		Active         bool   `json:"active"`
		Owned          bool   `json:"owned"`
		Ipv4AddrIn     string `json:"ipv4_addr_in"`
		PortSpeed      int    `json:"network_port_speed"`
		Pubkey         string `json:"pubkey"`
		Type           string `json:"type"`
		StatusMessages []struct {
			Message   string    `json:"message"`
			Timestamp time.Time `json:"timestamp"`
		} `json:"status_messages"`
	}
	err = call("GET", url, "", nil, &response)
	if err != nil {
		return nil, err
	}

	relays = make(map[string][]Relay)
	for _, r := range response {
		if !r.Active || r.PortSpeed < 10 || r.Type != "wireguard" || len(r.StatusMessages) > 0 {
			continue
		}

		country := r.CountryCode
		city := fmt.Sprintf("%s-%s", country, r.CityCode)
		relay := Relay{
			CityCode: city,
			Endpoint: fmt.Sprintf("%s:51820", r.Ipv4AddrIn),
			Pubkey:   r.Pubkey,
		}
		relays[country] = append(relays[country], relay)
		relays[city] = append(relays[city], relay)
	}

	return relays, nil
}

func addPort(token string, publicKey, cityCode string) (port int, err error) {
	var payload struct {
		Pubkey   string `json:"pubkey"`
		CityCode string `json:"city_code"`
	}

	payload.Pubkey = publicKey
	payload.CityCode = cityCode
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return port, err
	}
	body := bytes.NewReader(payloadBytes)
	var response struct {
		Port int `json:"port"`
	}
	err = call("POST", "https://api.mullvad.net/www/ports/add/", token, body, &response)
	return response.Port, err
}

func removePort(token string, port int, cityCode string) error {
	var payload struct {
		Port     int    `json:"port"`
		CityCode string `json:"city_code"`
	}

	payload.Port = port
	payload.CityCode = cityCode
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	body := bytes.NewReader(payloadBytes)
	err = call("POST", "https://api.mullvad.net/www/ports/remove/", token, body, &struct{}{})
	if err == nil {
		return nil
	}

	if err == io.EOF {
		return nil
	}
	return err
}

func addPeer(token string, publicKey string) (peerAddress string, err error) {
	var payload struct {
		Pubkey string `json:"pubkey"`
	}

	payload.Pubkey = publicKey
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return peerAddress, err
	}
	body := bytes.NewReader(payloadBytes)
	var response struct {
		PeerAddress string `json:"ipv4_address"`
	}
	err = call("POST", "https://api.mullvad.net/www/wg-pubkeys/add/", token, body, &response)
	return response.PeerAddress, err
}

func removePeer(token string, publicKey string) (err error) {
	var payload struct {
		Pubkey string `json:"pubkey"`
	}

	payload.Pubkey = publicKey
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	body := bytes.NewReader(payloadBytes)

	err = call("POST", "https://api.mullvad.net/www/wg-pubkeys/revoke/", token, body, &struct{}{})
	if err == nil {
		return nil
	}

	if err == io.EOF {
		return nil
	}

	return err
}

func call[T any](method, url, token string, body io.Reader, response *T) error {
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		return err
	}
	req.Header.Set("Authority", "api.mullvad.net")
	req.Header.Set("Accept", "application/json, text/plain, */*")
	if token != "" {
		req.Header.Set("Authorization", fmt.Sprintf("Token %s", token))
	}
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	req.Header.Set("Origin", "https://mullvad.net")
	req.Header.Set("Sec-Fetch-Dest", "empty")
	req.Header.Set("Sec-Fetch-Mode", "cors")
	req.Header.Set("Sec-Fetch-Site", "same-site")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	req.Header.Set("Sec-Gpc", "1")
	req.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.54 Safari/537.36")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}

	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("failed with status code: %v", resp)
	}

	return json.NewDecoder(resp.Body).Decode(response)
}
