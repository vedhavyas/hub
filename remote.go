package main

import (
	"bytes"
	_ "embed"
	"fmt"
	"io"
	"net"
	"os"

	"github.com/BurntSushi/toml"
	"github.com/melbahja/goph"
	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
)

type Remote struct {
	ssh  *goph.Client
	sftp *sftp.Client
}

type Connection struct {
	User     string `toml:"user"`
	Addr     string `toml:"addr"`
	Port     uint   `toml:"port"`
	Password string `toml:"passwd"`
	KeyPath  string `toml:"key_path"`
}

//go:embed config.toml
var configBytes string

type Config struct {
	Hub     Connection `toml:"hub"`
	Gateway Connection `toml:"gateway"`
}

func LoadConfig() (Config, error) {
	var config Config
	log.Infoln("Loading config...")
	log.Debugf("Config data: %v", configBytes)
	_, err := toml.Decode(configBytes, &config)
	if err != nil {
		return config, fmt.Errorf("failed to load config: %v", err)
	}

	return config, nil
}

func (conn Connection) Auth() (goph.Auth, error) {
	if conn.Password != "" {
		log.Infof("Using password authentication...")
		return goph.Password(conn.Password), nil
	}

	if conn.KeyPath != "" {
		log.Infof("Using private key authentication...")
		return goph.Key(conn.KeyPath, "")
	}

	log.Infof("Using SSH agent...")
	return goph.UseAgent()
}

func ConnectToRemote(conn Connection) (Remote, error) {
	auth, err := conn.Auth()
	if err != nil {
		return Remote{}, err
	}

	ssh, err := goph.NewConn(&goph.Config{
		User:    conn.User,
		Addr:    conn.Addr,
		Port:    conn.Port,
		Auth:    auth,
		Timeout: goph.DefaultTimeout,
		Callback: func(hostname string, remote net.Addr, key ssh.PublicKey) error {
			log.Infof("Checking host %s at %s with key: %v", hostname, remote.String(), key.Type())
			return nil
		},
	})
	if err != nil {
		return Remote{}, err
	}

	sftp, err := ssh.NewSftp()
	if err != nil {
		return Remote{}, err
	}

	return Remote{ssh: ssh, sftp: sftp}, err
}

func (r Remote) Close() {
	if r.sftp != nil {
		err := r.sftp.Close()
		if err != nil {
			log.Infof("failed to close SFTP connection: %v", err)
		}
	}

	if r.ssh != nil {
		err := r.ssh.Close()
		if err != nil {
			log.Infof("failed to close SSH connection: %v", err)
		}
	}
}

func (r Remote) ExecuteCommand(cmd string) (output []byte, err error) {
	log.Debugf("Executing command: %v", cmd)
	return r.ssh.Run(cmd)
}

func (r Remote) WriteScriptToFile(script []byte, remotePath string) error {
	return r.writeDataToFile(bytes.NewReader(script), remotePath, true)
}

func (r Remote) WriteDataToFile(data []byte, remotePath string) error {
	return r.writeDataToFile(bytes.NewReader(data), remotePath, false)
}

func (r Remote) SymLink(oldPath, newPath string) error {
	res, err := r.ExecuteCommand(fmt.Sprintf("ln -sf %s %s", oldPath, newPath))
	if err != nil {
		return fmt.Errorf("%v: %s", err, res)
	}

	return nil
}

func (r Remote) writeDataToFile(data io.Reader, remotePath string, executable bool) error {
	remote, err := r.sftp.Create(remotePath)
	if err != nil {
		return fmt.Errorf("failed to create file on remote: %v", err)
	}
	defer remote.Close()

	_, err = remote.ReadFrom(data)
	if err != nil {
		return fmt.Errorf("failed to write data to file: %v", err)
	}

	if executable {
		err = remote.Chmod(0775)
		if err != nil {
			return fmt.Errorf("failed to set permisssions: %v", err)
		}

	}

	return nil
}

func (r Remote) newTTYSession(stdOut, stdError io.Writer) (*ssh.Session, error) {
	modes := ssh.TerminalModes{
		ssh.ECHO:  0, // disable echoing
		ssh.IGNCR: 1,
	}
	session, err := r.ssh.NewSession()
	if err != nil {
		return nil, fmt.Errorf("failed to start remote session: %v", err)
	}

	err = session.RequestPty("xterm-256color", 40, 80, modes)
	if err != nil {
		return nil, err
	}

	out, err := session.StdoutPipe()
	if err != nil {
		return nil, err
	}
	go io.Copy(stdOut, out)

	stdErr, err := session.StderrPipe()
	if err != nil {
		return nil, err
	}
	go io.Copy(stdError, stdErr)

	in, err := session.StdinPipe()
	if err != nil {
		return nil, err
	}
	go io.Copy(in, os.Stdin)
	return session, nil
}

func (r Remote) ExecuteCommandStream(cmd string, logger io.Writer) (err error) {
	log.Debugf("Executing cmd: %v", cmd)
	session, err := r.newTTYSession(logger, logger)
	if err != nil {
		return fmt.Errorf("failed to open pty session: %v", err)
	}

	err = session.Run(cmd)
	if err != nil {
		return fmt.Errorf("failed to run command: %v", err)
	}

	return nil
}

func (r Remote) OpenShell(shell string) (err error) {
	session, err := r.newTTYSession(os.Stdout, os.Stderr)
	if err != nil {
		return fmt.Errorf("failed to open pty session: %v", err)
	}

	err = session.Run(shell)
	if err != nil {
		return fmt.Errorf("failed to run command: %v", err)
	}

	return nil
}
