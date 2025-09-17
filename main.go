package main

import (
	"bufio"
	"log"
	"net/url"
	"os/exec"
	"regexp"
	"runtime"
	"strings"
	"sync"
	"time"

	"go.bug.st/serial"
)

const (
	appName = "serial-url-scanner"
	version = "1.0.0"
)

var (
	urlRegex = regexp.MustCompile(`https?://[^\s<>"']+`)
)

func main() {
	log.Printf("%s v%s starting...\n", appName, version)

	// Start monitoring serial ports for scan events
    go watchdogMonitor()

	// Block forever
	select {}
}

func monitorSerialPorts() {
	log.Printf("Monitoring serial ports for scan events...\n")

	// Get list of available serial ports
	ports, err := serial.GetPortsList()
	if err != nil {
		log.Printf("Error listing serial ports: %v", err)
		return
	}

	if len(ports) == 0 {
		log.Printf("No serial ports found")
		return
	}

	var wg sync.WaitGroup

	// Monitor each port in a separate goroutine
	for _, portName := range ports {
		wg.Add(1)
		go func(port string) {
			defer wg.Done()
			monitorSerialPort(port)
		}(portName)
	}

	wg.Wait()
}

// watchdogMonitor continuously restarts serial port monitoring if it exits
// due to errors, no ports being available, or readers finishing.
func watchdogMonitor() {
    for {
        monitorSerialPorts()
        log.Printf("Serial monitoring exited; restarting in 5s...\n")
        time.Sleep(5 * time.Second)
    }
}

func monitorSerialPort(portName string) {
	log.Printf("Starting monitor on port: %s", portName)

	// Configure serial port
	mode := &serial.Mode{
		BaudRate: 9600,
		Parity:   serial.NoParity,
		DataBits: 8,
		StopBits: serial.OneStopBit,
	}

	// Open the serial port
	port, err := serial.Open(portName, mode)
	if err != nil {
		log.Printf("Error opening port %s: %v", portName, err)
		return
	}
	defer port.Close()

	// Set read timeout
	port.SetReadTimeout(time.Second * 5)

	scanner := bufio.NewScanner(port)

	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) != "" {
			log.Printf("Scan event from %s: %s", portName, line)
			processScannedLine(line)
		}
	}

	if err := scanner.Err(); err != nil {
		log.Printf("Error reading from port %s: %v", portName, err)
	}
}

func clean(line string) string {
	// Minimal normalization for scanner prefixes/suffixes
	line = strings.TrimSpace(line)

	if len(line) >= 3 && line[0:3] == "\ufeff" {
		line = line[3:]
	}

	for _, prefix := range []string{"URL:", "SCAN:", "CODE:", "DATA:"} {
		if strings.HasPrefix(strings.ToUpper(line), prefix) {
			line = strings.TrimSpace(line[len(prefix):])
			break
		}
	}

	return strings.TrimRight(line, "\r\n\t ")
}

func processScannedLine(line string) {
	log.Printf("Processing scanned line: %s\n", line)
	line = strings.TrimSpace(line)
	if line == "" {
		return
	}

	// Normalize similar to serial input cleaning
	line = clean(line)

	// Case 1: explicit localhost prefix
	if strings.HasPrefix(line, "http://localhost") {
		if isValidURL(line) {
			openURL(line)
		}
		return
	}

	// Case 2: contains carbon.ms anywhere in the line
	if strings.Contains(strings.ToLower(line), "carbon.ms") {
		// Prefer explicit URLs first
		matches := urlRegex.FindAllString(line, -1)
		opened := false
		for _, u := range matches {
			if strings.Contains(strings.ToLower(u), "carbon.ms") {
				if isValidURL(u) {
					openURL(u)
					opened = true
				}
			}
		}

		if opened {
			return
		}

		// Fallback: build an https:// URL around the carbon.ms domain/path if no scheme present
		carbonRe := regexp.MustCompile(`([A-Za-z0-9\-\._]*carbon\.ms[^\s<>"']*)`)
		if m := carbonRe.FindStringSubmatch(line); len(m) > 0 {
			candidate := m[1]
			if !strings.HasPrefix(candidate, "http://") && !strings.HasPrefix(candidate, "https://") {
				candidate = "https://" + candidate
			}
			if isValidURL(candidate) {
				openURL(candidate)
			}
		}
	}
}

func isValidURL(str string) bool {
	u, err := url.Parse(str)
	if err != nil {
		return false
	}
	return u.Scheme != "" && u.Host != ""
}

func openURL(url string) {
	var cmd *exec.Cmd

	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	case "darwin":
		cmd = exec.Command("open", url)
	case "linux":
		cmd = exec.Command("xdg-open", url)
	default:
		log.Printf("Unsupported platform: %s\n", runtime.GOOS)
		return
	}

	if err := cmd.Start(); err != nil {
		log.Printf("Failed to open URL %s: %v\n", url, err)
	}
}