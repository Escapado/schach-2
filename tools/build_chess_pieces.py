"""Run in Blender through its MCP. Rebuilds only the SchachPieces scene."""
import bpy, math, os
from mathutils import Vector
ROOT = "/Users/kevin/schach-2/assets/pieces"
os.makedirs(ROOT, exist_ok=True)
scene = bpy.data.scenes.new("SchachPieces") if "SchachPieces" not in bpy.data.scenes else bpy.data.scenes["SchachPieces"]
bpy.context.window.scene = scene
for obj in list(scene.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
mat = bpy.data.materials.new("Ivory stone")
mat.diffuse_color = (0.82, 0.72, 0.53, 1)
mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Base Color"].default_value = (0.82, 0.72, 0.53, 1)
bsdf.inputs["Roughness"].default_value = 0.85
parts = []
def mesh(name, verts, faces):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    parts.append(obj)
    return obj
def lathe(profile, sides=12):
    verts = [(r*math.cos(2*math.pi*i/sides), r*math.sin(2*math.pi*i/sides), z) for z,r in profile for i in range(sides)]
    faces = [tuple(reversed(range(sides)))]
    for j in range(len(profile)-1):
        for i in range(sides):
            a=j*sides+i; b=j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple((len(profile)-1)*sides+i for i in range(sides)))
    return mesh("turned stone", verts, faces)
def box(center, size, angle=0):
    x,y,z=center; a,b,c=[v/2 for v in size]
    verts=[]
    for dz in [-c,c]:
        for dx,dy in [(-a,-b),(a,-b),(a,b),(-a,b)]:
            verts.append((x+dx*math.cos(angle)-dy*math.sin(angle), y+dx*math.sin(angle)+dy*math.cos(angle),z+dz))
    return mesh("carved detail",verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
def sphere(z,r):
    profile=[(z+r*math.sin(-math.pi/2+math.pi*j/8),max(0.001,r*math.cos(-math.pi/2+math.pi*j/8))) for j in range(9)]
    return lathe(profile)
base=[(0,.34),(.06,.39),(.16,.39),(.21,.32),(.25,.32),(.29,.26)]
for index,kind in enumerate(["pawn","rook","knight","bishop","queen","king"]):
    parts=[]
    lathe(base)
    if kind=="pawn":
        lathe([(.29,.25),(.36,.23),(.62,.13),(.67,.21),(.73,.21),(.77,.13)])
        sphere(.91,.19)
    elif kind=="rook":
        lathe([(.29,.26),(.38,.22),(.91,.20),(.97,.30),(1.08,.30)])
        for i in range(6):
            a=i*math.tau/6
            box((.24*math.cos(a),.24*math.sin(a),1.16),(.16,.16,.19),a)
    elif kind=="bishop":
        lathe([(.29,.26),(.38,.23),(.86,.13),(.91,.24),(.99,.24),(1.04,.13),(1.11,.22),(1.25,.20),(1.50,.025)])
        sphere(1.53,.055)
    elif kind=="queen":
        lathe([(.29,.26),(.40,.23),(1.06,.13),(1.12,.26),(1.20,.26),(1.28,.22),(1.46,.30)])
        for i in range(8):
            a=i*math.tau/8
            obj=box((.27*math.cos(a),.27*math.sin(a),1.51),(.09,.09,.20),a)
        sphere(1.54,.115)
    elif kind=="king":
        lathe([(.29,.27),(.40,.23),(1.12,.14),(1.18,.27),(1.28,.27),(1.34,.20),(1.43,.20)])
        box((0,0,1.63),(.11,.13,.43))
        box((0,0,1.68),(.37,.13,.11))
    else:
        lathe([(.29,.26),(.37,.24),(.44,.21)])
        # Extruded horse profile faces toward -Y; broad neck, muzzle and two ears.
        outline=[(.18,.44),(-.17,.44),(-.21,.70),(-.18,.94),(-.40,1.01),(-.44,1.14),(-.29,1.25),(-.14,1.47),(.02,1.43),(.18,1.21),(.25,.82)]
        verts=[(x,y,z) for x in [-.14,.14] for y,z in outline]
        n=len(outline)
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        mesh("horse",verts,faces)
        for x in [-.105,.105]:
            box((x,-.10,1.48),(.075,.12,.22))
        for j in range(5):
            box((0,.17-j*.025,.85+j*.105),(.32,.09,.10))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name=kind
    # All six files share a ground origin and metre scale.
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,kind+".glb"),use_selection=True,use_active_scene=True,export_format="GLB")
    obj.location.x=(index-2.5)*1.25
source_dir = os.path.abspath(os.path.join(ROOT, "../../art_sources"))
os.makedirs(source_dir, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source_dir,"chess_pieces.blend"),copy=True)
print("Created and exported six chess pieces in "+ROOT)

