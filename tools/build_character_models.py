import bpy
import math
import os


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "models")
os.makedirs(OUT, exist_ok=True)


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
    # A rounded shoe last: tapered ankle, broad toe and lifted front.
    verts = [
        (-.10, .10, .08), (.10, .10, .08), (-.13, -.24, .06), (.13, -.24, .06),
        (-.11, .10, -.06), (.11, .10, -.06), (-.15, -.25, -.05), (.15, -.25, -.05),
        (-.12, -.34, .00), (.12, -.34, .00),
    ]
    faces = [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3),(2,3,9,8),(6,8,9,7)]
    return mesh_object(name, verts, faces, mat, (x, -.04, -.98))


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
        arm = lathe(side + "Arm", [(0,.105),(-.10,.13),(-.42,.115),(-.59,.085)], jersey, (x, 0, .36), segments=16)
        arm.rotation_euler[1] = -.08 if side == "Left" else .08
        organic_form(side + "Hand", (.09,.085,.11), accent, (x, -.015, -.28), rings=7, segments=14)
    for side, x in [("Left", -.16), ("Right", .16)]:
        lathe(side + "Leg", [(0,.135),(-.12,.15),(-.48,.115),(-.68,.09)], accent, (x, 0, -.25), segments=16)
        boot(side + "Boot", shoe, x)


def build_lamb():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    wool = material("NaturalWool", (.90, .89, .82), .93)
    face = material("SheepFace", (.34, .29, .25), .88)
    black = material("EyesAndNose", (.012, .014, .016), .55)
    pink = material("InnerEar", (.50, .33, .31), .85)
    add_common("lamb")
    organic_form("Head", (.31,.27,.32), wool, (0, 0, .78), rings=11, segments=22, wool=.075)
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
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "lamb_player.glb"), export_format="GLB", export_yup=True, export_apply=True)


def build_pirate():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    skin = material("PirateSkin", (.58, .34, .22), .82)
    hair = material("PirateHair", (.12, .055, .03), .92)
    white = material("EyeWhite", (.92, .90, .82), .72)
    black = material("HatAndPatch", (.012, .016, .024), .58)
    blue = material("PirateBlue", (.27, .72, .88), .65)
    gold = material("PirateGold", (.85, .58, .12), .42)
    add_common("pirate")
    organic_form("Head", (.255,.235,.30), skin, (0,0,.76), rings=11, segments=22, muzzle=.05)
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
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "pirate_player.glb"), export_format="GLB", export_yup=True, export_apply=True)


build_lamb()
build_pirate()
