# Brief explanation of the script
# This script does the drawing and rates the the thing that has been drawed
# The drawing part is easy - it just adds a point to e Line2d every physics step (not frame)
# To give a propper score, the script comares the drawing to something that a call "template"
# useing the method CheckTemplate()
# The template is just a few points from the reference image
# The player gets a point for placing a point within "treshold" distance from a point in the template
# To prevent the player from cheating by placing just a few points, the script also takes into a count
# the total length of each Line2d
# The template is also being rotated to allow the player to draw the object in whatever orientation

# Currently alot of optimisations can be done, but the script runs fine as it is and the evaluation is
# done only once in a while (when the player finish drawing)

# I swear the code looked fine until the last 2 days of the jam when I had to speedrun everything


extends Node2D
class_name MainScript

signal pauseSignal(animName)
signal dialogSignal(animName)
signal imagesSignal(animName)
signal mainMenuSignal(animName)
#signal DoneButtone(animName)

var canvas :Node2D  #The canvas is the parent of the layers
var layer :Node2D  #Each drawing is drawn on a new layer (if I get this far)
var dialogBox :RichTextLabel
var taskBox :RichTextLabel
var scoreBox :RichTextLabel
var loadingText :RichTextLabel
var scoreGain :RichTextLabel
var delayTimer :Timer  #Used to add some delay, check the timeout signal
var scoreTimer :Timer
var passSound :AudioStreamPlayer
var failSound :AudioStreamPlayer
var newLine :Line2D
var mousePos :Vector2
var lastMousePos :Vector2
@export var lineWidth = 10
@export var color1 :Color
@export var color2 :Color
var actionRe
var drawingEnabled = false  #Diasables drawing
var isPlaying = false  #Controls the pause menu
var inDialog = false  #Controls the previous two
var tutorialMode = false
var failFlag = false  #Described in TutorialDialog()
var gameOver = false
#Those are used to determine the edges of the drawing
#The edges are used to determine the center of the drawing
#And you need the center so you can compare the drawing with the template
var leftMostPoint = 0
var rightMostPoint = 0
var upMostPoint = 0
var downMostPoint = 0

#All images are stored in objDate.gd
#objDta.gd is a global script that can be accessed by any other script as "objects"
var img :int
var imageToDraw :Array
var threshold = lineWidth * 3  #maybe I should have named it acceptable aberration 🥁
var totalLength = 0
var taskCounter = 0
var dialogID = 0
var score =0
var totalScore = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	$Song1.play()
	canvas = $Canvas
	dialogBox = $DialogBuble/Dialog
	taskBox = $Task
	scoreBox = $Score
	loadingText = $"Please wait"
	scoreGain = $PlusScore
	delayTimer = $"Please wait/Timer"
	scoreTimer = $PlusScore/ScoreTimer
	passSound = $Pass
	failSound = $Fail

func _physics_process(_delta):
	# A new line is added when the player presses the mouse buttone
	if Input.is_action_just_pressed("mouse_click"):
		if drawingEnabled:
			lastMousePos = get_viewport().get_mouse_position()
			if IsMouseOnCanvas(lastMousePos):
				newLine = StartNewLine(color1)
		
		if inDialog:
			if !tutorialMode:
				dialogSignal.emit("dialog_end")
				taskBox.visible = true
				inDialog = false
				drawingEnabled = true
				isPlaying = true
			else:
				TutorialDialog()
		elif gameOver:
			GoToMainMenu()
	
	# This is the part that does the actual drawing
	if Input.is_action_pressed("mouse_click") && drawingEnabled:
		mousePos = get_viewport().get_mouse_position()
		if lastMousePos != mousePos && IsMouseOnCanvas(mousePos):
			DrawLine(newLine)
			lastMousePos = mousePos
			
	
	# This draws a single dot
	if Input.is_action_just_released("mouse_click") && drawingEnabled && IsMouseOnCanvas(mousePos):
		if newLine.get_point_count() == 1 :
			DrawPoint(newLine, mousePos)
	


func _process(_delta):
	# Currently used for debuging
	if Input.is_action_just_pressed("ui_select") && drawingEnabled:
		drawingEnabled = false
		loadingText.visible = true
		delayTimer.start()
		
	# Opens the pause menu and stops the drawing
	if Input.is_action_just_pressed("ui_cancel") && isPlaying:
		if drawingEnabled:
			drawingEnabled = false
			pauseSignal.emit("move_in")
		else:
			drawingEnabled = true
			pauseSignal.emit("move_out")
	
	if Input.is_anything_pressed():
		pass


func IsMouseOnCanvas(mPos :Vector2):
	return(mPos.x > 654 && mPos.y > 66 && mPos.x < 1853 && mPos.y < 916)


# Appends new line2d to the layer
func StartNewLine(col :Color):
	var nLine = Line2D.new()
	nLine.default_color = col
	nLine.width = lineWidth
	nLine.add_point(lastMousePos)
	CheckDrawingEdge(lastMousePos)  #Have to execute with every new point
	layer.add_child(nLine)
	print(lastMousePos)
	return nLine


# Adds new point to the line and increments the total length
func DrawLine(nLine :Line2D):
	totalLength += (mousePos - lastMousePos).length()
	nLine.add_point(mousePos)
	CheckDrawingEdge(mousePos)  #Have to execute with every new point
	print(mousePos)


# The is the fathest from the center of the drawing
# Used to scale up/down the template to match the drawing
func FindFarthestPointDistance(drawing :Node2D, gCenter :Vector2):
	var farthestPointDist = 0
	var lines = drawing.get_children()
	for line in lines:
		for linePoint in line.get_point_count():
			if (line.get_point_position(linePoint) - gCenter).length() > farthestPointDist :
				farthestPointDist = (line.get_point_position(linePoint) - gCenter).length()
	print("FP ", farthestPointDist)
	return farthestPointDist


# This is where the magic happens 
func CheckTemplate(drawing :Node2D, template :Array, thresh, tLength):  #tresh = threshold
	var offset = FindGeometricCenter(leftMostPoint, rightMostPoint, upMostPoint, downMostPoint)  #Thoes are global variables, I dont care if it's a bad practice, I can't be bothered rn
	var scaleFactor = FindFarthestPointDistance(drawing, offset) / objects.objs[img]["farthestPoint"]
	print(scaleFactor)
	#Creates a scled up template (testPoints) and place it on top of the drawing
	var testPoints :Array
	for point in template:
		testPoints.append(point * scaleFactor + offset)
	# The threshold is also being scaled so you have bigger room for error on big drawings
	# and vice versa
	var scaledThreshold = thresh * sqrt(scaleFactor)
	print("TH ", scaledThreshold)
	# And now the real magic begins
	var lines = drawing.get_children()
	var eval = 0  #Evaluation of the drawing, gets incremented with every match
	var maxEval = 0  #The greatest evaluation of all angles
	var breakFlag = false  #Flag to break the loop when a match is found
	# Rotates the template and compares it to every point of the drawwing
	var angle = 0
	while angle < 360:  #This whole loop is horible
		testPoints = RotateTemplate(testPoints, 10 / scaleFactor, offset) #you can either increment the degree with each loop or pass the same template over and over
		angle += (10 / scaleFactor)
		for point in testPoints:
			'''
			#debug
			var newPoint = Line2D.new()
			DrawPoint(newPoint, point)
			drawing.add_child(newPoint)
			#debugn't
			'''
			for line in lines:
				for linePoint in line.get_point_count():
					if (line.get_point_position(linePoint) - point).length() < scaledThreshold :
						print("test", line.get_point_position(linePoint) - point, point)
						print("to4ka", line.get_point_position(linePoint))
						eval += 1
						breakFlag = true
						break
				if breakFlag:
					breakFlag = false
					break  #Go to the next point of thee template
		
		# eval is turned from number of matched points to actual score value
		@warning_ignore("integer_division")
		eval *= 100 / template.size() 
		eval -= abs(((tLength - (objects.objs[img]["length"] * scaleFactor)) / (objects.objs[img]["length"] * scaleFactor)) * 100)
		if eval > maxEval: maxEval = eval
		eval = 0
	
	return maxEval


# Rotates the template
# step 1 - remove offset
# step 2 - move each point on x and y axies a little
# step 3 - bring the offset back
# step 4 - proffit
func RotateTemplate(template :Array, deg :int, offset = Vector2.ZERO):
	var templRotated = []  #Creates a new template
	for point in template:
		var angle = rad_to_deg((point - offset).angle()) + deg  #gets the angle of the Vector2 of each point and adds the angle to be rotated with
		#Some trigonometry
		#If you don't get, watch some videos about sin and cos or smthng idk
		var hypotenuse = (point - offset).length()
		var x = hypotenuse * cos(deg_to_rad(angle))
		var y = hypotenuse * sin(deg_to_rad(angle))
		templRotated.append(Vector2(x, y) + offset)
	return templRotated


# Keeps track of the edge of the drawing
# (booring stuff)
func CheckDrawingEdge(pointPos :Vector2):
	if pointPos.x < leftMostPoint: leftMostPoint = pointPos.x
	if pointPos.x > rightMostPoint: rightMostPoint = pointPos.x
	if pointPos.y < upMostPoint: upMostPoint = pointPos.y
	if pointPos.y > downMostPoint: downMostPoint = pointPos.y


func ResetDrawingEdge():
	rightMostPoint = 0
	downMostPoint = 0
	leftMostPoint = get_viewport().get_visible_rect().size.x
	upMostPoint = get_viewport().get_visible_rect().size.y


# Ah yes
# math
# I am not sure if this is the actual geometric center, but it does the job
func FindGeometricCenter(left :int, right :int, up :int, down :int):
	@warning_ignore("integer_division")
	var x = (left + right) / 2
	@warning_ignore("integer_division")
	var y = (up + down) / 2
	return(Vector2(x, y))


# Draws a point (on the drawing) by adding points (to the Line2D) a little bit to the left
# and to the right of the mouse click position
# Does NOT add lenght to the drawing
func DrawPoint(line :Line2D, pointCord :Vector2):
	@warning_ignore("integer_division")
	line.add_point(pointCord + Vector2(lineWidth / 2, 0))
	@warning_ignore("integer_division")
	line.add_point(pointCord - Vector2(lineWidth / 2, 0))


func TutorialDialog():
	if failFlag:
		failFlag = false  #Skip you have been there already
		dialogID -= 2
		dialogBox.text = "Try again but put more effort into it!"
		#dialogSignal.emit("dialog_start")
		
	elif objects.dialogs[dialogID]["text"]:
		if objects.dialogs[dialogID]["text"] == "quit":
			GoToMainMenu()
			gameOver = true
			dialogID = 0
		else:
			dialogBox.text = objects.dialogs[dialogID]["text"]
		
	else:
		failFlag = false
		inDialog = false
		isPlaying = true
		taskBox.visible = true
		dialogSignal.emit("dialog_end")
	
	dialogID +=1


func GiveTask(random):
	if random:
		img = randi_range(0, objects.objs.size() - 1)
	elif !failFlag:
		img += 1
	
	taskCounter +=1
	
	imageToDraw = objects.objs[img]["template"] #debug
	print(objects.objs[img]["objName"])
	
	if !tutorialMode:
		dialogBox.text = "Let me give you a task!\n Draw a " + objects.objs[img]["objName"] + "."
	else:
		inDialog = true
		drawingEnabled = false
		TutorialDialog()
	
	taskBox.text = "Task: Add a " + objects.objs[img]["objName"] + ". "
	if !tutorialMode:
		taskBox.text += str(taskCounter) + "/10"

func ChangeTask():
	if taskCounter == 10:
		GameOver()
	else:
		for line in layer.get_children():
			line.default_color = color2
		layer = Node2D.new()
		canvas.add_child(layer)
		GiveTask(!tutorialMode)
		ResetDrawingEdge()
		totalLength = 0
		if !tutorialMode:
			drawingEnabled = true


func GameOver():
	inDialog = true
	gameOver = true
	dialogSignal.emit("dialog_start")
	#DoneButtone.emit("move_out")
	imagesSignal.emit("move_out")
	dialogBox.text = "Good job!\n SCORE: " + str(totalScore).pad_decimals(0)


func GoToMainMenu():
	#tutorialMode = false
	isPlaying = false
	drawingEnabled = false
	
	taskBox.visible = false
	scoreBox.visible = false
	
	for layr in canvas.get_children():
		layr.queue_free()
	
	if inDialog:
		dialogSignal.emit("dialog_end")


func  StartGame():
	isPlaying = true
	inDialog = true
	gameOver = false
	
	ResetDrawingEdge()
	dialogID = 0
	totalLength = 0
	taskCounter = 0
	totalScore = 0
	scoreBox.text = "SCORE: " + str(totalScore)
	scoreBox.visible = true
	
	layer = Node2D.new()
	canvas.add_child(layer)
	
	newLine = Line2D.new()
	
	GiveTask(!tutorialMode)
	taskBox.text = "Task: Draw a " + objects.objs[img]["objName"] + "."


func _on_check_button_toggled(toggled_on):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_exit_pressed():
	get_tree().quit()


func _on_play_pressed():
	tutorialMode = false
	StartGame()
	

func _on_tutorial_pressed():
	tutorialMode = true
	img = -1
	StartGame()


func _on_resume_pressed():
	drawingEnabled = true


func _on_robot_animation_finished(anim_name):
	if anim_name == "move_out":
		dialogSignal.emit("dialog_start")
	elif anim_name == "dialog_end":
		if gameOver:
			mainMenuSignal.emit("move_in")
		else:
			drawingEnabled = true
			imagesSignal.emit("move_in")
	elif anim_name == "move_in":
		imagesSignal.emit("move_out")


func _on_main_menu_pressed():
	GoToMainMenu()

func _on_done_pressed():
	if drawingEnabled:
		drawingEnabled = false
		loadingText.visible = true
		delayTimer.start()
		if tutorialMode:
			dialogSignal.emit("dialog_start")


# Adds delay to be able to display the "Please wait" text
func _on_timer_timeout():
	score = CheckTemplate(layer, imageToDraw, threshold, totalLength)
	print("score", score)
	print("length ", totalLength)
	if score < 10:
		failSound.play()
		if tutorialMode:
			failFlag = true
	else:
		passSound.play()
	totalScore += score
	scoreBox.text = "SCORE: " + str(totalScore).pad_decimals(0)
	scoreGain.text = "SCORE +" + str(score).pad_decimals(0)
	scoreGain.visible = true
	scoreTimer.start()
	ChangeTask()
	loadingText.visible = false


func _on_score_timer_timeout():
	scoreGain.visible = false


#Calculates the center of the drawing
#DOES NOT WORK FOR MY USE CASE
#The drawing is made out of lines, the lines are made out of points
'''
func GetDrawingCenter(drawing :Node2D):
	var centerPoitn = Vector2(0, 0)
	var totalPointCount = 0
	var lines = drawing.get_children()
	for line in lines:
		var linePoints = line.get_point_count()
		totalPointCount += linePoints
		for linePoint in linePoints:
			centerPoitn += line.get_point_position(linePoint)
			
	centerPoitn = centerPoitn / totalPointCount
	#debug
	print("center: ", centerPoitn)
	print("geometric center", FindGeometricCenter(leftMostPoint, rightMostPoint, upMostPoint, downMostPoint))
	print(leftMostPoint, " ", rightMostPoint)
	print(upMostPoint, " ", downMostPoint)
	newLine = Line2D.new()
	newLine.add_point(Vector2(leftMostPoint, 0))
	newLine.add_point(Vector2(leftMostPoint, 1000))
	layer.add_child(newLine)
	newLine = Line2D.new()
	newLine.add_point(Vector2(rightMostPoint, 0))
	newLine.add_point(Vector2(rightMostPoint, 1000))
	layer.add_child(newLine)
	newLine = Line2D.new()
	newLine.add_point(Vector2(0, upMostPoint))
	newLine.add_point(Vector2(2000, upMostPoint))
	layer.add_child(newLine)
	newLine = Line2D.new()
	newLine.add_point(Vector2(0, downMostPoint))
	newLine.add_point(Vector2(2000, downMostPoint))
	layer.add_child(newLine)
'''
