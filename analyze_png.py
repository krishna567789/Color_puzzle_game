import sys
from PIL import Image

img = Image.open('assets/blender/bottol_cap.png')
print(f"Size: {img.size}")
box = img.getbbox()
print(f"Bounding box of non-transparent pixels: {box}")
