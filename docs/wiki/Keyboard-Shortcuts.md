# Keyboard Shortcuts

## Histology Browser

Press **F1** in the browser for this list. The browser generates it from the same table that binds
the keys (`@HistologyImageBrowser/keyBindings.m`), so the two always agree.

Every shortcut except `Esc` and `F1` uses a modifier, so typing in the search box never triggers
one. `Ctrl+A`, `Ctrl+Z`, `Ctrl+Home`, `Ctrl+End`, `Ctrl+Left` and `Ctrl+Right` go to the text field
instead when a field was the last thing you clicked.

### Sections

| Keys | Action |
|---|---|
| `Ctrl+Down` or `Ctrl+Right` | Next section |
| `Ctrl+Up` or `Ctrl+Left` | Previous section |
| `Ctrl+Home` / `Ctrl+End` | First / last section |
| `Ctrl+A` | Select every section passing the filters |
| `Ctrl+F` | Jump to the search box |
| `Ctrl+Shift+R` | Clear every filter |
| `Ctrl+L` | Load the dataset |
| `Ctrl+Shift+E` | Export the selected sections to the workspace |

### Review

| Keys | Action |
|---|---|
| `Ctrl+M` | Mark the selected sections measured, or clear them if all are |

### Line ROI

| Keys | Action |
|---|---|
| `Ctrl+N` | Add another ROI to this section |
| `Ctrl+Shift+N` | Move to this section's next ROI |
| `Ctrl+E` | Start or finish editing the chosen ROI of the marked section |
| `Ctrl+D` | Draw a new line over the marked section |
| `Ctrl+S` | Save the ROI and remeasure its profile |
| `Ctrl+Z` | Discard unsaved ROI changes |
| `Esc` | Leave ROI editing |
| `Ctrl+B` | Find the brain surface in the profile and mark it |
| `Ctrl+Shift+B` | Click on the image to mark the brain surface |

### Display

| Keys | Action |
|---|---|
| `Ctrl+1` | Line ROI overlay on or off |
| `Ctrl+2` | Sampling band on or off |
| `Ctrl+3` | Shade the ROI by intensity, or not |
| `Ctrl+4` | Brain surface marks on or off |
| `Ctrl+Shift+D` | Hide or show the lookup and catalog column |
| `Ctrl+Shift+P` | Hide or show the display controls above the tiles |
| `Ctrl+H` | Hide or show the data column and the display row together |
| `Ctrl+O` | Redraw the view in a normal figure |
| `Ctrl+P` | Export the view to an image file |
| `Ctrl+Shift+F` | Open the folder holding the marked section's image |

### Help

| Keys | Action |
|---|---|
| `F1` | Show the shortcut list |

## Interactive tools

The keys for `InteractiveAffineOverlay`, `InteractiveRotator`, `ThresholdAdjuster` and
`histologyLabeller` are listed with each tool on
[Image Processing Tools](Image-Processing-Tools). In `InteractiveAffineOverlay` and
`histologyLabeller`, `?` prints the list to the Command Window.
