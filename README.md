# 1943 - for MEGA65

**1943: The Battle of Midway** is Capcom's 1987 vertically scrolling shoot-'em-up arcade game and the sequel to *1942*. The player pilots a P-38 Lightning through aerial and naval battles in the Pacific, collecting power-ups and fighting enemy aircraft and warships.

This project ports the **1943** FPGA core from **Jotego's JTCORES project** to the MEGA65.

The upstream core used as the basis of this port is:

[Jotego JTCORES - 1943](https://github.com/jotego/jtcores/tree/master/cores/1943)

The original FPGA implementation, JTFRAME infrastructure and associated supporting cores are the work of **Jotego and the JTCORES contributors**.

The MEGA65 port uses the [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65) framework and [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for MEGA65 integration, including FAT32 ROM loading and the on-screen menu.

## Credits

*1943: The Battle of Midway* was originally developed and released by **Capcom** in 1987.

This MEGA65 core would not exist without the work of **Jotego and the JTCORES contributors**. The MEGA65 version is based on the JTCORES 1943 implementation linked above.

Additional credit goes to **sy2002, MJoergen and the MiSTer2MEGA65 contributors** for the MiSTer2MEGA65 framework and QNICE-FPGA integration used by this port.

## How to install the core

### 1. Obtain the 1943 ROM set

You need a compatible MAME **1943: The Battle of Midway** ROM set, typically:

```text
1943.zip
```

ROM files are **not included** with this repository. Some MAME sets may require additional parent ZIP archives to supply all the chips used by the converter. You can pass multiple ZIP files to any of the scripts; later archives override earlier files of the same name.

The scripts read ROM chips directly from the ZIP files. **Do not extract the ZIPs.** Missing chips or unexpected generated image sizes cause conversion to stop.

### 2. Generate the MEGA65 ROM images

Three independent ROM conversion scripts are provided:

- `1943.py` — Python 3 (standard library only)
- `1943.sh` — Linux/macOS Bash, using Perl with `IO::Uncompress::Unzip` and `Compress::Raw::Zlib`
- `1943.ps1` — Windows PowerShell, using .NET ZIP support

**Each script performs the complete conversion itself.** The Bash and PowerShell scripts do not call Python.

Place your chosen script and the MAME ZIP file(s) in the project directory.

#### Windows / PowerShell

```powershell
.\1943.ps1
```

If Windows blocks the downloaded script, unblock it first:

```powershell
Unblock-File .\1943.ps1
```

To supply an additional parent ROM archive:

```powershell
.\1943.ps1 1943.zip parent.zip
```

#### Linux / macOS

Make the Bash script executable if necessary, then run:

```bash
chmod +x 1943.sh
./1943.sh
```

To supply an additional parent ROM archive:

```bash
./1943.sh 1943.zip parent.zip
```

The Bash script requires `bash`, `perl`, and the Perl modules `IO::Uncompress::Unzip` and `Compress::Raw::Zlib`.

#### Python

```bash
python3 1943.py 1943.zip
```

To supply an additional parent ROM archive:

```bash
python3 1943.py 1943.zip parent.zip
```

Python 3 is required; no third-party Python packages are needed.

#### Output directory

All three scripts create the following directory by default:

```text
arcade/1943
```

You can override the destination using `-o` (Bash/Python) or `-Out` (PowerShell):

```bash
./1943.sh -o /path/to/output
python3 1943.py 1943.zip -o /path/to/output
```

```powershell
.\1943.ps1 -Out 'D:\ROMs\1943'
```

The conversion follows the JTCORES ROM assembly and interleaving rules, including byte swapping and these required graphics transformations:

| ROM region | Graphics layout |
|---|---|
| Object/sprite (`obj`) | `hvvvvxx` sorted |
| Map 1 (`map1`) | `hvvvx` sorted |
| Map 2 (`map2`) | `hvvvx` sorted |
| Scroll 1 (`scr1`) | Unsorted |
| Scroll 2 (`scr2`) | Unsorted |

**Important:** These sorted ROMs require the matching FPGA address remapping in `main.vhd`. All three scripts apply sorting automatically. There is no unsorted option.

### 3. Generated ROM files

The scripts generate these nine files:

| File | Size (bytes) |
|---|---:|
| `1943_main.rom` | 163840 |
| `1943_sound.rom` | 32768 |
| `1943_char.rom` | 32768 |
| `1943_map1.rom` | 32768 |
| `1943_map2.rom` | 32768 |
| `1943_scr1.rom` | 262144 |
| `1943_scr2.rom` | 65536 |
| `1943_obj.rom` | 262144 |
| `1943_prom.rom` | 7168 |

Each script prints the generated file sizes and CRC32 checksums. Check for missing input files or unexpected image sizes before copying the ROMs to the SD card.

### 4. Copy the ROMs to the MEGA65 SD card

Copy the nine generated ROM files to:

```text
/arcade/1943
```

Also copy the supplied 1943 configuration file to that directory. The configured settings file is:

```text
/arcade/1943/1943cfg
```

Both the bottom SD card slot and rear SD card slot can be used. As with other MEGA65 cores, the rear SD card takes precedence when both are present.

Install the 1943 `.cor` file using the normal MEGA65 core installation procedure.

## Game setup

Press the **HELP** key while the core is running to open the MiSTer2MEGA65 on-screen menu.

The menu provides display, control and DIP-switch settings for the core.

### Video output

1943 is a vertically oriented arcade game. The MEGA65 port uses the MiSTer2MEGA65 rotation/frame-buffer support to display the game in the correct orientation.

The display menu includes **Rotate screen 90**, HDMI display settings, CRT emulation, and VGA options. The VGA menu provides standard output, retro 15 kHz with separate HS/VS, and retro 15 kHz with CSYNC.

The arcade **Flip Screen** DIP is separate from the MEGA65 screen-rotation control. The framebuffer rotation's `flip` input is fixed at `0`; the game's Flip Screen setting is handled through its DIP switches.

### Controls

1943 uses an eight-way joystick and two action buttons:

- **Fire**: Shoot enemy aircraft and ships.
- **Special attack**: Use the game's special weapon/attack.

The MEGA65 joystick ports provide directional control. The second action button can use the joystick POTX/POTY second-button input, as configured in the on-screen menu. Keyboard controls are also provided: **Z** and **X** for the two fire buttons, **1** or **2** to start, and **5** or **6** to insert credits.

### DIP switches

The on-screen **Game Setup → DSW A & B** menu exposes the original arcade DIP switches:

| Switch | Setting |
|---|---|
| SW1-1 | Service Mode |
| SW1-2 | Screen Stop |
| SW1-3 | Flip Screen |
| SW1-4 | 2 Player Game |
| SW1-5 to SW1-8 | Difficulty 1–4 |
| SW2-1 | Demo Sounds Off |
| SW2-2 | Continue Off |
| SW2-3 to SW2-5 | Coin B |
| SW2-6 to SW2-8 | Coin A |

**Note:** The menu deliberately labels two switches **Demo Sounds Off** and **Continue Off** to reflect their actual active state. **Flip Screen** is enabled by default for the correct display orientation in this port.

If saved menu settings are enabled, an existing `/arcade/1943/1943cfg` can override newly compiled menu defaults. Reset or regenerate that configuration when changing defaults.

## Upstream projects

This port builds upon several open-source FPGA projects:

- [Jotego JTCORES](https://github.com/jotego/jtcores)
- [1943 core in JTCORES](https://github.com/jotego/jtcores/tree/master/cores/1943)
- [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65)
- [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA)

Please support the upstream projects and developers whose work made this MEGA65 port possible.

## Status

This is an initial MEGA65 port of the 1943 core. The graphics layers, screen orientation, and DIP-switch behaviour have been brought up and verified during port development.

Please report MEGA65-specific problems through the 1943 MEGA65 project rather than to the upstream JTCORES project, unless the problem has also been reproduced on the original upstream implementation.

## Known issues

No confirmed 1943-specific issues are listed here yet.
