![Overtune 3](assets/banner.png)

# Overtune 3

Overtune is a desktop application for designing digital filters, analyzing signal response, simulating audio, and exporting filter implementations. It combines a Qt 6 interface with a standalone C++20 DSP library.

[Downloads](https://github.com/shadcy/overtune3/releases) · [Source](https://github.com/shadcy/overtune3) · [Report an issue](https://github.com/shadcy/overtune3/issues)

## Features

- Design low-pass, high-pass, band-pass, and band-stop IIR filters using Butterworth, Chebyshev I/II, elliptic, and Bessel responses.
- Design linear-phase FIR filters (windowed sinc, order up to 256) with 16 windows: rectangular, Hann, Hamming, Blackman, Kaiser, Bartlett, Bartlett-Hann, Blackman-Harris, Nuttall, Blackman-Nuttall, flat top, Gaussian, Tukey, Lanczos, cosine, and Dolph-Chebyshev.
- Inspect magnitude, phase, group delay, pole-zero, impulse, and step responses.
- Import WAV and CSV data, generate test signals, and compare filtered audio.
- Export filter implementations as C, C++, Python, JSON, MATLAB/Octave, Rust, WebAudio JavaScript, or CSV.
- Use the interface in dark or light appearance.

## Windows Installation

1. Download `Overtune3-Setup-x64.exe` from [GitHub Releases](https://github.com/shadcy/overtune3/releases).
2. Run the installer. Choose an installation folder when prompted.
3. Select **Launch Overtune 3** on the final page.

The installer creates Start Menu and desktop shortcuts and registers the app in Windows Installed Apps. To remove it, use **Settings > Apps > Installed apps** or the Start Menu uninstall shortcut.

The `overtune3-windows-x64.zip` release is a portable distribution. Extract the complete folder and run `ot3.exe` from its `bin` directory.

## Build

### Requirements

- CMake 3.24 or newer
- Qt 6.4 or newer with Core, Gui, Qml, Quick, QuickControls2, Multimedia, and Network
- A C++20 compiler

### Windows

Configure with a Qt installation matching the selected compiler, then build with MSVC:

```powershell
cmake -S . -B build -DCMAKE_PREFIX_PATH="C:/Qt/6.7.2/msvc2019_64"
cmake --build build --config Release --parallel
```

To create Windows distribution packages, run `scripts\package_windows.bat` after building. NSIS must be installed and `makensis` available on `PATH`. Packages are written to `dist`; GitHub-ready setup and portable archives are also copied to `dist/release`.

### Linux and macOS

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

## DSP Library

The `dsp/` library does not depend on Qt and can be included in another CMake project:

```cmake
add_subdirectory(overtune3/dsp)
target_link_libraries(MyApplication PRIVATE dsp)
```

## Project

Developed and maintained by [@/shadcy](https://github.com/shadcy). Contributions and issue reports are welcome through the [GitHub repository](https://github.com/shadcy/overtune3).

Licensed under the MIT License. See [LICENSE](LICENSE).
