## Roll For SoM
### Ignore SR and allow everyone to roll
---
If the item is SRed, the addon will only watch rolls for players who SRed. However, if you want everyone to roll, even if the item is SRed, use /arf instead of /rf. "arf" stands for "All Roll For".

### Create a Soft Res list at https://raidres.top (1.12.1) or https://softres.it (2.5.2).
---
Ask raiders to add their items.
When ready, lock the raid and click on RollFor export (raidres.top) or Gargul Export (softres.it) button.
Click on Copy RollFor data to clipboard button.
Click on the minimap icon or type /sr.
Paste the data into the window.
Click Import!.
The addon will tell you the status of SR import.
Hovering over the minimap icon will tell you who did not soft-res.

### Export Raid CSV
---
Click the minimap icon or type `/sr`.
Click `Export Raid`.
This stores the current raid export in `WTF/Account/<account>/SavedVariables/RollFor.lua` under `RollForDb.lastRaidExport`.

Requirements:

- Python 3
- No third-party packages are required
- `pandas` is not needed

Install Python:

- Windows: install Python 3 from https://www.python.org/downloads/windows/ and enable `Add python.exe to PATH`
- macOS: install Python 3 from https://www.python.org/downloads/macos/ or with Homebrew: `brew install python`
- Linux: install Python 3 from your package manager, for example `sudo apt install python3`

Check that Python is available:

```bash
python --version
```

or:

```bash
python3 --version
```

To convert that export into CSV, go to the addon `scripts` folder and run:

```bash
python export_last_raid_csv.py ELITZIA
```

On Windows, you can also use:

```bat
scripts\export_last_raid_csv.bat ELITZIA
```

Or double-click `scripts/export_last_raid_csv.bat` and enter the account name when prompted.

This will find `WTF/Account/<account>/SavedVariables/RollFor.lua` automatically and write:

```text
RollFor/scripts/lastRaidExport.csv
```

CSV columns:

```text
ID,Item,Boss,Attendee,Class,Specialization,Comment,Date (GMT),SR+
```

### csr
---
do /importcsrmod
