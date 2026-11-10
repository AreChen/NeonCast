"""Build a minimal, reproducible player archive and validate release metadata."""
import argparse
import hashlib
from pathlib import Path
import re
import stat
import xml.etree.ElementTree as ET
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
VERSION_PATTERN = r'(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-(?:alpha|beta|rc)\.(?:0|[1-9]\d*))?'
# Keep this explicit: unrelated/new artwork must not silently enter player downloads.
ASSETS = (
    'Media/NeonBack.tga',
    'Media/NeonGlow.tga',
    'Media/NeonRing.tga',
    'Icons/ChromaCast.tga',
)


def version():
    toc = (ROOT/'NeonCast.toc').read_text(encoding='utf-8-sig')
    match = re.search(r'^## Version:\s*(\S+)\s*$', toc, re.MULTILINE)
    if not match or not re.fullmatch(VERSION_PATTERN, match[1]):
        raise ValueError('NeonCast.toc needs a valid version: X.Y.Z or X.Y.Z-alpha/beta/rc.N')
    return match[1]


def validate_tag(tag):
    if not re.fullmatch('v' + VERSION_PATTERN, tag):
        raise ValueError('Release tags must be vX.Y.Z or vX.Y.Z-alpha/beta/rc.N')
    if tag != 'v' + version():
        raise ValueError(f'Tag {tag} does not match NeonCast.toc version {version()}')


def runtime_files():
    """TOC dependencies, automatically loaded bindings, required art, and license only."""
    files = set()

    def add(name):
        path = (ROOT/name.replace('\\', '/')).resolve()
        if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
            raise ValueError(f'Missing or out-of-project runtime file: {name}')
        if path in files:
            return
        files.add(path)
        if path.suffix.lower() == '.xml':
            # UI XML may load further Lua/XML relative to its own directory.
            for element in ET.parse(path).iter():
                if element.tag.rsplit('}', 1)[-1] in {'Script', 'Include'} and 'file' in element.attrib:
                    child = path.parent / element.attrib['file'].replace('\\', '/')
                    add(child.relative_to(ROOT).as_posix())

    add('NeonCast.toc')
    for line in (ROOT/'NeonCast.toc').read_text(encoding='utf-8-sig').splitlines():
        name = line.strip()
        if name and not name.startswith('#'):
            if Path(name).name.lower() == 'bindings.xml':
                raise ValueError('Bindings.xml must use the dedicated binding loader, not the TOC')
            if Path(name).suffix.lower() not in {'.lua', '.xml'}:
                raise ValueError(f'Unsupported TOC runtime file: {name}')
            add(name)
    add('Bindings.xml')
    add('LICENSE')
    for asset in ASSETS:
        add(asset)
    return sorted(files)


def package(output=None, tag=None):
    if tag is not None:
        validate_tag(tag)
    archive_version = version()
    paths = runtime_files()  # Validate all inputs before opening the output archive.
    output = Path(output) if output is not None else ROOT/'dist'/f'NeonCast-{archive_version}.zip'
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, 'w', ZIP_DEFLATED, compresslevel=9) as archive:
        for path in paths:
            info = ZipInfo('NeonCast/' + path.relative_to(ROOT).as_posix(), date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(info, path.read_bytes(), compress_type=ZIP_DEFLATED, compresslevel=9)
    return output


def release_notes(release_version):
    text = (ROOT/'CHANGELOG.md').read_text(encoding='utf-8')
    heading = f'## [{release_version}]'
    if heading not in text.splitlines():
        raise ValueError(f'CHANGELOG.md needs a {heading} section before release')
    section = text.split(heading, 1)[1].split('\n## ', 1)[0].strip()
    if not section:
        raise ValueError(f'Empty release notes for {release_version}')
    return section + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', help='Validate the Git tag against the TOC version')
    parser.add_argument('--output', type=Path, help='Override the versioned ZIP output path')
    parser.add_argument('--notes-output', type=Path, help='Export this version\'s changelog section for GitHub Releases')
    args = parser.parse_args()
    try:
        notes = release_notes(version()) if args.notes_output else None
        output = package(args.output, args.tag)
    except (ValueError, OSError, ET.ParseError) as error:
        parser.error(str(error))
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    checksum = output.with_suffix(output.suffix + '.sha256')
    checksum.write_text(f'{digest}  {output.name}\n', encoding='ascii')
    if args.notes_output:
        args.notes_output.parent.mkdir(parents=True, exist_ok=True)
        args.notes_output.write_text(notes, encoding='utf-8')
    print(output)
    print(checksum)


if __name__ == '__main__':
    main()
