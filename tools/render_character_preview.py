import bpy
import sys
from mathutils import Vector


args = sys.argv[sys.argv.index("--") + 1:]
source_path, output_path = args
bpy.ops.wm.open_mainfile(filepath=source_path)
bpy.ops.object.camera_add(location=(2.8, -5.8, 1.8))
camera = bpy.context.object
camera.rotation_euler = ((Vector((0, 0, 0.05)) - camera.location).to_track_quat("-Z", "Y")).to_euler()
bpy.context.scene.camera = camera
for location, energy, size in [((-3, -4, 5), 900, 5), ((4, 1, 3), 600, 4)]:
    bpy.ops.object.light_add(type="AREA", location=location)
    bpy.context.object.data.energy = energy
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = size
bpy.context.scene.render.engine = "BLENDER_EEVEE"
bpy.context.scene.render.resolution_x = 700
bpy.context.scene.render.resolution_y = 700
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.world.color = (0.035, 0.04, 0.055)
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.filepath = output_path
bpy.ops.render.render(write_still=True)
