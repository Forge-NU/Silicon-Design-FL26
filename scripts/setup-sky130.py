#!/usr/bin/env python3
"""Install the pinned PDK and generate an opt-in project under the user's home.
No vendor scripts are executed. No shared files or shell startup files are edited.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shlex
import shutil
import tarfile
import tempfile

SHA = '1a3846edc3552d99c289061515512116ca97f8db8fba7d365904082a54cb5bfb'
NAME = 'sky130_release_0.1.0'
REPO = Path(__file__).resolve().parents[1]


def inside_home(path):
    path = Path(path).expanduser().resolve()
    home = Path.home().resolve()
    if home not in path.parents:
        raise ValueError('Destination must be strictly inside your home: ' + str(path))
    # Reject paths that would be ambiguous in generated Cadence configuration.
    if any(c in str(path) for c in '\n\r"$\\'):
        raise ValueError('Use a Linux home path without quotes, dollar signs or backslashes')
    ancestor = path
    while not ancestor.exists():
        ancestor = ancestor.parent
    if hasattr(os, 'getuid') and ancestor.stat().st_uid != os.getuid():
        raise ValueError('Destination ancestor must be owned by you')
    return path


def install(root, name=NAME, sha=SHA):
    archive = REPO / 'vendor/sky130' / (name + '.tgz')
    if hashlib.sha256(archive.read_bytes()).hexdigest() != sha:
        raise ValueError('Archive checksum mismatch; nothing extracted')
    marker = root / '.forge-package-sha256'
    if root.exists():
        if not marker.is_file() or marker.read_text().strip() != sha:
            raise ValueError('Existing PDK is not this managed installation; choose a new path')
        return
    root.parent.mkdir(parents=True, exist_ok=True)
    # TemporaryDirectory only removes the newly allocated staging directory.
    with tempfile.TemporaryDirectory(prefix='.sky130-stage-', dir=root.parent) as td:
        stage = Path(td)
        aliases = []
        with tarfile.open(archive) as tar:
            for member in tar:
                rel = PurePosixPath(member.name)
                if rel.is_absolute() or '..' in rel.parts or rel.parts[0] != name:
                    raise ValueError('Unsafe archive path: ' + member.name)
                dest = stage.joinpath(*rel.parts)
                if member.isdir():
                    dest.mkdir(parents=True, exist_ok=True)
                elif member.isfile():
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    with tar.extractfile(member) as src, dest.open('xb') as out:
                        shutil.copyfileobj(src, out)
                    dest.chmod(0o700 if member.mode & 0o111 else 0o600)
                elif member.issym():
                    target = (dest.parent / member.linkname).resolve()
                    if (stage / name) not in target.parents:
                        raise ValueError('Unsafe archive link')
                    aliases.append((dest, target))
                else:
                    raise ValueError('Unsupported archive member: ' + member.name)
        for dest, target in aliases:
            # Materialize the internal RCXdspfINIT alias for filesystem portability.
            shutil.copyfile(target, dest)
        package = stage / name
        shutil.copytree(REPO / 'vendor/sky130', package / 'forge-distribution-notices',
                        ignore=shutil.ignore_patterns('*.tgz'))
        (package / '.forge-package-sha256').write_text(sha + '\n')
        package.rename(root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default='~/forge-projects/sky130')
    parser.add_argument('--pdk-root', default='~/.local/share/forge-silicon/pdks/' + NAME)
    parser.add_argument('--with-mpw', action='store_true', help='Also install/register optional die collateral')
    args = parser.parse_args()
    project, root = inside_home(args.project), inside_home(args.pdk_root)
    if root == project or root in project.parents or project in root.parents:
        raise ValueError('Project and PDK must be separate directories')
    install(root)
    scl = inside_home(root.parent / 'sky130_scl_9T_0.1.2')
    install(scl, 'sky130_scl_9T_0.1.2', 'c28363b936f3845fb02df8ea03b7106b17ffcf28ed6accfa3e1ea9fefd3f4c71')
    mpw = inside_home(root.parent / 'sky130_die_collateral_1.1')
    if args.with_mpw:
        install(mpw, 'sky130_die_collateral_1.1', '8464226fe231c6dfdad2a6da875cfa88451bf8e7baef4609c1eea5d03c6c21b4')
    paths = {
        'SKY130_SCL_ROOT': scl,
        'PDK_HOME': root, 'PDKDIR': root, 'SKY130_ROOT': root,
        'PEGASUS_DRC': root / 'Sky130_DRC',
        'FORGE_SKY130_MODEL': root / 'models/sky130.lib.spice',
        'FORGE_SKY130_DRC': root / 'Sky130_DRC/sky130_rev_0.0_2.12.drc.pvl',
        'FORGE_SKY130_LVS': root / 'Sky130_LVS/sky130.lvs.v0.0_1.1.pvl',
        'FORGE_SKY130_QRC': root / 'quantus/extraction/typical/qrcTechFile',
    }
    for value in paths.values():
        if not value.exists():
            raise ValueError('Required package content missing: ' + str(value))
    env = ''.join('export {}={}\n'.format(k, shlex.quote(str(v))) for k, v in paths.items())
    env += 'export FORGE_SKY130_CORNER=tt\n'
    cds = ('DEFINE analogLib $CDSHOME/tools/dfII/etc/cdslib/artist/analogLib\n'
           'DEFINE basic $CDSHOME/tools/dfII/etc/cdslib/basic\n'
           'DEFINE sky130_fd_pr_main "' + str(root / 'libs/sky130_fd_pr_main') + '"\n')
    for lib in ['sky130_scl_9T', 'sky130_scl_9T_tech']:
        cds += 'DEFINE ' + lib + ' "' + str(scl / lib) + '"\n'
    if args.with_mpw:
        cds += 'DEFINE sky130_die_collateral "' + str(mpw / 'sky130_die_collateral') + '"\n'
    def tclpath(p):
        return '{' + str(p) + '}'
    base = scl / 'sky130_scl_9T'
    tech = scl / 'sky130_scl_9T_tech'
    manifest = '# Generated base 9T selection. Preserve vendor dont_use restrictions.\n'
    for key, value in {
        'liberty_slow': base / 'lib/sky130_ss_1.62_125_nldm.lib.gz',
        'liberty_fast': base / 'lib/sky130_ff_1.98_0_nldm.lib.gz',
        'liberty_typical': base / 'lib/sky130_tt_1.8_25_nldm.lib.gz',
        'tech_lef': tech / 'lef/sky130_scl_9T.tlef',
        'cell_verilog': base / 'verilog/sky130_scl_9T.v',
        'qrc_typical': paths['FORGE_SKY130_QRC'],
    }.items():
        if not value.is_file():
            raise ValueError('Missing digital input: ' + str(value))
        manifest += 'set ' + key + ' ' + ('[list ' + tclpath(value) + ']' if key.startswith('liberty_') or key == 'cell_verilog' else tclpath(value)) + '\n'
    manifest += 'set cell_lefs [list ' + tclpath(base / 'lef/sky130_scl_9T.lef') + ' ' + tclpath(tech / 'lef/sky130_scl_9T_phyCells.lef') + ']\n'
    manifest += 'set placement_site CoreSite\nset power_net VDD\nset ground_net VSS\nset pdk_id sky130_0.1.0_scl_9T_0.1.2\n'
    # Only typical RC is supplied; do not invent slow/fast extraction corners.
    env += 'export FORGE_PDK_CONFIG=' + shlex.quote(str(project / '.forge-sky130/pdk.tcl')) + '\n'
    env += 'export FORGE_REPO=' + shlex.quote(str(REPO)) + '\n'
    launch = '''#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
export FORGE_PDK_ENV="$PWD/.forge-sky130/env.sh"
tool=${1:-virtuoso}
if [[ $# -gt 0 ]]; then shift; fi
case "$tool" in
  virtuoso|spectre|pegasus|qrc|xrun|genus|innovus|tempus|lec) ;;
  *) echo 'Use virtuoso, spectre, pegasus, qrc, xrun, genus, innovus, tempus or lec.' >&2; exit 2;;
esac
exec bash REPO_LAUNCH "$tool" "$@"
'''.replace('REPO_LAUNCH', shlex.quote(str(REPO / 'bin/forge-eda')))
    rules = (';; Forge-generated overlay; vendor files remain unchanged.\n'
             'pegasusRuleSet( "sky130_forge"\n'
             '  ( DrcRules ' + json.dumps(str(paths['FORGE_SKY130_DRC'])) + ' )\n'
             '  ( LvsRules ' + json.dumps(str(paths['FORGE_SKY130_LVS'])) + ' )\n)\n'
             'ruleSet( "typical"\n  ( RcxSetupDir ' +
             json.dumps(str(root / 'quantus/extraction/typical')) + ' )\n)\n')
    model = 'simulator lang=spectre\ninclude ' + json.dumps(str(paths['FORGE_SKY130_MODEL'])) + ' section=tt\n'
    outputs = {'cds.lib': cds, 'launch.sh': launch,
               '.forge-sky130/models.scs': model,
               '.forge-sky130/pdk.tcl': manifest,
               '.forge-sky130/env.sh': env, '.forge-sky130/techRuleSets': rules,
               '.forge-sky130/paths.json': json.dumps({k:str(v) for k,v in paths.items()}, indent=2)+'\n'}
    # Check every target before modifying any project file. Never overwrite edits.
    for name, content in outputs.items():
        target = project / name
        if project not in target.resolve().parents:
            raise ValueError('Project path escapes through a link: ' + str(target))
        if target.is_symlink() or (target.exists() and target.read_text() != content):
            raise ValueError('Preserving existing project file; choose a new project: ' + str(target))
    for name, content in outputs.items():
        target = project / name
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
    print('Prepared user-local project: ' + str(project))
    print('Launch: bash ' + shlex.quote(str(project / 'launch.sh')) + ' virtuoso')
    print('Paths: ' + str(project / '.forge-sky130/paths.json'))
    print('Configuration prepared; Cadence execution and design validation still required.')
    print('Base 9T digital manifest prepared. Typical RC only; full flow and AMS still require validation.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, tarfile.TarError) as exc:
        raise SystemExit('SKY130 setup: ' + str(exc))
