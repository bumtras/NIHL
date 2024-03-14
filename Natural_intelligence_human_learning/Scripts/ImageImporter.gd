# This script is used for importing objects that can be drawn
# You can directrly copy/paste the console output of this script into objDate.gd
#Instructions
# 1. Draw a new object (you can import an image and draw over it)
# the drawing is used to get the "length" and the farthest point
# 2. Press "space"
# 3. Plase a few points on top of the drawing to create the template
# 4. Press "space"
# 5. Your object is now in the console output, do whatever you want with it


extends MainScript

var offset
var farthestPointDist
var template = []
var drawingMode = true
var addedLength


func _physics_process(_delta):
	if Input.is_action_just_pressed("mouse_click"):
		lastMousePos = get_viewport().get_mouse_position()
		addedLength = 0
		if drawingMode:
			newLine = StartNewLine(Color(1, 0, 0, 1))
		else:
			newLine= StartNewLine(Color(1, 1, 1, 1))
	
	if Input.is_action_pressed("mouse_click"):
		if drawingMode:
			mousePos = get_viewport().get_mouse_position()
			if lastMousePos != mousePos:
				DrawLine(newLine)
				addedLength += (mousePos - lastMousePos).length()
				lastMousePos = mousePos
	
	if Input.is_action_just_released("mouse_click"):
		if newLine.get_point_count() == 1 :
			if drawingMode:
				DrawPoint(newLine, mousePos)
			else :
				mousePos = get_viewport().get_mouse_position()
				DrawPoint(newLine, mousePos)
				template.append(mousePos - offset)
	
	if Input.is_action_just_pressed("ui_select"):
		if drawingMode:
			offset = FindGeometricCenter(leftMostPoint, rightMostPoint, upMostPoint, downMostPoint)
			farthestPointDist = FindFarthestPointDistance(layer, offset)
			drawingMode = false
			#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else :
			#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			#print(offset)
			print(farthestPointDist)
			print("length ", totalLength)
			#print(template)
			
			#Generate a string that can be dropped directly in objData.gd
			var output :String
			output = 'objs.append({"objName" : "CHANGE_ME", "template" : ['
			for point in template:
				output += 'Vector2(' + str(point.x) + ', ' + str(point.y) + '), '
			output = output.left(-2)
			output += '], "farthestPoint" : '
			output += str(farthestPointDist).pad_decimals(2)
			output += ', "length" : '
			output += str(totalLength).pad_decimals(2)
			output += '})'
			print(output)
			
	if Input.is_action_just_pressed("ui_undo"):
		if is_instance_valid(newLine):
			newLine.queue_free()
			totalLength -= addedLength
	

func _on_button_toggled(toggled_on):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
