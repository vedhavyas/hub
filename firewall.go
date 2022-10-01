package hub

type Firewall struct {
	session *Session
	rules   []string
}

func (f *Firewall) getEth0Inf() (string, error) {
	out, err := f.session.ExecuteCommand(
		"ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}'")
	return string(out), err
}

func (f *Firewall) addRule(rule string) {
	f.rules = append(f.rules, rule)
}
