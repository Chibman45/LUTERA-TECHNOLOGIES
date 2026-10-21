"""Developer tool: prepare committed responsive WebP assets (requires Pillow)."""
from pathlib import Path
from PIL import Image, ImageOps
for source in (Path(__file__).resolve().parents[1]/'assets/photos').glob('*.jpg'):
 with Image.open(source) as opened:
  image=ImageOps.exif_transpose(opened).convert('RGB')
  for width in [480,960]:
   output=image.copy()
   output.thumbnail((width,round(image.height*width/image.width)))
   output.save(source.with_name(f'{source.stem}-{width}.webp'),'WEBP',quality=80,method=6)
print('Prepared 480px and 960px local WebP variants.')
