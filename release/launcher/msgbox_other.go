//go:build !windows

package main

import (
	"fmt"
	"os"
)

// showError prints to stderr (only used when testing the launcher on a non-Windows machine).
func showError(title, text string) { fmt.Fprintln(os.Stderr, title+": "+text) }
