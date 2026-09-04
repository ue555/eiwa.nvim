package main

import (
	"context"
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
		server := agent.New(provider.Placeholder{Delay: 40 * time.Millisecond})
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
	fmt.Fprintln(os.Stderr, "Usage: eiwa-agent <serve|version>")
}
