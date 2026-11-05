# zxp3

A Sinclair ZX Spectrum +3 FPGA implementation.

This is an independent implementation that does not rely on any FPGA board. Check out my other repositories for implementations specific to different FPGA boards, which use this repository as a submodule.

Uses T80 from mist-devel: https://github.com/mist-devel/T80
And TZX player by György Szombathelyi

### Implements a standard ZX Spectrum +3 computer and the follwing hardware:

- Turbosound
- Tape loading
- Floppy disk drives
- ZXMMC/DIVMMC disk images
- Dual Kempston Joystick with two fire buttons (ZX-Next ports)
- K-Mouse

A ROM file must be copied to the root directory of the SD card as "zxp3.rom". It is a 72 KB file containing the Spectrum ROM (64 KB) and the esxDOS ROM (8 KB). You can change it at any time via the on-screen display (OSD) menu (accessed by pressing the F12 key).

Any ROM compatible with the +3 is supported, such as the standard Amstrad ROM and Garry Lancaster’s +3e ROM.
If you are going to use Garry Lancaster's +3e ROM, you need to disable the DivMMC in the OSD.


### Useful links

Garry Lancaster's +3e ROM:
https://worldofspectrum.org/zxplus3e/

desUBIKado's Mar Océana image file for +3e:
http://www.retrowiki.es/viewtopic.php?f=110&t=200037816

Octocom's Workbench +e3:
https://octocom.speccy.org/workbench_es.html
