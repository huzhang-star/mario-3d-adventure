extends RefCounted

static func material(color: Color, roughness := 0.65, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metal
	if glow > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

static func mesh(parent: Node3D, geometry: Mesh, pos: Vector3, scale_value: Vector3, mat: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = geometry
	part.position = pos
	part.scale = scale_value
	part.material_override = mat
	parent.add_child(part)
	return part

static func orb(parent: Node3D, pos: Vector3, radius: Vector3, mat: Material) -> MeshInstance3D:
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 24
	ball.rings = 12
	return mesh(parent, ball, pos, radius, mat)

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top_radius := -1.0, segments := 32) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.height = height
	shape.radial_segments = segments
	return mesh(parent, shape, pos, Vector3.ONE, mat)

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, Vector3.ONE, mat)

static func ring(parent: Node3D, pos: Vector3, radius: float, thickness: float, mat: Material) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - thickness
	shape.outer_radius = radius + thickness
	shape.rings = 64
	shape.ring_segments = 12
	return mesh(parent, shape, pos, Vector3.ONE, mat)

# Revolved profile for sculpted caps, bells and crowns, with smooth radial normals.
static func lathe(parent: Node3D, pos: Vector3, profile: Array, mat: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 40
	for row in profile.size() - 1:
		var a: Vector2 = profile[row]
		var b: Vector2 = profile[row + 1]
		for i in count:
			var angle0 := TAU * i / count
			var angle1 := TAU * (i + 1) / count
			var vertices := [Vector3(cos(angle0)*a.x,a.y,sin(angle0)*a.x), Vector3(cos(angle1)*a.x,a.y,sin(angle1)*a.x), Vector3(cos(angle0)*b.x,b.y,sin(angle0)*b.x), Vector3(cos(angle1)*b.x,b.y,sin(angle1)*b.x)]
			for id in [0,1,2,1,3,2]:
				surface.set_smooth_group(0)
				surface.add_vertex(vertices[id])
	surface.generate_normals()
	return mesh(parent, surface.commit(), pos, Vector3.ONE, mat)
