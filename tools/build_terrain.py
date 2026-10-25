"""Run through Blender MCP. Creates only the dedicated SchachTerrain scene."""
import bpy, math, random, os
from mathutils import Vector
ROOT='/Users/kevin/schach-2'
scene=bpy.data.scenes.get('SchachTerrain') or bpy.data.scenes.new('SchachTerrain')
bpy.context.window.scene=scene
for obj in list(scene.objects): bpy.data.objects.remove(obj,do_unlink=True)
rng=random.Random(72)
materials=[]
for name,color in [('limestone',(0.64,.60,.44,1)),('chalk',(.79,.75,.58,1)),('shadow stone',(.40,.46,.43,1)),('moss',(.25,.36,.08,1)),('leaf gold',(.46,.57,.12,1)),('leaf green',(.16,.32,.13,1)),('stem',(.24,.20,.09,1))]:
 m=bpy.data.materials.new('Terrain '+name);m.diffuse_color=color;m.use_nodes=True
 p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=color;p.inputs['Roughness'].default_value=.9
 materials.append(m)
parts=[]
def box(name,at,size,mat,bevel=.035):
 bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.name=name;o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(materials[mat])
 if bevel:
  b=o.modifiers.new('Chipped edges','BEVEL');b.width=bevel;b.segments=1
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=b.name)
 parts.append(o);return o

def export(name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
 o.data.validate();o.data.update()
 scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/terrain/'+name+'.glb',use_selection=True,use_active_scene=True,export_format='GLB')
 o.location.x=(len(exported)%6)*2.5;o.location.y=(len(exported)//6)*3;exported.append(o)
os.makedirs(ROOT+'/assets/terrain',exist_ok=True);exported=[]
for variant in range(3):
 parts=[]
 # Four subtly irregular paving stones share a level top at zero.
 for x in [-.25,.25]:
  for y in [-.25,.25]:
   o=box('paving',(x,y,-.10),(.485,.485,.20),1 if variant!=1 else 2,.025+rng.random()*.025)
   for v in o.data.vertices:
    if abs(v.co.x)>.18 and abs(v.co.y)>.18:v.co.x+=rng.uniform(-.025,.025);v.co.y+=rng.uniform(-.025,.025)
 if variant==2:
  for i in range(9):box('moss patch',(rng.uniform(-.46,.46),rng.uniform(-.46,.46),.005),(rng.uniform(.07,.17),rng.uniform(.05,.13),.018),3,.012)
 export(['slab_light','slab_dark','slab_moss'][variant])
parts=[]
for row in range(3):
 for col in range(2):
  box('foundation masonry',(-.25+col*.5+(.04 if row%2 else -.02),0,-.39-row*.35),(.48,.94,.33),rng.choice([0,0,2]),.045)
export('foundation')
parts=[]
for row in range(5):
 box('pillar block',(rng.uniform(-.025,.025),rng.uniform(-.025,.025),row*.36+.18),(.46,.46,.34),0,.035)
box('capital',(0,0,1.85),(.65,.65,.16),1,.03)
box('foot',(0,0,.08),(.64,.64,.16),1,.025)
export('pillar')
for variant in range(2):
 parts=[]
 for strand in range(3):
  x0=(strand-1)*.26;length=1.1+strand*.24+variant*.3
  points=[Vector((x0+math.sin(t*.9+strand)*.075,-.04+math.cos(t)*.025,-t*length/9)) for t in range(10)]
  for a,b in zip(points,points[1:]):
   o=box('vine stem',(a+b)/2,(.025,.025,(b-a).length),6,.005);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
  for i in range(1,18):
   t=i/18*9;j=min(8,int(t));p=points[j].lerp(points[j+1],t-j);side=-1 if i%2 else 1
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=p+Vector((side*.09,-.035,-.025)))
   o=bpy.context.object;o.name='ivy leaf';o.scale=(.12,.035,.085);o.rotation_euler.y=side*.6;o.data.materials.append(materials[rng.choice([3,4,5])]);parts.append(o)
 export('vines_'+str(variant))
# Expanded ruin and garden kit. All modules retain a shared ground origin.
for name,color in [('bark',(.25,.16,.09,1)),('canopy shade',(.19,.32,.10,1)),('canopy green',(.35,.48,.12,1)),('canopy sun',(.57,.62,.19,1)),('petal rose',(.72,.23,.43,1)),('petal lavender',(.53,.37,.68,1)),('petal ivory',(.94,.83,.56,1)),('flower heart',(.94,.57,.10,1)),('stone warm',(.70,.63,.46,1)),('stone cool',(.47,.51,.46,1))]:
 m=bpy.data.materials.new('Terrain '+name);m.diffuse_color=color;m.use_nodes=True
 p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=color;p.inputs['Roughness'].default_value=.9
 materials.append(m)

def ico(name,at,size,mat,subdivisions=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions,radius=1,location=at)
 o=bpy.context.object;o.name=name;o.scale=size;o.data.materials.append(materials[mat]);parts.append(o);return o

def branch(a,b,width,mat=7):
 a=Vector(a);b=Vector(b)
 bpy.ops.mesh.primitive_cone_add(vertices=7,radius1=width,radius2=width*.68,depth=(b-a).length,location=(a+b)/2)
 o=bpy.context.object;o.name='organic branch';o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(materials[mat]);parts.append(o)

def grass(at,count=7,height=.19):
 x,y,z=at
 for i in range(count):
  a=rng.uniform(0,math.tau);h=rng.uniform(height*.5,height);w=rng.uniform(.015,.035)
  bx=x+rng.uniform(-.055,.055);by=y+rng.uniform(-.055,.055)
  verts=[(bx-w*math.cos(a),by-w*math.sin(a),z),(bx+w*math.cos(a),by+w*math.sin(a),z),(bx+math.sin(a)*h*.45,by+math.cos(a)*h*.45,z+h)]
  # A thin triangular wedge keeps grass visible from either side with valid geometry.
  verts.append((bx,by+.006,z+h*.35))
  me=bpy.data.meshes.new('grass blade');me.from_pydata(verts,[],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)]);me.update()
  o=bpy.data.objects.new('grass through joint',me);scene.collection.objects.link(o);o.data.materials.append(materials[rng.choice([3,4,5])]);parts.append(o)

def flower(at,mat=11,height=.22):
 x,y,z=at
 branch((x,y,z),(x+.025,y,z+height),.012,5)
 ico('flower leaf',(x+.05,y,z+height*.45),(.075,.025,.03),5)
 for j in range(5):
  a=j*math.tau/5
  o=ico('petal',(x+.025+math.cos(a)*.052,y+math.sin(a)*.052,z+height),(.06,.037,.025),mat)
  o.rotation_euler.z=a
 ico('gold pollen',(x+.025,y,z+height+.015),(.027,.027,.025),14)

def paving(dark=False,wear=False):
 for x in [-.25,.25]:
  for y in [-.25,.25]:
   o=box('worn paving',(x,y,-.10),(.477,.477,.20),rng.choice([2,16]) if dark else rng.choice([1,1,15]),.025+rng.random()*.025)
   for v in o.data.vertices:
    if abs(v.co.x)>.17 and abs(v.co.y)>.17:
     v.co.x+=rng.uniform(-.035,.035);v.co.y+=rng.uniform(-.035,.035)
   if wear:
    # Recessed fissure fragments remain below the common playing plane.
    for j in range(2):
     mark=box('stone fissure',(x+rng.uniform(-.16,.16),y+rng.uniform(-.16,.16),.001),(.012,rng.uniform(.09,.21),.003),2,.001)
     mark.rotation_euler.z=rng.uniform(-1,1)

for style in ['weathered','grass','ivy','flowers']:
 for dark in [False,True]:
  parts=[];paving(dark,True)
  if style=='grass':
   for t in [-.36,-.13,.16,.37]:grass((0,t,.003),6,.15);grass((t,0,.003),5,.12)
  elif style=='ivy':
   for i in range(20):
    a=i*.5;x=-.38+i*.026;y=.33+math.sin(a)*.08
    ico('creeping leaf',(x,y,.022),(.07,.045,.018),rng.choice([3,4,5]))
  elif style=='flowers':
   for i in range(4):
    x=rng.uniform(-.43,-.24);y=rng.uniform(.20,.41);grass((x,y,0),4,.12);flower((x,y,0),rng.choice([11,12,13]),.12+rng.random()*.08)
  else:
   for i in range(5):box('lichen',(rng.uniform(-.44,.44),rng.uniform(-.44,.44),.006),(.06,.035,.01),3,.008)
  export('slab_'+style+('_dark' if dark else '_light'))

for style in ['broken','leaning','overgrown']:
 parts=[];rows=3 if style=='broken' else 6
 box('column plinth',(0,0,.10),(.72,.70,.20),1,.045)
 for j in range(rows):
  x=.045*j if style=='leaning' else rng.uniform(-.04,.04)
  o=box('weathered column',(x,0,.37+j*.32),(.43,.46,.30),rng.choice([0,15,16]),.05)
  o.rotation_euler.z=rng.uniform(-.06,.06)
 if style=='broken':
  for i in range(3):
   o=box('fractured crown',(rng.uniform(-.15,.15),rng.uniform(-.13,.13),1.17),(.18,.18,rng.uniform(.12,.28)),0,.04);o.rotation_euler.y=rng.uniform(-.3,.3)
 else:box('worn capital',(.24 if style=='leaning' else 0,0,2.18),(.67,.63,.18),1,.04)
 if style=='overgrown':
  for i in range(26):
   z=i*.075;x=.26+math.sin(i*.5)*.08
   ico('climbing ivy',(x,-.26,z),(.085,.04,.065),rng.choice([3,4,5]))
  for i in range(5):grass((rng.uniform(-.28,.28),rng.uniform(-.28,.28),.21),7,.22)
 export('pillar_'+style)

for broken in [False,True]:
 parts=[]
 for row in range(3):
  for col in range(3):
   if broken and row==2 and col>0:continue
   o=box('wall masonry',(-.36+col*.36+(row%2)*.045,0,.17+row*.29),(.345,.34,.275),rng.choice([0,15,16]),.045)
   if broken and col==2:o.rotation_euler.y=.13
 if not broken:box('wall coping',(0,0,.96),(1.19,.45,.14),1,.035)
 for i in range(7):ico('wall moss',(rng.uniform(-.48,.48),-.18,rng.uniform(.05,.66)),(.11,.03,.065),rng.choice([3,5]))
 export('wall_broken' if broken else 'wall_low')

# Pixel leaf-cluster sprites on layered cards replace the solid canopy balls.
leaf_rng=random.Random(341)
leaf_size=32
pixels=[0.0]*(leaf_size*leaf_size*4)
leaf_palette=[(.10,.20,.10,1),(.18,.31,.11,1),(.29,.42,.12,1),(.41,.53,.15,1),(.56,.64,.23,1),(.70,.73,.32,1)]
def stamp_leaf(cx,cy,rx,ry,shade):
 for py in range(max(0,int(cy-ry-1)),min(leaf_size,int(cy+ry+2))):
  for px in range(max(0,int(cx-rx-1)),min(leaf_size,int(cx+rx+2))):
   dx=(px-cx)/rx;dy=(py-cy)/ry
   if abs(dx)*.6+abs(dy)*.4<.90 and dx*dx+dy*dy<1:
    color=leaf_palette[max(0,min(5,shade+(1 if dx+dy>.25 else 0)))]
    n=(py*leaf_size+px)*4;pixels[n:n+4]=color
# Loose, stepped clusters, with small holes and dangling edge leaves.
for i in range(48):
 a=leaf_rng.uniform(0,math.tau);r=math.sqrt(leaf_rng.random())
 cx=15+math.cos(a)*11*r;cy=15+math.sin(a)*10*r
 stamp_leaf(cx,cy,leaf_rng.uniform(2.0,3.6),leaf_rng.uniform(1.4,2.4),int(2+cy/16)+leaf_rng.choice([-1,0,0]))
for i in range(8):
 a=leaf_rng.uniform(0,math.tau)
 stamp_leaf(15+math.cos(a)*13,15+math.sin(a)*12,1.9,1.5,3)
image=bpy.data.images.new('Terrain leaf cluster pixels',width=leaf_size,height=leaf_size,alpha=True)
image.pixels=pixels
image.filepath_raw=ROOT+'/assets/terrain/leaf_cluster.png'
# PNG is an Image format enum; use the installed identifier.
formats=[item.identifier for item in image.bl_rna.properties['file_format'].enum_items]
image.file_format=next(item for item in formats if item=='PNG');image.save();image.pack()
leaf_mat=bpy.data.materials.new('Terrain sprite leaves');leaf_mat.use_nodes=True;leaf_mat.use_backface_culling=False
modes=[item.identifier for item in leaf_mat.bl_rna.properties['surface_render_method'].enum_items]
leaf_mat.surface_render_method=next((mode for mode in modes if 'DITHER' in mode),modes[0])
principled=next(n for n in leaf_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
tex=leaf_mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
interpolations=[item.identifier for item in tex.bl_rna.properties['interpolation'].enum_items]
tex.interpolation=next(item for item in interpolations if 'Closest' in item)
leaf_mat.node_tree.links.new(tex.outputs['Color'],principled.inputs['Base Color'])
leaf_mat.node_tree.links.new(tex.outputs['Alpha'],principled.inputs['Alpha'])
principled.inputs['Roughness'].default_value=1
leaf_materials=[]
for variant,factor in [('shade',.65),('middle',.86),('sun',1.08)]:
 variant_image=bpy.data.images.new('Terrain leaf '+variant,width=leaf_size,height=leaf_size,alpha=True)
 variant_pixels=[value*factor if i%4!=3 else value for i,value in enumerate(pixels)]
 variant_image.pixels=variant_pixels
 variant_image.filepath_raw=ROOT+'/assets/terrain/leaf_cluster_'+variant+'.png'
 variant_image.file_format=image.file_format;variant_image.save();variant_image.pack()
 variant_mat=leaf_mat.copy();variant_mat.name='Terrain sprite leaves '+variant
 next(n for n in variant_mat.node_tree.nodes if n.type=='TEX_IMAGE').image=variant_image
 leaf_materials.append(variant_mat)


def leaf_card(at,width,height,turn=0):
 # Camera-facing bias preserves sprite shape; varied normals give the crown volume.
 normal=Vector((.65+leaf_rng.uniform(-.25,.25),-.65+leaf_rng.uniform(-.25,.25),.48+leaf_rng.uniform(-.15,.15))).normalized()
 right=normal.cross(Vector((0,0,1))).normalized();up=right.cross(normal).normalized()
 r=right*math.cos(turn)+up*math.sin(turn);u=up*math.cos(turn)-right*math.sin(turn)
 center=Vector(at)
 verts=[center+r*x*width+u*y*height for x,y in [(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]]
 mesh=bpy.data.meshes.new('leaf sprite card');mesh.from_pydata(verts,[],[(0,1,2,3)]);mesh.update()
 uv=mesh.uv_layers.new(name='UVMap')
 for loop,coord in zip(uv.data,[(0,0),(1,0),(1,1),(0,1)]):loop.uv=coord
 obj=bpy.data.objects.new('layered leaf sprite',mesh);scene.collection.objects.link(obj);shade=0 if at[2]<2.35 else (2 if at[2]>2.73 else 1)
 obj.data.materials.append(leaf_materials[shade]);parts.append(obj)

parts=[]
# A shorter, branching trunk supports the wide, irregular canopy in the reference.
for a in [0,1.4,2.8,4.2,5.3]:branch((math.cos(a)*.46,math.sin(a)*.36,.015),(0,0,.38),.10)
trunk=[(0,0,.12),(-.10,.04,.64),(-.33,.03,1.12),(-.27,0,1.65),(-.49,.04,2.03)]
for j in range(len(trunk)-1):branch(trunk[j],trunk[j+1],.20-j*.03)
for end in [(-1.18,-.10,1.98),(.68,.15,2.08),(-.12,-.63,2.18),(-.53,.64,2.32)]:
 end=Vector((end[0]*1.18,end[1]*1.18,end[2]-.10))
 branch(trunk[2],end,.085)
 branch(end,end+Vector((-.12,.03,.31)),.045)
# Five uneven boughs with layered cutout sprites and visible air between them.
for center,spread in [((-.95,.04,2.35),(.55,.43,.30)),((.27,.17,2.46),(.52,.43,.34)),((-.18,-.47,2.52),(.50,.36,.32)),((-.40,.48,2.65),(.49,.36,.31)),((-.48,.03,2.86),(.48,.36,.27))]:
 for i in range(13):
  at=Vector(center)+Vector((leaf_rng.uniform(-spread[0],spread[0]),leaf_rng.uniform(-spread[1],spread[1]),leaf_rng.uniform(-spread[2],spread[2])))
  at=Vector((at.x*1.18,at.y*1.18,2.40+(at.z-2.50)*1.20))
  leaf_card(at,leaf_rng.uniform(.70,1.02),leaf_rng.uniform(.55,.82),leaf_rng.uniform(-.6,.6))
for i in range(10):grass((rng.uniform(-.4,.4),rng.uniform(-.3,.3),0),7,.21)
export('tree')

for style in ['meadow','flowers','fern']:
 parts=[]
 for i in range(14):
  x=rng.uniform(-.42,.42);y=rng.uniform(-.34,.34)
  grass((x,y,0),8,.17 if style=='flowers' else .27)
  if style=='flowers':flower((x,y,0),rng.choice([11,12,13]),rng.uniform(.17,.32))
  elif style=='fern':
   for j in range(5):
    a=i*2.3;z=j*.045
    ico('fern frond',(x+math.cos(a)*j*.036,y+math.sin(a)*j*.036,z+.04),(.10-j*.012,.035,.025),5)
 export('garden_'+style)

# Frame the asset library without disturbing the user's other scenes.
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.region_3d.view_distance=14
  area.spaces.active.region_3d.view_location=Vector((6,0,0))
previous_save_versions=bpy.context.preferences.filepaths.save_version
bpy.context.preferences.filepaths.save_version=0
try:
 bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/art_sources/terrain.blend',copy=True)
finally:
 bpy.context.preferences.filepaths.save_version=previous_save_versions
print('Exported '+str(len(exported))+' terrain modules')
