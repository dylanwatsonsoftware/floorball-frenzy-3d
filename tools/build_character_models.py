import bpy
import math
import os


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "models")
SOURCE_OUT = os.path.join(ROOT, "blender_source")
os.makedirs(OUT, exist_ok=True)
os.makedirs(SOURCE_OUT, exist_ok=True)


def clear_scene():
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def material(name, color, roughness=0.72):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def mesh_object(name, vertices, faces, mat, location=(0, 0, 0)):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.data.materials.append(mat)
    return obj


def lathe(name, profile, mat, location=(0, 0, 0), segments=18, ripple=0.0):
    vertices = []
    for ring, (z, radius) in enumerate(profile):
        for segment in range(segments):
            angle = math.tau * segment / segments
            shaped_radius = radius * (1.0 + ripple * math.sin(angle * 5.0 + ring * 1.7))
            vertices.append((math.cos(angle) * shaped_radius, math.sin(angle) * shaped_radius, z))
    faces = []
    for ring in range(len(profile) - 1):
        for segment in range(segments):
            nxt = (segment + 1) % segments
            a = ring * segments + segment
            b = ring * segments + nxt
            c = (ring + 1) * segments + nxt
            d = (ring + 1) * segments + segment
            faces.append((a, b, c, d))
    faces.append(tuple(range(segments - 1, -1, -1)))
    top = (len(profile) - 1) * segments
    faces.append(tuple(top + index for index in range(segments)))
    return mesh_object(name, vertices, faces, mat, location)


def organic_form(name, radii, mat, location=(0, 0, 0), rings=9, segments=18, muzzle=0.0, wool=0.0):
    vertices = [(0.0, 0.0, radii[2])]
    for ring in range(1, rings):
        phi = math.pi * ring / rings
        for segment in range(segments):
            theta = math.tau * segment / segments
            wave = 1.0 + wool * math.sin(theta * 5.0 + phi * 7.0) * math.sin(phi)
            x = math.sin(phi) * math.cos(theta) * radii[0] * wave
            y = math.sin(phi) * math.sin(theta) * radii[1] * wave
            z = math.cos(phi) * radii[2]
            if y < 0.0:
                y *= 1.0 + muzzle * math.sin(phi) ** 2
            vertices.append((x, y, z))
    bottom = len(vertices)
    vertices.append((0.0, 0.0, -radii[2]))
    faces = []
    for segment in range(segments):
        faces.append((0, 1 + segment, 1 + (segment + 1) % segments))
    for ring in range(rings - 2):
        start = 1 + ring * segments
        next_start = start + segments
        for segment in range(segments):
            nxt = (segment + 1) % segments
            faces.append((start + segment, next_start + segment, next_start + nxt, start + nxt))
    last = 1 + (rings - 2) * segments
    for segment in range(segments):
        faces.append((last + segment, bottom, last + (segment + 1) % segments))
    return mesh_object(name, vertices, faces, mat, location)


def lens(name, size, mat, location, rotation=(0, 0, 0)):
    obj = organic_form(name, size, mat, location, rings=7, segments=14)
    obj.rotation_euler = rotation
    return obj


def boot(name, mat, x):
    # Compact court shoe: enough toe to read in profile without projecting as
    # a dark spike beyond the body in the broadcast camera.
    verts = [
        (-.10, .08, .08), (.10, .08, .08), (-.13, -.15, .06), (.13, -.15, .06),
        (-.11, .08, -.06), (.11, .08, -.06), (-.15, -.16, -.05), (.15, -.16, -.05),
        (-.12, -.22, .00), (.12, -.22, .00),
    ]
    faces = [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3),(2,3,9,8),(6,8,9,7)]
    return mesh_object(name, verts, faces, mat, (x, .015, -.98))


def create_shared_rig():
    armature_data = bpy.data.armatures.new("FloorballHumanoid")
    armature = bpy.data.objects.new("Armature", armature_data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = {
        "Root": ((0, 0, -1.02), (0, 0, -.92), None),
        "Hips": ((0, 0, -.36), (0, 0, -.12), "Root"),
        "Spine": ((0, 0, -.12), (0, 0, .18), "Hips"),
        "Chest": ((0, 0, .18), (0, 0, .48), "Spine"),
        "Neck": ((0, 0, .48), (0, 0, .60), "Chest"),
        "Head": ((0, 0, .60), (0, 0, 1.04), "Neck"),
        "Clavicle.L": ((-.05, 0, .43), (-.20, 0, .40), "Chest"),
        "Clavicle.R": ((.05, 0, .43), (.20, 0, .40), "Chest"),
        "UpperArm.L": ((-.20, 0, .40), (-.34, 0, .12), "Clavicle.L"),
        "Forearm.L": ((-.34, 0, .12), (-.34, 0, -.12), "UpperArm.L"),
        "Hand.L": ((-.34, 0, -.12), (-.34, 0, -.28), "Forearm.L"),
        "UpperArm.R": ((.20, 0, .40), (.34, 0, .12), "Clavicle.R"),
        "Forearm.R": ((.34, 0, .12), (.34, 0, -.12), "UpperArm.R"),
        "Hand.R": ((.34, 0, -.12), (.34, 0, -.28), "Forearm.R"),
        "Thigh.L": ((-.16, 0, -.20), (-.16, 0, -.52), "Hips"),
        "Shin.L": ((-.16, 0, -.52), (-.16, 0, -.86), "Thigh.L"),
        "Foot.L": ((-.16, 0, -.86), (-.16, -.24, -.98), "Shin.L"),
        "Thigh.R": ((.16, 0, -.20), (.16, 0, -.52), "Hips"),
        "Shin.R": ((.16, 0, -.52), (.16, 0, -.86), "Thigh.R"),
        "Foot.R": ((.16, 0, -.86), (.16, -.24, -.98), "Shin.R"),
    }
    for name, (head, tail, parent_name) in bones.items():
        bone = armature_data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        if parent_name:
            bone.parent = armature_data.edit_bones[parent_name]
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def bind_character_to_rig(armature):
    bone_for_part = {
        "Torso": "Chest", "JerseyStripe": "Chest", "Shorts": "Hips",
        "LeftArm": "UpperArm.L", "LeftHand": "Hand.L", "RightArm": "UpperArm.R", "RightHand": "Hand.R",
        "LeftLeg": "Thigh.L", "LeftBoot": "Foot.L", "RightLeg": "Thigh.R", "RightBoot": "Foot.R",
        "LambWoolCollar": "Chest",
    }
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        if obj.name in ("LeftArm", "RightArm"):
            side = "L" if obj.name.startswith("Left") else "R"
            upper_group = obj.vertex_groups.new(name="UpperArm.%s" % side)
            forearm_group = obj.vertex_groups.new(name="Forearm.%s" % side)
            for vertex in obj.data.vertices:
                # The elbow sits about .24 m down this local arm profile. Blend
                # across a broad sleeve section so IK bends rather than splits it.
                blend = max(0.0, min(1.0, (-vertex.co.z - .17) / .18))
                blend = blend * blend * (3.0 - 2.0 * blend)
                if blend < .999:
                    upper_group.add([vertex.index], 1.0 - blend, "REPLACE")
                if blend > .001:
                    forearm_group.add([vertex.index], blend, "REPLACE")
        else:
            bone_name = bone_for_part.get(obj.name, "Head")
            group = obj.vertex_groups.new(name=bone_name)
            group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
        modifier = obj.modifiers.new(name="SharedHumanoidRig", type="ARMATURE")
        modifier.object = armature
        obj.parent = armature


def add_pose_animation(armature, name, length, poses, loop=True):
    action = bpy.data.actions.new(name=name)
    armature.animation_data_create()
    armature.animation_data.action = action
    for bone in armature.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)
    for frame, bone_poses in poses.items():
        for bone_name, rotation in bone_poses.items():
            bone = armature.pose.bones[bone_name]
            bone.rotation_euler = rotation
            bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)
    action.frame_start = 1
    action.frame_end = length
    action.use_cyclic = loop
    armature.animation_data.action = None


def author_animation_set(armature):
    add_pose_animation(armature, "idle", 40, {
        1: {"Chest": (0, 0, -.03), "UpperArm.L": (-.45, 0, -.12), "UpperArm.R": (-.58, 0, .18)},
        20: {"Chest": (.025, 0, .03), "UpperArm.L": (-.49, 0, -.12), "UpperArm.R": (-.54, 0, .18)},
        40: {"Chest": (0, 0, -.03), "UpperArm.L": (-.45, 0, -.12), "UpperArm.R": (-.58, 0, .18)},
    })
    run_a = {"Thigh.L": (.72, 0, 0), "Thigh.R": (-.72, 0, 0), "Shin.L": (-.30, 0, 0), "UpperArm.L": (-.62, 0, -.12), "UpperArm.R": (-.36, 0, .18)}
    run_b = {"Thigh.L": (-.72, 0, 0), "Thigh.R": (.72, 0, 0), "Shin.R": (-.30, 0, 0), "UpperArm.L": (-.36, 0, -.12), "UpperArm.R": (-.62, 0, .18)}
    add_pose_animation(armature, "run", 20, {1: run_a, 10: run_b, 20: run_a})
    # Defensive recovery uses short, bent-knee steps and a low pelvis. It is not
    # the forward run played in reverse: the chest stays available to watch the ball.
    back_a = {"Hips": (.12, 0, -.035), "Thigh.L": (.36, 0, 0), "Thigh.R": (-.28, 0, 0), "Shin.L": (-.34, 0, 0), "Shin.R": (-.18, 0, 0)}
    back_b = {"Hips": (.12, 0, .035), "Thigh.L": (-.28, 0, 0), "Thigh.R": (.36, 0, 0), "Shin.L": (-.18, 0, 0), "Shin.R": (-.34, 0, 0)}
    add_pose_animation(armature, "backpedal", 24, {1: back_a, 12: back_b, 24: back_a})
    shuffle_left_a = {"Hips": (.08, 0, -.12), "Thigh.L": (0, 0, -.38), "Thigh.R": (0, 0, .18), "Shin.L": (-.24, 0, 0), "Shin.R": (-.16, 0, 0)}
    shuffle_left_b = {"Hips": (.08, 0, -.07), "Thigh.L": (0, 0, .14), "Thigh.R": (0, 0, -.34), "Shin.L": (-.16, 0, 0), "Shin.R": (-.24, 0, 0)}
    shuffle_right_a = {"Hips": (.08, 0, .12), "Thigh.L": (0, 0, .18), "Thigh.R": (0, 0, -.38), "Shin.L": (-.16, 0, 0), "Shin.R": (-.24, 0, 0)}
    shuffle_right_b = {"Hips": (.08, 0, .07), "Thigh.L": (0, 0, -.34), "Thigh.R": (0, 0, .14), "Shin.L": (-.24, 0, 0), "Shin.R": (-.16, 0, 0)}
    add_pose_animation(armature, "strafe_left", 24, {1: shuffle_left_a, 12: shuffle_left_b, 24: shuffle_left_a})
    add_pose_animation(armature, "strafe_right", 24, {1: shuffle_right_a, 12: shuffle_right_b, 24: shuffle_right_a})
    add_pose_animation(armature, "slap_shot", 24, {
        1: {"Hips": (0, 0, 0), "Chest": (0, 0, 0), "Clavicle.L": (0, 0, -.04), "Clavicle.R": (0, 0, .04), "UpperArm.L": (-.5, 0, -.12), "UpperArm.R": (-.58, 0, .18)},
        9: {"Hips": (0, 0, -.28), "Chest": (-.10, 0, -.62), "Clavicle.L": (0, -.18, -.22), "Clavicle.R": (0, .22, -.16), "UpperArm.L": (-.30, -.22, -.55), "UpperArm.R": (-.36, .30, -.48)},
        15: {"Hips": (0, 0, .22), "Chest": (.14, 0, .52), "Clavicle.L": (0, .12, .18), "Clavicle.R": (0, -.16, .22), "UpperArm.L": (-.78, .12, .44), "UpperArm.R": (-.82, -.18, .58)},
        24: {"Hips": (0, 0, 0), "Chest": (0, 0, 0), "Clavicle.L": (0, 0, -.04), "Clavicle.R": (0, 0, .04), "UpperArm.L": (-.5, 0, -.12), "UpperArm.R": (-.58, 0, .18)},
    }, loop=False)


def finalize_character(team):
    armature = create_shared_rig()
    bind_character_to_rig(armature)
    author_animation_set(armature)
    bpy.context.scene.render.fps = 30
    source_path = os.path.join(SOURCE_OUT, "%s_player.blend" % team)
    export_path = os.path.join(OUT, "%s_player.glb" % team)
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    bpy.ops.export_scene.gltf(
        filepath=export_path, export_format="GLB", export_yup=True,
        export_animations=True, export_animation_mode="ACTIONS", export_apply=False,
    )
    # Exporters can alter scene state. Keep the reusable .blend as the final,
    # authoritative artifact and fail the build if Blender did not write it.
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    if not os.path.isfile(source_path) or os.path.getsize(source_path) < 1024:
        raise RuntimeError("Blender source was not saved correctly: %s" % source_path)
    if os.path.getmtime(source_path) < os.path.getmtime(export_path):
        raise RuntimeError("Blender source is older than its export: %s" % source_path)


def add_common(team):
    jersey = material("LambsGreen" if team == "lamb" else "PiratesBlack", (0.05, .48, .19) if team == "lamb" else (.035, .045, .065))
    accent = material("White" if team == "lamb" else "IceBlue", (.94, .96, .94) if team == "lamb" else (.30, .76, .90))
    dark = material("Shorts", (.025, .035, .055))
    shoe = material("CourtShoes", (.015, .02, .028), .48)
    torso = lathe("Torso", [(-.34,.25),(-.24,.31),(.12,.34),(.34,.31),(.43,.23)], jersey)
    torso.scale.y = .72
    stripe = lathe("JerseyStripe", [(-.02,.345),(.04,.35),(.10,.345)], accent, segments=20)
    stripe.scale.y = .73
    shorts = lathe("Shorts", [(-.42,.27),(-.29,.31),(-.20,.31),(-.13,.27)], dark)
    shorts.scale.y = .72
    for side, x in [("Left", -.32), ("Right", .32)]:
        arm = lathe(side + "Arm", [(0,.105),(-.10,.13),(-.18,.125),(-.24,.115),(-.30,.11),(-.38,.115),(-.48,.10),(-.59,.085)], jersey, (x, 0, .36), segments=16)
        arm.rotation_euler[1] = -.08 if side == "Left" else .08
        organic_form(side + "Hand", (.09,.085,.11), accent, (x, -.015, -.28), rings=7, segments=14)
    for side, x in [("Left", -.16), ("Right", .16)]:
        lathe(side + "Leg", [(0,.135),(-.12,.15),(-.48,.115),(-.68,.09)], accent, (x, 0, -.25), segments=16)
        boot(side + "Boot", shoe, x)


def build_lamb():
    clear_scene()
    wool = material("NaturalWool", (.90, .89, .82), .93)
    face = material("SheepFace", (.34, .29, .25), .88)
    black = material("EyesAndNose", (.012, .014, .016), .55)
    pink = material("InnerEar", (.50, .33, .31), .85)
    add_common("lamb")
    organic_form("HeadVisual", (.31,.27,.32), wool, (0, 0, .78), rings=11, segments=22, wool=.075)
    organic_form("LambFace", (.17,.19,.25), face, (0, -.19, .73), rings=9, segments=18, muzzle=.22)
    organic_form("Muzzle", (.12,.13,.10), face, (0, -.34, .62), rings=7, segments=16, muzzle=.12)
    lens("LeftLambEar", (.20,.065,.09), face, (-.27, -.01, .85), (0,.12,-.22))
    lens("RightLambEar", (.20,.065,.09), face, (.27, -.01, .85), (0,-.12,.22))
    lens("LeftInnerEar", (.135,.068,.045), pink, (-.285, -.065, .85), (0,.12,-.22))
    lens("RightInnerEar", (.135,.068,.045), pink, (.285, -.065, .85), (0,-.12,.22))
    organic_form("LeftEye", (.038,.025,.050), black, (-.085, -.375, .79), rings=7, segments=14)
    organic_form("RightEye", (.038,.025,.050), black, (.085, -.375, .79), rings=7, segments=14)
    organic_form("LambNose", (.047,.032,.035), black, (0, -.455, .63), rings=7, segments=14)
    lathe("LambWoolCollar", [(-.08,.23),(0,.31),(.08,.27)], wool, (0,0,.49), segments=22, ripple=.12)
    # The named fleece crown is one continuous, rippled modeled surface.
    crown = lathe("LambWool", [(-.08,.19),(0,.30),(.10,.24)], wool, (0,0,.98), segments=22, ripple=.16)
    crown.scale.y = .88
    finalize_character("lamb")


def build_pirate():
    clear_scene()
    skin = material("PirateSkin", (.58, .34, .22), .82)
    hair = material("PirateHair", (.12, .055, .03), .92)
    white = material("EyeWhite", (.92, .90, .82), .72)
    black = material("HatAndPatch", (.012, .016, .024), .58)
    blue = material("PirateBlue", (.27, .72, .88), .65)
    gold = material("PirateGold", (.85, .58, .12), .42)
    add_common("pirate")
    organic_form("HeadVisual", (.255,.235,.30), skin, (0,0,.76), rings=11, segments=22, muzzle=.05)
    lens("LeftHumanEar", (.065,.045,.095), skin, (-.255, 0, .76))
    lens("RightHumanEar", (.065,.045,.095), skin, (.255, 0, .76))
    organic_form("LeftEye", (.055,.025,.040), white, (-.085,-.235,.80), rings=7, segments=14)
    organic_form("RightEye", (.055,.025,.040), white, (.085,-.235,.80), rings=7, segments=14)
    organic_form("PirateNose", (.062,.08,.09), skin, (0,-.265,.72), rings=8, segments=16, muzzle=.25)
    beard = organic_form("PirateBeard", (.22,.16,.25), hair, (0,-.08,.57), rings=10, segments=20)
    beard.scale.y = .72
    # Curved moustache lobes and a modeled eyepatch sit on the authored head.
    lens("LeftMoustache", (.105,.035,.035), hair, (-.07,-.285,.665), (0,0,-.28))
    lens("RightMoustache", (.105,.035,.035), hair, (.07,-.285,.665), (0,0,.28))
    lens("PirateEyePatch", (.09,.028,.075), black, (-.09,-.272,.80))
    lathe("PirateBandana", [(-.035,.255),(.025,.27),(.065,.25)], blue, (0,0,.94), segments=22)
    # Tricorne brim uses a three-lobed radial profile instead of a flat box.
    verts = []
    faces = []
    segments = 36
    for ring, radius in enumerate((.13,.36)):
        for index in range(segments):
            angle = math.tau * index / segments
            lobe = 1.0 + .22 * math.cos(angle * 3.0)
            verts.append((math.cos(angle)*radius*lobe, math.sin(angle)*radius*.72*lobe, .99 + ring*.015))
    for index in range(segments):
        nxt = (index + 1) % segments
        faces.append((index,nxt,segments+nxt,segments+index))
    hat = mesh_object("PirateTricorne", verts, faces, black)
    lathe("HatCrown", [(1.00,.22),(1.12,.25),(1.25,.16)], black, segments=22)
    lathe("HatBand", [(1.045,.225),(1.075,.235),(1.105,.225)], gold, segments=22)
    finalize_character("pirate")


build_lamb()
build_pirate()
