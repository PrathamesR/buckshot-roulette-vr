extends Node
class MockPerm extends Node:
	var log := []
	func SetIndicators(b): log.append("ind=" + str(b))
	func SetInteractionPermissions(b): log.append("perm=" + str(b))
	func RevertDescriptionUI(): log.append("desc")
	func SetStackInvalidIndicators(): pass
class MockCursor extends Node:
	func SetCursor(a, b): pass
class MockAmount extends RefCounted:
	var itemName := ""
	var amount_player := 3
class MockAmounts extends Node:
	var array_amounts := []
class MockPlayerData extends RefCounted:
	var stat_beerDrank := 0
	var stat_cigSmoked := 0
class MockSpawner extends Node:
	var sequenceArray: Array = ["live", "blank", "live"]
class MockRM extends Node:
	var playerData = MockPlayerData.new()
	var shellSpawner
	var playerCuffed := false
	var dealerCuffed := false
	var barrelSawedOff := false
	var currentShotgunDamage := 1
	var playerCurrentTurnItemArray: Array = []
	var cleared := 0
	var started := 0
	func ClearDeskUI(b): cleared += 1
	func StartRound(b): started += 1
class MockII extends Node:
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
	func RemovePlayerItemFromGrid(p): removed += 1
	func EnablePermissions(): enabled += 1
	func CheckAchievement_koni(): pass
	func CheckAchievement_full(): pass
class MockEject extends Node:
	var shellSpawner
	var animator
	var mesh
	var mat_brass = StandardMaterial3D.new()
	var mat_live = StandardMaterial3D.new()
	var mat_blank = StandardMaterial3D.new()
	var count := 0
	func BeerEjection_player():
		count += 1
		shellSpawner.sequenceArray.remove_at(0)
		mesh.visible = true
		animator.play("RESET")
class MockExamine extends Node:
	var shellParent
	var up := 0
	var down := 0
	func SetupShell(): up += 1; shellParent.visible = true
	func RevertShell(): down += 1; shellParent.visible = false
class MockSeg extends Node:
	var hid := 0
	func HideSegment(): hid += 1
class MockHealth extends Node:
	var calls := 0
	func UpdateDisplayRoutineCigarette_Player(): calls += 1
class MockIMgr extends RefCounted:
	var numberOfCigs_player := 2
