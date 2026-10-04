package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/ue555/eiwa.nvim/internal/agent"
	"github.com/ue555/eiwa.nvim/internal/provider"
)

var version = "0.1.0"

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	switch os.Args[1] {
	case "serve":
		flags := flag.NewFlagSet("serve", flag.ExitOnError)
		endpoint := flags.String("endpoint", env("EIWA_API_URL", "http://127.0.0.1:8000/translate"), "translation API URL")
		timeout := flags.String("timeout", env("EIWA_API_TIMEOUT", "90s"), "HTTP timeout")
		style := flags.String("style", env("EIWA_API_STYLE", "source"), "source, polite, or plain")
		glossary := flags.String("glossary", env("EIWA_API_GLOSSARY", "{}"), "JSON glossary")
		kind := flags.String("provider", "http", "http or placeholder (UI development)")
		flags.Parse(os.Args[2:])
		var translationProvider provider.Provider
		if *kind == "placeholder" {
			translationProvider = provider.Placeholder{Delay: 40 * time.Millisecond}
		} else if *kind == "http" {
			duration, err := time.ParseDuration(*timeout)
			if err != nil {
				fatal("invalid API timeout")
			}
			var terms map[string]string
			if err := json.Unmarshal([]byte(*glossary), &terms); err != nil {
				fatal("API glossary must be a JSON object with string values")
			}
			p, err := provider.NewHTTP(*endpoint, *style, terms, duration)
			if err != nil {
				fatal(err.Error())
			}
			translationProvider = p
		} else {
			fatal("provider must be http or placeholder")
		}
		server := agent.New(translationProvider)
		if err := server.Run(context.Background(), os.Stdin, os.Stdout); err != nil {
			fmt.Fprintln(os.Stderr, "eiwa-agent:", err)
			os.Exit(1)
		}
	case "version":
		fmt.Println(version)
	default:
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "Usage: eiwa-agent serve [--endpoint URL --timeout 90s --style source --glossary JSON] | version")
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func fatal(message string) {
	fmt.Fprintln(os.Stderr, "eiwa-agent:", message)
	os.Exit(2)
}
