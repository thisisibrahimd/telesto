package testutils

import "os/exec"

func NewRqliteCmd() *exec.Cmd {
	return exec.Command("just", "start-db")
}
