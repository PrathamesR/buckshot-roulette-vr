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
var dealerIntelligence
var sound_use_inverter
var sound_use_medicine
func RemovePlayerItemFromGrid(p): removed += 1
func EnablePermissions(): enabled += 1
func CheckAchievement_koni(): pass
func CheckAchievement_full(): pass
var stealing := false
var stealing_fs := false
var temp_itemParent
var items
var hands
var camera
var pos_hand := Vector3(1, 1, 1)
var pos_hand_main := Vector3(2, 2, 2)
var rot_hand_main := Vector3(0, 45, 0)
var sound_use_burnerphone
var sound_use_adrenaline
var hit_count := 0
func AdrenalineHit(): hit_count += 1
