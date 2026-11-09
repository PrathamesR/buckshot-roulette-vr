extends Node
var itemManager
var roundManager
var perm
var cursor
var amounts
var animator_dealerHands
var animator_playerHands
var rot_hand := Vector3(0, 90, 0)
var moving := false
var removed := 0
var enabled := 0
var medicine
var sound_use_inverter
var sound_use_medicine
func RemovePlayerItemFromGrid(p): removed += 1
func EnablePermissions(): enabled += 1
func CheckAchievement_koni(): pass
func CheckAchievement_full(): pass
