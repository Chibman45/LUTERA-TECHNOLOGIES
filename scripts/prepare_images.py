"""Developer tool: prepare committed responsive WebP assets (requires Pillow)."""
from pathlib import Path
import argparse
from PIL import Image, ImageOps
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--widths',nargs='+',type=int,default=[480,768,960])
widths=parser.parse_args().widths
if any(width<1 or width>1920 for width in widths):parser.error('Use image widths between 1 and 1920.')
for source in (Path(__file__).resolve().parents[1]/'assets/photos').glob('*.jpg'):
 with Image.open(source) as opened:
  image=ImageOps.exif_transpose(opened).convert('RGB')
  for width in widths:
   output=image.copy()
   output.thumbnail((width,round(image.height*width/image.width)))
   output.save(source.with_name(f'{source.stem}-{width}.webp'),'WEBP',quality=80,method=6)
print('Prepared local WebP widths: '+', '.join(map(str,widths))+'.')
