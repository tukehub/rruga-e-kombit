# Building with the optional licensed car

The supplied CGTrader car is not included in this public repository. Its
license permits game use subject to its terms and limits redistribution of the
standalone model. Keep the original, converted model, staged payload and key
out of Git and public build artifacts. The original source is **Sports Racing
Car Low Poly Game Ready** by smileypixelstudio:
https://www.cgtrader.com/free-3d-models/car/sport-car/sports-racing-car-low-poly-game-ready

After obtaining the licensed GLB, prepare and stage it locally:

```sh
blender -b -t 2 --python tools/import_cg_sport.py -- /path/to/source.glb work/private_sport_normalized.glb
python3 tools/stage_private_car.py work/private_sport_normalized.glb
godot --headless --path godot --editor --import
```

`work/private_sport.key`, the normalized model, and `godot/assets/private_car/`
are ignored by Git. Do not share those files. Use
`python3 tools/run_tests.py --godot godot` before exporting. When the local
Android SDK and release signing configuration are available, export with an
unused, monotonically increasing Android version code:

```sh
python3 tools/export_android.py --version-code VERSION --require-private-car
```

The flag checks that the encrypted payload and local key script are staged,
avoiding an accidental build with the fallback vehicle. A fresh GitHub Actions
checkout has no private asset and intentionally uses the open fallback car;
future CI builds need an access-controlled provisioning mechanism to include
the licensed car. Merely pushing the public source does not provide it.

The staged model is encrypted and the key script is exported as Godot bytecode
to discourage casual extraction. Because a running client must contain the key,
this cannot prevent determined reverse engineering. Verify the asset terms and
distribution arrangements for each release; encryption is not a legal or
security guarantee.
