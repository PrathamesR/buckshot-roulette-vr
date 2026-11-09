extends Node
var activeInteractionBranch
var shotgun
var intro
var itemManager
var itemInteraction
var fs_dec := false
var pressed := []
var iw := []
func InteractWith(alias):
	iw.append(str(alias))
	if str(alias) == "shotgun":
		shotgun.collider_shotgun.collision_layer = 0
		fs_dec = false
	elif str(alias) == "text dealer" or str(alias) == "text you":
		fs_dec = true
func MainInteractionEvent():
	var a := str(activeInteractionBranch.interactionAlias)
	pressed.append(a)
	if a == "shotgun" and activeInteractionBranch.interactionAllowed:
		shotgun.collider_shotgun.collision_layer = 0
		fs_dec = false
	if a == "item" and activeInteractionBranch.interactionAllowed:
		activeInteractionBranch.interactionAllowed = false
		item_presses.append(activeInteractionBranch.itemName)
		if itemInteraction != null:
			itemInteraction.moving = true
	if a == "bathroom door" or a == "backroom door":
		pass
var item_presses := []
