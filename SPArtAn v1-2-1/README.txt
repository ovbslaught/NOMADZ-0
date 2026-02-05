=======
SPARTAN
=======
Small Pixel ART ANimator
By Paul Jeffries

Uses the IconBitmapEncoder by Herbert Lausmann:
http://www.codeproject.com/Articles/687057/A-High-Quality-IconBitmapEncoder-for-WPF

Everything else (c) Paul Jeffries 2013-2014

SPARTAN is freeware.  For information, news and updates, visit:
http://www.vitruality.com

SHORTCUT KEYS:
D: Draw | Pick Colour
L: Line | Pick Colour
C: Circle | Ellipse
F: Flood Fill | Pick Colour
S: Select | Move
H: Set Hot Spot
Delete: Clear selection (only when select tool is active)


GETTING STARTED:
- The tools in SPARTAN have different functions assigned to left and right mouse buttons.  For example, the Draw tool draws pixels using the left mouse button and picks colours with the right.  The text in the top right-hand corner of the viewport shows the currently active functions.
- Left-click on the panel showing the current colour to bring up the colour picker window.  This has many different ways to choose the colour you want - use whichever way you like most!
- Below the current colour panel is the palette.  You can add a blob of the current colour using the left mouse button, or pick the colour under the mouse with the right mouse button.  Hold down the shift key and right-click on a colour to mix with the current colour.
- Above the colour panel is the Sprite tree.  Click on the arrow next to each entry to open it and see its contents.  The hierarchy is Sprite->Animations->Directions->Frames->Layers.  Right click on an entry to see a context menu of modification options relevant to that entity type.


USAGE NOTES:
- SPARTAN is intended for small, animated, limited-colour pixel art.  It's not really optimised for large pictures so I don't recommend it for use touching up your holiday snaps.
- It is possible to link frames and layers between different sprites.  Note however that the link is only active when both sprites are open in the program at once.  If you open a linked sprite without the original then you can modify it independently, however any local changes will be overriden by the master file should that also be opened at the same time.


SPRITESHEET MARKUP FORMAT:
SPARTAN outputs a markup text file along with the compiled spritesheet image.  The first line in the file will be the name of the spritesheet image file to which the markup relates.  Following that are the positions of the sprites contained in the spritesheet in the following format:

[SPRITE NAME]
[ANIMATION NAME]
[DIRECTION ANGLE (Degrees)]
[FRAME NUMBER]
[FRAME LEFT POSITION]	[FRAME TOP POSITION]	[FRAME WIDTH]	[FRAME HEIGHT]	[FRAME HOT-SPOT X OFFSET (Optional)]	[FRAME HOT-SPOT Y OFFSET (Optional)]

The values in the frame data are tab-separated.  Coordinates may be expressed in either pixel units or as a proportion of the overall image size.


CHANGELOG:

version 1.1.0:

Bugs fixed:
- Circle/Ellipse tools were not updating the combined preview image after use
- New Sprite->Custom will no longer create a new sprite if the size selection window is closed without pressing OK
- Flip X and Flip Y tools were incorrectly calculating flip bounds - was resulting in a one-pixel offset to the result
- Box selection is now limited to selected layer area
- Prevented mouse movement drawing when the mouse button was not initially clicked over the canvas
- Clearing selection using the delete key was not being correctly triggered
- Layout rounding was causing offset layers and selection areas to be displayed in slightly the wrong position

New Features:
- Display option to show bounds of selected Layer
- Showing frame border can now be toggled on or off
- Layers can now be assigned X and Y offsets from their parent frame
- Frame and Layer cropping/resizing
- Support for brushes added
- New round brush
- New square brush
- New 'rough' brush
- New brush selection/editing interface above colour selection
- Colour selection now has patchwork background to make colour transparency more obvious
- New ability to import/batch import images to be used as custom brushes
- Image brushes can use original image colours or use the image as a mask for the current colour
- Dithering, with a library of 12 different dithering patterns to choose from
- Default shortcut keys added for primary tools (see Readme for key bindings).
- Frame hot-spot support added
- Hot-spot data can optionally be written to output spritesheet markup
- Tooltips added to spritesheet generator options
- Option to display current frame with the view centred on its hotspot (for animation preview - not recommended for editing)
- Onion skinning displays next/previous frame using the differential offset between hot-spots
- Onion skinning now 'wraps around' when the active frame is the first or last in the animation
- Crosshair overlay for thick brushes
- Performance improvements for larger canvasses
- Colour picker now remembers and restores the last-used tab

version 1.2.0

Bugs fixed:
- Brush crosshair only shows up when the equipped tool uses brushes

New Features:
- Ability to generate spritesheet with missing non-vertical directions automatically taken as mirrors of existing directions
- Selection system re-written to enable non-rectangular selection areas.

New PROCJAM Features:
- New Selection Menu with different fill options
- New Colour Range system and editing interface for specifying colour gradients
- New Generator system for procedurally creating pixel art tiles
- Visual editor for building generation algorithms
- A library of modular generation components


version 1.2.1

Bugs fixed:
- Crash on startup on computers with certain regional settings
- Auto generation was not triggering when new components were added

New Features:
- Toolbar button to toggle generator sidebar