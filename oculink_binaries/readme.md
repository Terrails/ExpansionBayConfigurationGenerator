# OCuLink

This folder contains the EEPROM binaries for the OCuLink board.

## Flashing

### Using `framework_tool`

**NOTE:** It seems like there is some issue with framework_tool writing malformed data to the EEPROM. Make sure to check the written data before rebooting the laptop.

```bash
framework_tool --flash-gpu-descriptor-file path/to/eeprom.bin
```

Then verify using

```bash
framework_tool --expansion-bay
```

If there is any kind of error. You might have to turn the EEPROM back on using ECTool before trying out the alternative using `eeprom_write.ps1`. Malformed data could have turned off the power to the EEPROM.

```bash
ectool gpioset gpu_3v_5v_en 1
```

### Using `eeprom_write.ps1`

This requires Windows, but the script should be easy enough to adapt to Bash for usage on Linux.

Make sure to put `ectool.exe` in the same directory as the script. Then open PowerShell and run the script

```powershell
.\write.ps1 .\eeprom.bin
```

You can also specify `-verifyOnly` to only verify the written data. For more detailed logging use `-Verbose`.

Verify the data using `framework_tool`.

```bash
framework_tool.exe --expansion-bay
```

## Generation

To generate these OCuLink binaries yourself, compile the program and run it using the `-l` and `-g` parameters. The value provided to `-g` depends on how many PCIe lanes you want, `0` for 1x8, `1` for 1x4 and `2` for 2x4. Example of PCIe x8 with a provided serial number:

```bash
gpu_cfg_gen -l -g 0 -s FRAOCULINKTERR1X8I -o eeprom.bin
```
