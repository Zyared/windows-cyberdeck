"""Replace spinner glyphs in a NEW lab copy. Invalidates the font signature.

The output is for the isolated EFI experiment, never a Windows font installer.
"""
import argparse
import hashlib
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.transformPen import TransformPen

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('source',type=Path)
p.add_argument('art',type=Path)
p.add_argument('output',type=Path)
args=p.parse_args()
if args.output.exists() or args.output.resolve()==args.source.resolve():
    raise ValueError('Output must be a new file; existing fonts are never overwritten')
before=hashlib.sha256(args.source.read_bytes()).hexdigest()
font=TTFont(args.source);art=TTFont(args.art)
cmap=font.getBestCmap(); artmap=art.getBestCmap(); glyphs=art.getGlyphSet()
for frames in (range(0xe052,0xe0cc),range(0xe100,0xe177)):
    original=[font['glyf'][cmap[c]] for c in frames]
    nonempty=[g for g in original if hasattr(g,'xMin')]
    x0=min(g.xMin for g in nonempty);y0=min(g.yMin for g in nonempty)
    x1=max(g.xMax for g in nonempty);y1=max(g.yMax for g in nonempty)
    scale=min((x1-x0)/900,(y1-y0)/900)
    dx=(x0+x1)/2-500*scale;dy=(y0+y1)/2-500*scale
    for n,c in enumerate(frames):
        # Resample the artwork cycle into both legacy dots and modern ring ranges.
        artcode=0xe052+n*122//len(frames)
        recording=DecomposingRecordingPen(glyphs);glyphs[artmap[artcode]].draw(recording)
        pen=TTGlyphPen(None)
        recording.replay(TransformPen(pen,(scale,0,0,scale,dx,dy)))
        replacement=pen.glyph();replacement.recalcBounds(font['glyf'])
        font['glyf'][cmap[c]]=replacement
        advance,_=font['hmtx'].metrics[cmap[c]]
        font['hmtx'].metrics[cmap[c]]=(advance,replacement.xMin)
args.output.parent.mkdir(parents=True,exist_ok=True)
font.save(args.output)
checked=TTFont(args.output,checkChecksums=2)
assert checked.getBestCmap()==cmap
assert hashlib.sha256(args.source.read_bytes()).hexdigest()==before
print(f'LAB ONLY: replaced 122+119 glyphs in {args.output}; signature no longer valid')
