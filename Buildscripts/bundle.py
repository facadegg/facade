#!/usr/bin/env python3

import os
import subprocess
import sys

cpuname = subprocess.check_output(['sysctl', '-n', 'machdep.cpu.brand_string']).decode(encoding='utf-8')
cpuintel = 'intel' in cpuname.lower()
brew_home = '/usr/local/lib' if cpuintel else '/opt/homebrew/lib'
brew_cellar = '/usr/local/Cellar' if cpuintel else '/opt/homebrew/Cellar'

def find_and_copy_dependencies(library_path, dependencies = []):
    print(library_path)
    basename = os.path.basename(library_path)
    destination = os.path.join(frameworks_path, basename) if library_path != executable_path else executable_path

    output = subprocess.check_output(['otool', '-l', os.path.basename(library_path)], cwd=os.path.dirname(library_path))
    lines = [line.strip().decode() for line in output.splitlines()]
    cmd = None

    if library_path != executable_path:
        try:
            subprocess.check_call(['cp', library_path, destination])
        except Exception as e:
            print(e)
        subprocess.check_call(['install_name_tool', '-id', f'@rpath/{basename}', destination],
                              stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL)

    for line in lines:
        if line.startswith('cmd '):
            cmd = line.replace('cmd ', '').strip()
        elif cmd == 'LC_LOAD_DYLIB' and line.startswith('name '):
            dependency_path = line.split(' ')[1]

            if ('@rpath' not in dependency_path or library_path != executable_path or dependency_path.endswith('onnxruntime.1.15.0.dylib')) \
                    and '@loader_path' not in dependency_path \
                    and '@executable_path' not in dependency_path \
                    and 'libc++' not in dependency_path \
                    and '/System/Library' not in dependency_path \
                    and '/usr/lib' not in dependency_path:
                original_path = dependency_path
                if dependency_path.startswith('@rpath/'):
                    dependency_path = dependency_path.replace('@rpath', brew_home)
                    if dependency_path.endswith('libquadmath.0.dylib') or\
                        dependency_path.endswith('libgcc_s.1.1.dylib'):
                        dependency_path = f'{brew_cellar}/gcc/13.1.0/lib/gcc/current/{os.path.basename(dependency_path)}'
                    if dependency_path.endswith('libonnxruntime.1.15.0.dylib'):
                        dependency_path = os.path.expanduser(f'~/Workspace/PaalMaxima/onnxruntime/build/MacOS/RelWithDebInfo/{os.path.basename(dependency_path)}')

                print(f'\t {basename} → {dependency_path}')

                subprocess.check_call(['install_name_tool', '-change', original_path, f'@rpath/{os.path.basename(dependency_path)}', destination],
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)

                if dependency_path not in dependencies:
                    dependencies.append(dependency_path)
                    find_and_copy_dependencies(dependency_path, dependencies)

    subprocess.check_call([
        'codesign',
        '--force',
        '--verify',
        '--verbose',
        '--options',
        'runtime',
        '--sign',
        "CDPZ9359Z6",
    ] + ([
        '--entitlements',
        'Lens/Lens.entitlements'
    ] if library_path == executable_path else [])
      + [destination])

    return dependencies


def find_and_copy_resources():
    subprocess.check_output(['cp', '/opt/facade/CenterFace.mlmodel', resources_path])
    subprocess.check_output(['cp', '/opt/facade/FaceMesh.mlmodel', resources_path])
    subprocess.check_output(['cp',
                             os.path.join(executable_original_directory, 'face_compositor.metallib'),
                             resources_path])
    subprocess.check_output(['cp',
                             os.path.join(executable_original_directory, 'face_compositor.metallib'),
                             os.path.join('/opt/facade/', 'face_compositor.metallib')])


if __name__ == '__main__':
    bundle_path = os.path.abspath(sys.argv[1])
    executable_name = sys.argv[2]
    executable_original_directory = os.path.dirname(bundle_path)
    executable_path = os.path.join(bundle_path, 'Contents', 'MacOS', executable_name)
    frameworks_path = os.path.join(bundle_path, 'Contents', 'Frameworks')
    library_path = os.path.join(bundle_path, 'Contents', 'Library')
    resources_path = os.path.join(bundle_path, 'Contents', 'Resources')
    os.makedirs(frameworks_path, exist_ok=True)
    os.makedirs(library_path, exist_ok=True)
    os.makedirs(resources_path, exist_ok=True)

    find_and_copy_dependencies(executable_path)
    subprocess.check_call([
          'codesign',
          '--force',
          '--verify',
          '--verbose',
          '--options',
          'runtime',
          '--sign',
          "CDPZ9359Z6",
      ] + [
               '--entitlements',
               'Lens/Lens.entitlements'
       ]
      + [executable_path])
    find_and_copy_resources()