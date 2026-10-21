"""Developer tool: download credited hero sources and prepare committed WebPs.
Requires Pillow and network access. Not run by the website or deployment build.
"""
from io import BytesIO
from pathlib import Path
from urllib.request import urlopen
from PIL import Image,ImageOps
PHOTOS={
 'hero-workplace':'photo-1498050108023-c5249f4df085',
 'hero-support':'photo-1581092918056-0c4c3acd3789',
 'hero-cloud':'photo-1558494949-ef010cbdcc31',
}
root=Path(__file__).resolve().parents[1]/'assets/photos'
for name,photo in PHOTOS.items():
 with urlopen(f'https://images.unsplash.com/{photo}?auto=format&fit=crop&w=1920&h=1200&q=82',timeout=40) as response:
  image=ImageOps.exif_transpose(Image.open(BytesIO(response.read()))).convert('RGB')
 for width in [768,1280,1920]:
  resized=image.resize((width,round(image.height*width/image.width)),Image.Resampling.LANCZOS)
  resized.save(root/f'{name}-{width}.webp','WEBP',quality=79,method=6)
 print(f'Prepared {name} in three responsive sizes.')
