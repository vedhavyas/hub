package main

import (
	"fmt"
	"io"
	"os"
	"time"

	"github.com/melbahja/goph"
)

type Session struct {
	client *goph.Client
}

func OpenSession() (*Session, error) {
	callback, err := goph.DefaultKnownHosts()
	if err != nil {
		return nil, err
	}

	client, err := goph.NewConn(&goph.Config{
		User:     "root",
		Addr:     "127.0.0.1",
		Port:     1022,
		Auth:     goph.Password("password"),
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

func (s *Session) CopyLocalFile(localPath, remotePath string, executable bool) error {
	local, err := os.Open(localPath)
	if err != nil {
		return fmt.Errorf("failed to open local file: %v", err)
	}
	defer local.Close()

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

	_, err = io.Copy(remote, local)
	if err != nil {
		return fmt.Errorf("failed to copy to remote: %v", err)
	}

	permissions := os.FileMode(0774)
	if executable {
		permissions = 0775
	}
	err = remote.Chmod(permissions)
	if err != nil {
		return fmt.Errorf("failed to set permisssions: %v", err)
	}

	return nil
}

func (s *Session) ExecuteLocalShellFile(localPath string, logger io.Writer) error {
	remotePath := fmt.Sprintf("/tmp/hub-script-%d.sh", time.Now().UTC().UnixMilli())
	err := s.CopyLocalFile(localPath, remotePath, true)
	if err != nil {
		return fmt.Errorf("failed to copy script: %v", err)
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
