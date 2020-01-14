For those bothered about it being for 3ds max, remember that you can get a FREE student version here: https://www.autodesk.com/education/free-software/3ds-max

Let me know about any bugs you might run into, but I feel like this could be very useful to people.

And before you ask, YES, this could potentially import characters in their entirety. It imports character models fine at the moment, but assembling everything is an issue. 
If people want to help with reverse engineering a bit to find where to get file references from a character creator file, where to pull filenames from, and how to dehash them, I'd be happy to work on an import script for that. 
As is, you can import all of those things separately (Though UV maps for layered wear and cast parts will expect a larger, combined texture of the textures of all parts as the game creates itself in memory).

Model Import Usage:
1. Extract a model from its PSO2 archive (use deicer or repacker for this)
1b. If using repacker, strip the header either manually in hex or with the stripheader power script provided
2. Put the aqo file you get into a folder with the NIFL Tool and run the ObjectExportBatch script (will process all aqos in the folder)
3. Drag the ImportVColorObj script into 3ds max, select the options you want (pso2 bones are needed for rigging clearly), hit import, and select the .obj and its .aqn.
4. For larger models this may take a few minutes (Yamato is the longest I've seen, but it works; just be patient), but you're done!

AQN Skeleton Export (Automatically Exported with a model export!):
***ONLY EXPORT WITH ONE ROOT NODE in scene***
That aside, for best results please match and follow patterns of ingame hierarchy user defined variables etc. although these are not necessary for a working export.

Note:
This works for terrain .trp models and .trn bones too, if you wanted to get a terrain model or whatever.

Anyways, if anyone does anything cool with this stuff, I'd love to know about it.

PSO2 modding discord link is here for those who want to bug me more directly:
https://discord.gg/Kds4V4Z