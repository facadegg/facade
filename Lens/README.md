# Lens

Lens implements various virtual camera effects and integrates with the host system using Facade.

| Feature   | Description                                          | Status |
|-----------|------------------------------------------------------|--------|
| Face Swap | This swaps out faces so they look like someone else. | ✅      |

## Build

| Option              | Description                                               |
|---------------------|-----------------------------------------------------------|
| LENS_FEATURE_ONNX   | Use cross-platform ONNX models                            |
| LENS_FEATURE_BUNDLE | Bundle the executable into a macOS or Windows application |

## Usage

Lens is bundled into the Facade app, through which end-users will use it. For testing, you might want to run it directly:

```bash
${CMAKE_BINARY_DIR}/lens                          \
  --dst Facade                                    \
  --frame-rate=30                                 \
  --face-swap-model=/opt/facade/Ewon_Spice.mlmodel\
  --root-dir=/opt/facade 
```

_Note: You will need to turn off LENS_FEATURE_BUNDLE to run lens from the command-line. This is because hardened runtime on macOS will not allow the executable to run outside of the Facade app._