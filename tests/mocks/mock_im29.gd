extends Node
var interaction_intake
var activeItem
var moving := false
var numberOfOccupiedGrids := 0
var gridParentArray: Array = []
var gridOccupiedArray: Array = [false, false, false, false, false, false, false, false]
var activeItem_offset_pos := Vector3(0, 0.3, 0)
var itemSpawnParent
var rot_next := Vector3(0, 90, 0)
var placed := []
var items_dynamicInteractionArray: Array = []
func GrabItem():
	var it := Node3D.new()
	itemSpawnParent.add_child(it)
	it.transform.origin = Vector3(-1.0, 0.5, -3.0)
	activeItem = it
	interaction_intake.interactionAllowed = false
	moving = true
func PlaceDownItem(i: int):
	placed.append(i)
	gridOccupiedArray[i] = true
	numberOfOccupiedGrids += 1
	moving = true
	interaction_intake.interactionAllowed = true
var itemArray_instances_dealer: Array = []
var steal_calls := 0
func SetupItemSteal(): steal_calls += 1
var counter_calls := []
var revert_calls := 0
func Counter(b): counter_calls.append(b)
func RevertItemSteal(): revert_calls += 1
