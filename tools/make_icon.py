import sys
from PIL import Image
# 16x16 pixel art: sprout on soil inside a wooden frame. '.' = transparent.
P = {
 'O': (74,44,23,255),   # outline
 'W': (184,118,58,255), # wood
 'w': (126,75,34,255),  # wood dark
 'S': (243,226,184,255),# sky/parchment
 'G': (107,175,74,255), # leaf
 'g': (63,125,42,255),  # leaf dark
 'B': (122,78,44,255),  # soil
 'b': (92,58,30,255),   # soil dark
 'Y': (233,184,74,255), # sun
}
art = [
"OOOOOOOOOOOOOOOO",
"OWWWWWWWWWWWWWWO",
"OWSSSSSSSSSSYYwO",
"OWSSSSSSSSSSYYwO",
"OWSSSSGGSSSSSSwO",
"OWSSSGGgSSSSSSwO",
"OWSSSGgSSGGSSSwO",
"OWSSSSgSGGgSSSwO",
"OWSSSSgGgSSSSSwO",
"OWSSSSSgSSSSSSwO",
"OWSSSSSgSSSSSSwO",
"OWBBBBBBBBBBBBwO",
"OWBbBBbBBBbBBbwO",
"OWbBBbBBbBBBbBwO",
"OwwwwwwwwwwwwwwO",
"OOOOOOOOOOOOOOOO",
]
img = Image.new('RGBA', (16,16))
for y,row in enumerate(art):
    for x,c in enumerate(row):
        img.putpixel((x,y), P.get(c,(0,0,0,0)))
out = sys.argv[1]
for name,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    img.resize((size,size), Image.NEAREST).save(f"{out}/mipmap-{name}/ic_launcher.png")
import os
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
img.resize((512,512), Image.NEAREST).save(os.path.join(root, "store", "icon_512.png"))
print("ok")
