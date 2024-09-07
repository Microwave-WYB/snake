extends	Node2D

class GameState:
	enum State {
		IDLE,
		PLAYING,
		GAME_OVER,
	}

	var	current_state: State = State.IDLE
	var	snake: Array[Vector2] =	[]
	var	food: Vector2 =	Vector2.ZERO
	var	score: int = 0
	var	direction: Vector2 = Vector2.RIGHT
	var	move_timer:	float =	0.0
	var	move_interval: float = 0.0
	var	input_buffer: Array[Vector2] = []

	func handle_input(new_direction: Vector2) -> void:
		if current_state ==	State.IDLE or current_state	==	State.GAME_OVER:
			current_state =	State.PLAYING

		if new_direction !=	Vector2.ZERO:
			add_to_input_buffer(new_direction)

	func add_to_input_buffer(new_direction:	Vector2) ->	void:
		input_buffer.append(new_direction)
		if input_buffer.size() > 4:
			input_buffer.pop_front()

	func reset(initial_move_interval: float, grid_size:	int) ->	void:
		current_state =	State.IDLE
		# Calculate	the	center of the grid
		var	center = Vector2(grid_size / 2,	grid_size /	2)
		# Spawn	the	snake in the center, facing	right
		snake =	[
			center + Vector2(1,	0),
			center,
			center + Vector2(-1, 0)
		]
		direction =	Vector2.RIGHT
		score =	0
		move_timer = 0
		move_interval =	initial_move_interval
		input_buffer.clear()

	func get_next_valid_direction()	-> Vector2:
		while not input_buffer.is_empty():
			var	next_direction = input_buffer.pop_front()
			if next_direction +	direction != Vector2.ZERO:
				return next_direction
		return Vector2.ZERO

# Game settings
@export	var	grid_size: int = 20
@export	var	move_interval_base:	float =	0.2
@export	var	min_swipe_distance:	float =	20.0  #	Minimum	distance for a swipe to	be registered

var	screen_size: Vector2
var	game_size: float
var	cell_size: float
var	offset:	Vector2

var	game_state:	GameState =	GameState.new()

var	swipe_start: Vector2 = Vector2.ZERO
var	is_swiping:	bool = false

# Labels
@onready var score_label: Label	= $CanvasLayer/ScoreLabel
@onready var control_label:	Label =	$CanvasLayer/ControlLabel
@onready var game_over_label: Label	= $CanvasLayer/GameOverLabel

func _ready() -> void:
	screen_size	= get_viewport_rect().size
	calculate_game_dimensions()
	randomize()
	reset_game()
	
	# Position labels
	var	label_position = offset	+ Vector2(20, 20)
	score_label.position = label_position
	control_label.position = label_position
	game_over_label.position = label_position

func calculate_game_dimensions() ->	void:
	game_size =	min(screen_size.x, screen_size.y)
	cell_size =	game_size /	grid_size
	offset = (screen_size -	Vector2(game_size, game_size)) / 2

func _input(event: InputEvent) -> void:
	if event is	InputEventMouseButton:
		if event.pressed:
			start_swipe(event.position)
		else:
			end_swipe(event.position)
	elif event is InputEventMouseMotion	and	is_swiping:
		update_swipe(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			start_swipe(event.position)
		else:
			end_swipe(event.position)
	elif event is InputEventScreenDrag and is_swiping:
		update_swipe(event.position)

	# Keyboard input remains the same
	if game_state.current_state	== GameState.State.PLAYING:
		if event is	InputEventKey:
			var	new_direction =	Vector2.ZERO
			if event.is_action_pressed("ui_up"):
				new_direction =	Vector2.UP
			elif event.is_action_pressed("ui_down"):
				new_direction =	Vector2.DOWN
			elif event.is_action_pressed("ui_left"):
				new_direction =	Vector2.LEFT
			elif event.is_action_pressed("ui_right"):
				new_direction =	Vector2.RIGHT
			
			if new_direction !=	Vector2.ZERO:
				game_state.handle_input(new_direction)

func start_swipe(position: Vector2)	-> void:
	swipe_start	= position
	is_swiping = true

func update_swipe(position:	Vector2) ->	void:
	if is_swiping:
		var	swipe =	position - swipe_start
		if swipe.length() >	min_swipe_distance:
			var	new_direction =	get_direction_from_swipe(swipe)
			game_state.handle_input(new_direction)
			# Reset	swipe start	to allow for continuous	swiping
			swipe_start	= position

func end_swipe(position: Vector2) -> void:
	if is_swiping:
		var	swipe =	position - swipe_start
		if swipe.length() >	min_swipe_distance:
			var	new_direction =	get_direction_from_swipe(swipe)
			game_state.handle_input(new_direction)
	is_swiping = false

func get_direction_from_swipe(swipe: Vector2) -> Vector2:
	if abs(swipe.x)	> abs(swipe.y):
		return Vector2.RIGHT if	swipe.x	> 0	else Vector2.LEFT
	else:
		return Vector2.DOWN	if swipe.y > 0 else	Vector2.UP
func process_idle_state() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		game_state.current_state = GameState.State.PLAYING
	update_labels(false, false,	true)

func process_playing_state(delta: float) ->	void:
	game_state.move_timer += delta
	game_state.move_interval = 0.05	if Input.is_action_pressed("ui_select")	else move_interval_base

	if game_state.move_timer >=	game_state.move_interval:
		game_state.move_timer =	0
		move_snake()
		queue_redraw()
	
	update_labels(true,	false, false)
	score_label.text = "Score: %d" % game_state.score

func process_game_over_state() -> void:
	if Input.is_action_just_pressed("ui_accept") or is_swiping:
		reset_game()
		game_state.current_state = GameState.State.PLAYING
	update_labels(false, true, false)
	game_over_label.text = "Score: %d\nGame	Over!\nPress Space or tap to restart" %	game_state.score

func update_labels(show_score: bool, show_game_over: bool, show_control: bool) -> void:
	score_label.visible	= show_score
	game_over_label.visible	= show_game_over
	control_label.visible =	show_control

func _draw() ->	void:
	draw_game_area()
	draw_grid()
	draw_snake()
	draw_food()

func draw_game_area() -> void:
	draw_rect(Rect2(offset,	Vector2(game_size, game_size)),	Color("111111"))

func draw_grid() ->	void:
	for	i in range(grid_size + 1):
		var	start =	offset + Vector2(i * cell_size,	0)
		var	end	= offset + Vector2(i * cell_size, game_size)
		draw_line(start, end, Color("222222"))
		
		start =	offset + Vector2(0,	i *	cell_size)
		end	= offset + Vector2(game_size, i	* cell_size)
		draw_line(start, end, Color("222222"))

func draw_snake() -> void:
	for	segment	in game_state.snake:
		draw_rect(Rect2(offset + segment * cell_size, Vector2(cell_size, cell_size)), Color("00aa00"))

func draw_food() ->	void:
	draw_rect(Rect2(offset + game_state.food * cell_size, Vector2(cell_size, cell_size)), Color("aa0000"))

func reset_game() -> void:
	game_state.reset(move_interval_base, grid_size)
	spawn_food()

func spawn_food() -> void:
	var	x =	randi()	% grid_size
	var	y =	randi()	% grid_size
	game_state.food	= Vector2(x, y)
	while game_state.food in game_state.snake:
		x =	randi()	% grid_size
		y =	randi()	% grid_size
		game_state.food	= Vector2(x, y)


func move_snake() -> void:
	var	next_direction = game_state.get_next_valid_direction()
	if next_direction != Vector2.ZERO:
		game_state.direction = next_direction
	
	var	head = game_state.snake[0]
	var	new_head = wrap_position(head +	game_state.direction)

	game_state.snake.push_front(new_head)

	if new_head	== game_state.food:
		game_state.score +=	1
		spawn_food()
	else:
		game_state.snake.pop_back()

	if new_head	in game_state.snake.slice(1):
		game_state.current_state = GameState.State.GAME_OVER

func wrap_position(pos:	Vector2) ->	Vector2:
	return Vector2(
		posmod(pos.x, grid_size),
		posmod(pos.y, grid_size)
	)

func _process(delta: float)	-> void:
	match game_state.current_state:
		GameState.State.IDLE:
			process_idle_state()
		GameState.State.PLAYING:
			process_playing_state(delta)
		GameState.State.GAME_OVER:
			process_game_over_state()
	
	# Force	redraw every frame
	queue_redraw()
