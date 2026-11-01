"""Check native APK package/version, manifest readability, orientation and signature."""
import argparse
import os
from pathlib import Path
import re
import subprocess

ap = argparse.ArgumentParser()
ap.add_argument('apk')
ap.add_argument('--version-code', type=int)
args = ap.parse_args()
sdk = Path(os.environ.get('ANDROID_HOME', os.environ.get('ANDROID_SDK_ROOT', '')))
tools = sdk / 'build-tools/34.0.0'
subprocess.run([str(tools / 'apksigner'), 'verify', args.apk], check=True)
badging = subprocess.check_output([str(tools / 'aapt'), 'dump', 'badging', args.apk], text=True)
assert "package: name='al.tukehub.rruga'" in badging, 'wrong application identity'
assert "com.godot.game.GodotApp" in badging, 'native Godot activity missing'
assert "native-code: 'arm64-v8a'" in badging, 'arm64 export required'
if args.version_code is not None:
    assert f"versionCode='{args.version_code}'" in badging
    assert f"versionName='1.0.{args.version_code}'" in badging
manifest = subprocess.check_output([str(tools / 'aapt'), 'dump', 'xmltree', args.apk, 'AndroidManifest.xml'], text=True)
assert re.search(r'android:screenOrientation.*\(type 0x10\)0xb', manifest), 'sensor landscape required'
assert 'android.hardware.vulkan.version' in manifest, 'Vulkan capability declaration missing'
print('Verified signed native arm64 APK: al.tukehub.rruga, sensor landscape, readable manifest')
