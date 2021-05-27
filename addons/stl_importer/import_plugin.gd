tool
extends EditorImportPlugin

func get_importer_name():
	return "stl.importer"
	
func get_visible_name():
	return "STL Importer"
	
func get_recognized_extensions():
	return ["stl"]
	
func get_save_extension():
	return "mesh"
	
func get_resource_type():
	return "Mesh"
	
func get_preset_count():
	return 0
	
func get_import_options(preset):
	return []
	
func get_preset_name(preset):
	return "Unknown"
	
func import(source_file, save_path, options, platform_variants, gen_files):
	# STL file format: https://web.archive.org/web/20210428125112/http://www.fabbers.com/tech/STL_Format
	
	var file = File.new()
	var err = file.open(source_file, File.READ)
	if err != OK:
		return err
	
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# STL lists its vertices in counterclockwise order
	# while Godot uses clockwise order for front faces in primitive triangle mode
	# so we will temporarily store them and when we leave a facet add the vertices to surface_tool
	var vertices = []
	
	# first line should be in the format "solid name"
	# we are going to ignore the name
	file.get_line()
	
	var parsing_state = PARSE_STATE.SOLID
	
	while !file.eof_reached():
		if parsing_state == PARSE_STATE.SOLID:
			var line = file.get_line().strip_edges(true, true)
			
			# last line should be "endsolid name"
			# just continue because the loop should end because EOF reached
			if line.begins_with("endsolid"):
				continue
			elif line != "":
				var parts = line.split(" ")
				
				# first 2 items of the parts array should be "facet" and "normal"
				# the next 3 items should be the normals
				var normal_x = float(parts[2])
				var normal_y = float(parts[3])
				var normal_z = float(parts[4])
				surface_tool.add_normal(Vector3(normal_x, normal_y, normal_z))
				
				parsing_state = PARSE_STATE.FACET
				
		elif parsing_state == PARSE_STATE.FACET:
			var line = file.get_line().strip_edges(true, true)
			
			if line == "endfacet":
				parsing_state = PARSE_STATE.SOLID
			elif line != "":
				# line should be "outer loop"
				# we can ignore this line and continue on to parsing the vertices
				parsing_state = PARSE_STATE.OUTER_LOOP
		
		elif parsing_state == PARSE_STATE.OUTER_LOOP:
			var line = file.get_line().strip_edges(true, true)
			
			if line == "endloop":
				for vec in vertices:
					surface_tool.add_vertex(vec)
					
				vertices.clear()
				parsing_state = PARSE_STATE.FACET
			elif line != "":
				var parts = line.split(" ")
				
				# first item of the parts array should be "vertex"
				# the next 3 items should be the vertex coordinates
				var x = float(parts[1])
				var y = float(parts[2])
				var z = float(parts[3])
				
				# add the vertex at the front of the array 
				# this way we don't have to loop over the array in reverse
				# to add the vertices to the mesh
				vertices.insert(0, Vector3(x, y, z))
	
	var final_mesh = surface_tool.commit()
	
	return ResourceSaver.save("%s.%s" % [save_path, get_save_extension()], final_mesh)

enum PARSE_STATE {SOLID, FACET, OUTER_LOOP}
