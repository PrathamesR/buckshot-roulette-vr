// Buckshot Roulette VR.exe - starts the game in VR mode.
//
// It does three small things, nothing else:
//  1. checks that it sits next to "Buckshot Roulette.exe" and that the mod (vr_mod\vr_boot.gd) is there;
//  2. makes sure override.cfg exists (the file that tells the game to load the mod);
//  3. starts the game with --xr-mode on, from the game folder (override.cfg is read from the working folder).
//
// Extra arguments are passed on to the game. "--flat" starts the game without VR (the mod then stays idle).
package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

var version = "dev"

const gameExe = "Buckshot Roulette.exe"
const overrideCfg = "[autoload]\n\nVRBoot=\"*res://vr_mod/vr_boot.gd\"\n"

func main() {
	title := "Buckshot Roulette VR " + version
	self, err := os.Executable()
	if err != nil {
		showError(title, "Cannot find out where this program is: "+err.Error())
		os.Exit(1)
	}
	if real, err := filepath.EvalSymlinks(self); err == nil {
		self = real
	}
	dir := filepath.Dir(self)
	game := filepath.Join(dir, gameExe)
	if _, err := os.Stat(game); err != nil {
		showError(title, "This program must be in the game folder, next to \""+gameExe+"\".\n\n"+
			"Steam: right-click the game > Manage > Browse local files, then extract the whole zip there.\n\nLooked in: "+dir)
		os.Exit(1)
	}
	if _, err := os.Stat(filepath.Join(dir, "vr_mod", "vr_boot.gd")); err != nil {
		showError(title, "The \"vr_mod\" folder is missing next to this program.\n\nExtract the WHOLE zip into the game folder (the folder that holds \""+gameExe+"\").")
		os.Exit(1)
	}
	cfg := filepath.Join(dir, "override.cfg")
	if data, err := os.ReadFile(cfg); err != nil {
		if err := os.WriteFile(cfg, []byte(overrideCfg), 0o644); err != nil {
			showError(title, "Cannot create override.cfg in the game folder: "+err.Error())
			os.Exit(1)
		}
	} else if !strings.Contains(string(data), "vr_mod/vr_boot.gd") {
		showError(title, "There is an override.cfg in the game folder that does not load the VR mod (maybe from another mod).\n\n"+
			"Rename it, or add these lines to it:\n\n[autoload]\nVRBoot=\"*res://vr_mod/vr_boot.gd\"")
		os.Exit(1)
	}
	args := []string{}
	flat, hasXR := false, false
	for _, a := range os.Args[1:] {
		switch a {
		case "--flat":
			flat = true
		case "--xr-mode":
			hasXR = true
			args = append(args, a)
		default:
			args = append(args, a)
		}
	}
	if !flat && !hasXR {
		args = append([]string{"--xr-mode", "on"}, args...)
	}
	cmd := exec.Command(game, args...)
	cmd.Dir = dir
	if err := cmd.Start(); err != nil {
		showError(title, "Could not start the game: "+err.Error())
		os.Exit(1)
	}
}
