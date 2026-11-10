"""Build an installable addon archive from its manifest and packaged media."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]

def package(output=None):
    output = output or ROOT/'dist'/'NeonCast.zip'
    output.parent.mkdir(parents=True,exist_ok=True)
    # Bindings.xml uses WoW's dedicated binding loader and must not be listed in the TOC.
    paths = {ROOT/'NeonCast.toc', ROOT/'Bindings.xml', ROOT/'LICENSE'}
    for line in (ROOT/'NeonCast.toc').read_text().splitlines():
        if line and not line.startswith('#'):
            paths.add(ROOT/line)
    for directory in ['Media','Icons']:
        paths.update(path for path in (ROOT/directory).rglob('*') if path.is_file())
    paths.update(ROOT.glob('README*.md'))
    with ZipFile(output,'w',ZIP_DEFLATED) as archive:
        for path in sorted(paths):
            archive.write(path,'NeonCast/'+path.relative_to(ROOT).as_posix())
    return output

if __name__=='__main__':
    print(package())
