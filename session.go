package hub

import (
	"fmt"
	"io"
	"os"

	"github.com/melbahja/goph"
)

type Remote struct {
	Addr   string `toml:"addr"`
	Port   uint   `toml:"port"`
	User   string `toml:"user"`
	Passwd string `toml:"passwd"`
}

type Session struct {
	client *goph.Client
}

func OpenSession(remote Remote) (*Session, error) {
	callback, err := goph.DefaultKnownHosts()
	if err != nil {
		return nil, err
	}

	client, err := goph.NewConn(&goph.Config{
		User:     remote.User,
		Addr:     remote.Addr,
		Port:     remote.Port,
		Auth:     goph.Password(remote.Passwd),
		Timeout:  goph.DefaultTimeout,
		Callback: callback,
	})

	return &Session{client: client}, nil
}

func (s *Session) ExecuteCommand(cmd string) (output []byte, err error) {
	return s.client.Run(cmd)
}

func (s *Session) WriteScriptToFile(script []byte, remotePath string) error {
	return s.writeDataToFile(script, remotePath, true)
}

func (s *Session) WriteDataToFile(data []byte, remotePath string) error {
	return s.writeDataToFile(data, remotePath, false)
}

func (s *Session) writeDataToFile(data []byte, remotePath string, executable bool) error {
	ftp, err := s.client.NewSftp()
	if err != nil {
		return fmt.Errorf("failed to open sftp client: %v", err)
	}
	defer ftp.Close()

	remote, err := ftp.Create(remotePath)
	if err != nil {
		return fmt.Errorf("failed to create file on remote: %v", err)
	}
	defer remote.Close()

	_, err = remote.Write(data)
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

func (s *Session) ExecuteLocalShellFile(localPath string, logger io.Writer) (err error) {
	local, err := os.Open(localPath)
	if err != nil {
		return fmt.Errorf("failed to open local file: %v", err)
	}
	defer local.Close()

	localStat, err := local.Stat()
	if err != nil {
		return fmt.Errorf("failed to get file stat: %v", err)
	}

	ftp, err := s.client.NewSftp()
	if err != nil {
		return fmt.Errorf("failed to open sftp client: %v", err)
	}
	defer ftp.Close()

	remotePath := fmt.Sprintf("/tmp/%s", localStat.Name())
	remote, err := ftp.Create(remotePath)
	if err != nil {
		return fmt.Errorf("failed to create file on remote: %v", err)
	}
	defer ftp.Remove(remotePath)
	defer remote.Close()

	_, err = io.Copy(remote, local)
	if err != nil {
		return fmt.Errorf("failed to copy to remote: %v", err)
	}

	err = remote.Chmod(0775)
	if err != nil {
		return fmt.Errorf("failed to set permisssions: %v", err)
	}

	return s.ExecuteRemoteShellFile(remotePath, logger)
}

func (s *Session) ExecuteRemoteShellFile(remotePath string, logger io.Writer) (err error) {
	session, err := s.client.NewSession()
	if err != nil {
		return fmt.Errorf("failed to start remote session: %v", err)
	}

	session.Stdout = logger
	session.Stderr = logger
	err = session.Run(fmt.Sprintf("`which sh` %s", remotePath))
	if err != nil {
		return fmt.Errorf("failed to run script: %v", err)
	}

	return nil
}
