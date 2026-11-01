"""Export the native APK using the existing update identity. Never prints signing secrets."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    ap.add_argument('--version-code', type=int, required=True)
    ap.add_argument('--profile-seconds', type=int, default=0, help='Export a benchmark build; collect PROFILE JSON with adb logcat.')
    ap.add_argument('--quality', choices=['low', 'medium', 'high'], default='medium')
    ap.add_argument('--output', default=str(ROOT / 'rruga-e-kombit.apk'))
    args = ap.parse_args()
    if args.version_code < 1:
        ap.error('version code must be positive')
    env = os.environ.copy()
    # Preserve the established signing identity. CI may override the same values
    # via secrets; the original project already distributes this fixed key.
    legacy = (ROOT / 'android/app/build.gradle').read_text()
    fields = {'USER': 'keyAlias', 'PASSWORD': 'storePassword'}
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH'] = str(ROOT / 'android/app/rruga.jks')
    for key, field in fields.items():
        name = 'GODOT_ANDROID_KEYSTORE_RELEASE_' + key
        if not env.get(name):
            env[name] = re.search(field + r"\s+'([^']+)'", legacy).group(1)
    java = env.get('JAVA_HOME', '/usr/lib/jvm/temurin-17-jdk-amd64')
    sdk = env.get('ANDROID_HOME', env.get('ANDROID_SDK_ROOT', ''))
    if not Path(java, 'bin/javac').exists() or not Path(sdk, 'platform-tools/adb').exists():
        raise SystemExit('Set JAVA_HOME to a JDK 17 and ANDROID_HOME to an installed Android SDK.')
    # Separate non-secret editor configuration; do not overwrite developer settings.
    config = ROOT / 'godot/.godot/export-config'
    editor = config / 'godot/editor_settings-4.4.tres'
    editor.parent.mkdir(parents=True, exist_ok=True)
    import json
    editor.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
                      + 'export/android/android_sdk_path = ' + json.dumps(sdk) + '\n'
                      + 'export/android/java_sdk_path = ' + json.dumps(java) + '\n')
    env['XDG_CONFIG_HOME'] = str(config)
    presets = ROOT / 'godot/export_presets.cfg'
    original = presets.read_text()
    updated = re.sub(r'^version/code=.*$', f'version/code={args.version_code}', original, flags=re.M)
    updated = re.sub(r'^version/name=.*$', f'version/name="1.0.{args.version_code}"', updated, flags=re.M)
    if args.profile_seconds:
        extra = f'--scene=race --auto --quality={args.quality} --benchmark={args.profile_seconds}'
        updated = re.sub(r'^command_line/extra_args=.*$', f'command_line/extra_args="{extra}"', updated, flags=re.M)
    destination = Path(args.output).resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = tempfile.NamedTemporaryFile(prefix='.godot-export-', suffix='.apk', dir=destination.parent, delete=False)
    temporary.close()
    candidate = Path(temporary.name)
    candidate.unlink()
    try:
        presets.write_text(updated)
        install = [] if (ROOT / 'godot/android/build/build.gradle').exists() else ['--install-android-build-template']
        subprocess.run([args.godot, '--headless', '--path', str(ROOT / 'godot'), *install,
                        '--export-release', 'Android', str(candidate)], env=env, check=True)
        subprocess.run([os.sys.executable, str(ROOT / 'tools/verify_apk.py'), str(candidate),
                        '--version-code', str(args.version_code)], env=env, check=True)
        os.replace(candidate, destination)
    finally:
        presets.write_text(original)
        candidate.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
