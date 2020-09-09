
Before you ask, YES, this could potentially import characters in their entirety. It imports character models fine at the moment, but assembling everything is an issue. 
If people want to help with reverse engineering a bit to figure things out (texture color blending, the particle format, etc.), I'd be happy to work on an import script for that. 
As is, you can import all of the player stuff separately (Though UV maps for layered wear and cast parts will expect a larger, combined texture of the textures of all parts as the game creates itself in memory).

Model Import Usage:
1. Extract a model from its PSO2 archive (use deicer or repacker for this)
2. Drag the PSO2 Model Tool script into 3ds max, select the options you want (pso2 bones are needed for rigging clearly), hit import, and select the .obj and its .aqn.
***Please note the import is SIGNIFICANTLY longer with skinning and precise normals due to how Maxscript works. For static elements and if you don't care about normals, uncheck these!*** 
3. For larger models this may take a few minutes (Yamato is the longest I've seen, but it works; just be patient), but you're done!

Model Export (Not recommended right now):
See AQPExportReadme.txt. I'm not proud of how this works at the moment. It will take a long time and can devour 16gb+ of RAM on bigger models. Limitations in how Maxscripting works create ugly bottlenecks with this. I've begun the process of writing it to be faster and not require stupid amounts of RAM, but it will take some time. In the meantime, it does at least work to some degree, albeit very slowly.

AQN Skeleton Export (Automatically Exported with a model export!):
***ONLY EXPORT WITH ONE ROOT NODE in scene***
That aside, for best results please match and follow patterns of ingame hierarchy user defined variables etc. although these are not necessary for a working export.

AQM Animations:
See AQM (Animation) Export Readme. You must have a skeleton in the scene to import an animation. However, you're welcome to import mismatched animations for your amusement.

Note:
This works for terrain .trp models, .trm animations, and .trn bones too, if you wanted to get a terrain model or whatever.

Anyways, if anyone does anything cool with this stuff, I'd love to know about it.

PSO2 modding discord link is here for those who want to bug me more directly:
https://discord.gg/Kds4V4Z