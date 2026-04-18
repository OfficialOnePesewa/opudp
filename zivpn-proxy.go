package main

import (
	"encoding/json"
	"flag"
	"io"
	"log"
	"net"
	"os"
	"strings"
)

// Binding maps a password to an allowed device ID
type Binding struct {
	Password string `json:"password"`
	DeviceID string `json:"device_id"`
}

var bindings map[string]Binding

// loadBindings reads the bindings from a JSON file
func loadBindings(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, &bindings)
}

func main() {
	listenAddr := flag.String("listen", ":5667", "Proxy listen address")
	backendAddr := flag.String("backend", ":5668", "Backend ZIVPN address")
	bindingsFile := flag.String("bindings", "/etc/zivpn/bindings.json", "Path to bindings JSON file")
	flag.Parse()

	// Load device bindings
	err := loadBindings(*bindingsFile)
	if err != nil {
		log.Fatalf("Failed to load bindings: %v", err)
	}
	log.Printf("Loaded %d device binding(s)", len(bindings))

	// Start UDP listener
	ln, err := net.ListenPacket("udp", *listenAddr)
	if err != nil {
		log.Fatal(err)
	}
	defer ln.Close()
	log.Printf("Proxy listening on %s, forwarding to %s", *listenAddr, *backendAddr)

	for {
		handleConnection(ln, *backendAddr)
	}
}

func handleConnection(ln net.PacketConn, backendAddr string) {
	buf := make([]byte, 2048)
	n, clientAddr, err := ln.ReadFrom(buf)
	if err != nil {
		log.Printf("Read error: %v", err)
		return
	}

	// The first packet from the ZIVPN app contains the password and device ID.
	// Format (simplified): the handshake data includes "password:deviceID"
	data := buf[:n]
	parts := strings.Split(string(data), ":")
	if len(parts) < 2 {
		log.Printf("Invalid handshake from %v (no device ID)", clientAddr)
		return
	}
	password := parts[0]
	deviceID := parts[1]

	// Check if the password exists and is bound to this device ID
	binding, exists := bindings[password]
	if !exists || binding.DeviceID != deviceID {
		log.Printf("REJECTED: password=%s device=%s from %v", password, deviceID, clientAddr)
		return
	}
	log.Printf("ALLOWED: password=%s device=%s from %v", password, deviceID, clientAddr)

	// Establish connection to the real ZIVPN server (localhost:5668)
	backendConn, err := net.Dial("udp", backendAddr)
	if err != nil {
		log.Printf("Backend dial error: %v", err)
		return
	}
	defer backendConn.Close()

	// Forward the initial packet to ZIVPN
	_, err = backendConn.Write(data)
	if err != nil {
		log.Printf("Backend write error: %v", err)
		return
	}

	// Start a goroutine to relay responses from ZIVPN back to the client
	go func() {
		_, _ = io.Copy(ln.(net.PacketConn), backendConn)
	}()

	// Relay subsequent packets from the client to ZIVPN
	_, _ = io.Copy(backendConn, ln.(net.PacketConn))
}
