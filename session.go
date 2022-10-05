package main

import (
	"bytes"
	"fmt"
	"io"

	"github.com/melbahja/goph"
	"github.com/pkg/sftp"
)

type Session struct {
	ssh  *goph.Client
	sftp *sftp.Client
}

func OpenSession() (Session, error) {
	callback, err := goph.DefaultKnownHosts()
	if err != nil {
		return Session{}, err
	}

	ssh, err := goph.NewConn(&goph.Config{
		User:     "root",
		Addr:     "127.0.0.1",
		Port:     1022,
		Auth:     goph.Password("password"),
		Timeout:  goph.DefaultTimeout,
		Callback: callback,
	})

	sftp, err := ssh.NewSftp()
	if err != nil {
		return Session{}, err
	}

	return Session{ssh: ssh, sftp: sftp}, err
}

func (s Session) Close() {
	err := s.sftp.Close()
	if err != nil {
		log.Infof("failed to close SFTP connection: %v", err)
	}

	err = s.ssh.Close()
	if err != nil {
		log.Infof("failed to close SSH connection: %v", err)
	}
}

func (s Session) ExecuteCommand(cmd string) (output []byte, err error) {
	log.Debugf("Executing command: %v", cmd)
	return s.ssh.Run(cmd)
}

func (s Session) WriteScriptToFile(script []byte, remotePath string) error {
	return s.writeDataToFile(bytes.NewReader(script), remotePath, true)
}

func (s Session) WriteDataToFile(data []byte, remotePath string) error {
	return s.writeDataToFile(bytes.NewReader(data), remotePath, false)
}

func (s Session) SymLink(oldPath, newPath string) error {
	_, err := s.ExecuteCommand(fmt.Sprintf("ln -sf %s %s", oldPath, newPath))
	if err != nil {
		return err
	}

	return nil
}

func (s Session) writeDataToFile(data io.Reader, remotePath string, executable bool) error {
	remote, err := s.sftp.Create(remotePath)
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

func (s Session) ExecuteCommandStream(command string, logger io.Writer) (err error) {
	session, err := s.ssh.NewSession()
	if err != nil {
		return fmt.Errorf("failed to start remote session: %v", err)
	}

	session.Stdout = logger
	session.Stderr = logger
	err = session.Run(command)
	if err != nil {
		return fmt.Errorf("failed to run command: %v", err)
	}

	return nil
}
