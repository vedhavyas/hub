package main

import "github.com/sirupsen/logrus"

type strippedFormatter struct {
	txtFmtr logrus.TextFormatter
}

func (sf *strippedFormatter) Format(entry *logrus.Entry) ([]byte, error) {
	bytes, err := sf.txtFmtr.Format(entry)
	if err != nil {
		return nil, err
	}

	return bytes[20:], nil
}
