extends MotionBlurCompositorEffect
class_name GuertinMotionBlur

@export_group("Motion Blur", "motion_blur_")
# diminishing returns over 16
@export_range(4, 64) var motion_blur_samples: int = 25
# you really don't want this over 0.5, but you can if you want to try
@export_range(0, 0.5, 0.001, "or_greater") var motion_blur_intensity: float = 1
@export_range(0, 1) var motion_blur_center_fade: float = 0.0

@export var blur_stage : ShaderStageResource = preload("res://addons/SphynxMotionBlurToolkit/Guertin/guertin_blur_stage.tres"):
	set(value):
		unsubscribe_shader_stage(blur_stage)
		blur_stage = value
		subscirbe_shader_stage(value)

@export var overlay_stage : ShaderStageResource = preload("res://addons/SphynxMotionBlurToolkit/Guertin/guertin_overlay_stage.tres"):
	set(value):
		unsubscribe_shader_stage(overlay_stage)
		overlay_stage = value
		subscirbe_shader_stage(value)

@export var tile_max_x_stage : ShaderStageResource = preload("res://addons/SphynxMotionBlurToolkit/Guertin/guertin_tile_max_x_stage.tres"):
	set(value):
		unsubscribe_shader_stage(tile_max_x_stage)
		tile_max_x_stage = value
		subscirbe_shader_stage(value)

@export var tile_max_y_stage : ShaderStageResource = preload("res://addons/SphynxMotionBlurToolkit/Guertin/guertin_tile_max_y_stage.tres"):
	set(value):
		unsubscribe_shader_stage(tile_max_y_stage)
		tile_max_y_stage = value
		subscirbe_shader_stage(value)

@export var neighbor_max_stage : ShaderStageResource = preload("res://addons/SphynxMotionBlurToolkit/Guertin/guertin_neighbor_max_stage.tres"):
	set(value):
		unsubscribe_shader_stage(neighbor_max_stage)
		neighbor_max_stage = value
		subscirbe_shader_stage(value)

@export var tile_variance_stage : ShaderStageResource = preload("res://addons/SphynxMotionBlurToolkit/Guertin/guertin_tile_variance_stage.tres"):
	set(value):
		unsubscribe_shader_stage(tile_variance_stage)
		tile_variance_stage = value
		subscirbe_shader_stage(value)

@export var tile_size : int = 40

@export var linear_falloff_slope : float = 1

@export var importance_bias : float = 40

@export var maximum_jitter_value : float = 0.95

@export var minimum_user_threshold : float = 1.5

var output_color: StringName = "output_color"

var tile_max_x : StringName = "tile_max_x"

var tile_max : StringName = "tile_max"

var neighbor_max : StringName = "neighbor_max"

var tile_variance : StringName = "tile_variance"

var custom_velocity : StringName = "custom_velocity"

var debug_1 : StringName = "debug_1"
var debug_2 : StringName = "debug_2"
var debug_3 : StringName = "debug_3"
var debug_4 : StringName = "debug_4"

var freeze : bool = false

func _get_max_dilation_range() -> float:
	return tile_size;

func _render_callback_2(render_size : Vector2i, render_scene_buffers : RenderSceneBuffersRD, render_scene_data : RenderSceneDataRD):
	ensure_texture(tile_max_x, render_scene_buffers, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, Vector2(1. / tile_size, 1.))
	ensure_texture(tile_max, render_scene_buffers, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, Vector2(1. / tile_size, 1. / tile_size))
	ensure_texture(neighbor_max, render_scene_buffers, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, Vector2(1. / tile_size, 1. / tile_size))
	ensure_texture(tile_variance, render_scene_buffers, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, Vector2(1. / tile_size, 1. / tile_size))
	ensure_texture(custom_velocity, render_scene_buffers)
	ensure_texture(output_color, render_scene_buffers)
	ensure_texture(debug_1, render_scene_buffers)
	ensure_texture(debug_2, render_scene_buffers)
	ensure_texture(debug_3, render_scene_buffers)
	ensure_texture(debug_4, render_scene_buffers)
	
	rd.draw_command_begin_label("Motion Blur", Color(1.0, 1.0, 1.0, 1.0))
	
	var tile_max_x_push_constants: PackedFloat32Array = [
		0,
		0,
		0,
		0
	]
	var int_tile_max_x_push_constants : PackedInt32Array = [
		tile_size,
		0,
		0,
		0
	]
	var tile_max_x_push_constants_byte_array = tile_max_x_push_constants.to_byte_array()
	tile_max_x_push_constants_byte_array.append_array(int_tile_max_x_push_constants.to_byte_array())
	
	var tile_max_y_push_constants: PackedFloat32Array = [
		0,
		0,
		0,
		0
	]
	var int_tile_max_y_push_constants : PackedInt32Array = [
		tile_size,
		0,
		0,
		0
	]
	var tile_max_y_push_constants_byte_array = tile_max_y_push_constants.to_byte_array()
	tile_max_y_push_constants_byte_array.append_array(int_tile_max_y_push_constants.to_byte_array())
	
	var neighbor_max_push_constants: PackedFloat32Array = [
		0,
		0,
		0,
		0
	]
	var int_neighbor_max_push_constants : PackedInt32Array = [
		0,
		0,
		0,
		0
	]
	var neighbor_max_push_constants_byte_array = neighbor_max_push_constants.to_byte_array()
	neighbor_max_push_constants_byte_array.append_array(int_neighbor_max_push_constants.to_byte_array())
	
	var tile_variance_push_constants: PackedFloat32Array = [
		0,
		0,
		0,
		0
	]
	var int_tile_variance_push_constants : PackedInt32Array = [
		0,
		0,
		0,
		0
	]
	var tile_variance_push_constants_byte_array = tile_variance_push_constants.to_byte_array()
	tile_variance_push_constants_byte_array.append_array(int_tile_variance_push_constants.to_byte_array())
	
	var blur_push_constants: PackedFloat32Array = [
		minimum_user_threshold, 
		importance_bias,
		maximum_jitter_value, 
		0,
	]
	var int_blur_push_constants : PackedInt32Array = [
		tile_size,
		motion_blur_samples,
		Engine.get_frames_drawn() % 8,
		0
	]
	var blur_push_constants_byte_array = blur_push_constants.to_byte_array()
	blur_push_constants_byte_array.append_array(int_blur_push_constants.to_byte_array())
	
	var view_count = render_scene_buffers.get_view_count()
	
	for view in range(view_count):
		var color_image := render_scene_buffers.get_color_layer(view)
		var depth_image := render_scene_buffers.get_depth_layer(view)
		var output_color_image := render_scene_buffers.get_texture_slice(context, output_color, view, 0, 1, 1)
		var tile_max_x_image := render_scene_buffers.get_texture_slice(context, tile_max_x, view, 0, 1, 1)
		var tile_max_image := render_scene_buffers.get_texture_slice(context, tile_max, view, 0, 1, 1)
		var neighbor_max_image := render_scene_buffers.get_texture_slice(context, neighbor_max, view, 0, 1, 1)
		var tile_variance_image := render_scene_buffers.get_texture_slice(context, tile_variance, view, 0, 1, 1)
		var custom_velocity_image := render_scene_buffers.get_texture_slice(context, custom_velocity, view, 0, 1, 1)
		var debug_1_image := render_scene_buffers.get_texture_slice(context, debug_1, view, 0, 1, 1)
		var debug_2_image := render_scene_buffers.get_texture_slice(context, debug_2, view, 0, 1, 1)
		var debug_3_image := render_scene_buffers.get_texture_slice(context, debug_3, view, 0, 1, 1)
		var debug_4_image := render_scene_buffers.get_texture_slice(context, debug_4, view, 0, 1, 1)
		
		var x_groups := floori((render_size.x / tile_size - 1) / 16 + 1)
		var y_groups := floori((render_size.y - 1) / 16 + 1)
		
		dispatch_stage(tile_max_x_stage, 
		[
			get_sampler_uniform(custom_velocity_image, 0, false),
			get_sampler_uniform(depth_image, 1, false),
			get_image_uniform(tile_max_x_image, 2)
		],
		tile_max_x_push_constants_byte_array,
		Vector3i(x_groups, y_groups, 1), 
		"TileMaxX", 
		view)
		
		x_groups = floori((render_size.x / tile_size - 1) / 16 + 1)
		y_groups = floori((render_size.y / tile_size - 1) / 16 + 1)
		
		dispatch_stage(tile_max_y_stage, 
		[
			get_sampler_uniform(tile_max_x_image, 0, false),
			get_image_uniform(tile_max_image, 1)
		],
		tile_max_y_push_constants_byte_array,
		Vector3i(x_groups, y_groups, 1), 
		"TileMaxY", 
		view)
		
		dispatch_stage(neighbor_max_stage, 
		[
			get_sampler_uniform(tile_max_image, 0, false),
			get_image_uniform(neighbor_max_image, 1)
		],
		neighbor_max_push_constants_byte_array,
		Vector3i(x_groups, y_groups, 1), 
		"NeighborMax", 
		view)
		
		dispatch_stage(tile_variance_stage, 
		[
			get_sampler_uniform(tile_max_image, 0, false),
			get_image_uniform(tile_variance_image, 1)
		],
		tile_variance_push_constants_byte_array,
		Vector3i(x_groups, y_groups, 1), 
		"TileVariance", 
		view)
		
		x_groups = floori((render_size.x - 1) / 16 + 1)
		y_groups = floori((render_size.y - 1) / 16 + 1)
		
		dispatch_stage(blur_stage, 
		[
			get_sampler_uniform(color_image, 0, false),
			get_sampler_uniform(depth_image, 1, false),
			get_sampler_uniform(custom_velocity_image, 2, false),
			get_sampler_uniform(neighbor_max_image, 3, false),
			get_sampler_uniform(tile_variance_image, 4, true),
			get_image_uniform(output_color_image, 5),
			get_image_uniform(debug_1_image, 6),
			get_image_uniform(debug_2_image, 7),
			get_image_uniform(debug_3_image, 8),
			get_image_uniform(debug_4_image, 9)
		],
		blur_push_constants_byte_array,
		Vector3i(x_groups, y_groups, 1), 
		"Blur", 
		view)
		
		dispatch_stage(overlay_stage, 
		[
			get_sampler_uniform(output_color_image, 0, false),
			get_image_uniform(color_image, 1)
		],
		[],
		Vector3i(x_groups, y_groups, 1), 
		"Overlay result", 
		view)
	
	rd.draw_command_end_label()