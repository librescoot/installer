package main

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"strconv"
	"strings"
	"time"
)

type redisClient struct {
	conn   net.Conn
	reader *bufio.Reader
}

func connectRedis() (*redisClient, error) {
	conn, err := net.DialTimeout("tcp", "127.0.0.1:6379", 250*time.Millisecond)
	if err != nil {
		return nil, err
	}
	return &redisClient{conn, bufio.NewReader(conn)}, nil
}

// One connection serves the entire show; no subprocess sits on a timing path.
func (r *redisClient) Command(args ...string) (string, error) {
	var request strings.Builder
	fmt.Fprintf(&request, "*%d\r\n", len(args))
	for _, arg := range args {
		fmt.Fprintf(&request, "$%d\r\n%s\r\n", len(arg), arg)
	}
	if err := r.conn.SetDeadline(time.Now().Add(250 * time.Millisecond)); err != nil {
		return "", err
	}
	if _, err := io.WriteString(r.conn, request.String()); err != nil {
		return "", err
	}
	line, err := r.reader.ReadString('\n')
	if err != nil {
		return "", err
	}
	if len(line) < 3 || !strings.HasSuffix(line, "\r\n") {
		return "", fmt.Errorf("invalid Redis response")
	}
	value := line[1 : len(line)-2]
	switch line[0] {
	case '+', ':':
		return value, nil
	case '$':
		size, err := strconv.Atoi(value)
		if err != nil || size < -1 || size > 4096 {
			return "", fmt.Errorf("invalid Redis bulk length")
		}
		if size == -1 {
			return "", nil
		}
		data := make([]byte, size+2)
		if _, err := io.ReadFull(r.reader, data); err != nil {
			return "", err
		}
		if string(data[size:]) != "\r\n" {
			return "", fmt.Errorf("truncated Redis response")
		}
		return string(data[:size]), nil
	default:
		return "", fmt.Errorf("Redis error: %s", value)
	}
}
