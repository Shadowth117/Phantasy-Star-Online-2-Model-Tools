Model Export Usage:
1. Load model
2. Pick settings
3. Hit export

Checkbox notes:
Player Model (Add UNRMS) - Adds in extra data only found in player models. Not required to function correctly ingame. This is calculated via NIFL Tools (ＮＩＦＬツール)'s method, which is inaccurate, but seems to be fine.
White Diffuse Tint - Because Max makes materials have a gray diffuse by default, ingame models may look less saturated in color if this is unchecked.
Average UNRM Normals - Blends a model's normals between vertices that would match as UNRMs (same position in space). This may fix unwanted hard edges or dark spots on models ingame.
Use Face Normals - Recalculates a model's normals based on the faces of the model rather than the model's defined normals. This may help fix some of the issues defined in the line above.
Zero Out Bounds - Uses 0 for model boundaries; a hack for special cases.
Make Mesh Dummies - Used to recreate the process in which sega creates dummies of existing scene models and adds them to the skeleton. Not important, probably, but a feature.
Basewear culling hack - since layered wear is weird, certain things are set to 0 where they would normally have another value. This option applies that.

Y-Z Axis Flip and Rescale are also used for export and should be ticked to match settings used for import. For custom models, if your model is based on Z axis being up (3ds Max's default), this should be used. Scale in PSO2 is also quite small as Rescale implies. 

Users may set these properties on a mesh to further customize export: 
Setting "FaceNormals" User Defined Property on an object will cause it to forcibly use its face normals for export rather than its existing normals if true or never use its face normals if false.
Setting "AverageNormals" User Defined Property on an object will cause it to forcibly average its normals per vertex if true or to avoid averaging its normals if false.

***To specify player model textures, instead a user should set "[pl]" without quotes in the material name which will cause texture names to be automatically corrected on export. Add (0100p,0100) as well to use the default player shader!***

Users may set materials to use specific shaders to use specific shaders by specifying in a material name in parenthesis the shader's 2 ids separated by a comma, ex: (0200p,0200) or (0100p,0100). Shader ids can be found within existing aqp files. Materials are assumed to be Standard materials (these are the default materials 3ds Max will use.)
The shader specified determines what your texture order should be and should be based on what is observed in the original usage. For example, 0200p,0200 should have:
-DXT5 _d texture in the diffuse color slot
-DXT1 _t texture in the specular color slot
-DXT1 _s texture in the specular level slot
-DXT1 _n texture in the glossiness slot

PSO2 materials used to support a maximum of 4 texture maps normally and the order is important. PSO2 NGS materials can potentially support 16. Texture ids will be 1-16 downward starting from the diffuse map.

In lieu of a shader selection, the default shader will be "0301p,0301" which expects textures in order:
-DXT5 _d texture in the diffuse color slot
-DXT1 _s texture in the specular color slot
-DXT1 _n texture in the specular level slot

Note that the _d etc. may be required in the texture filename for it to work properly ingame.

Textures can be assigned to be used on specific uv channels on a model by setting said texture's Map Channel within its settings to the desired value. Note that 99 should be used for environment maps.
Map channel shenanigans should probably be left alone unless you've done some research on them and how they interact with shaders etc.

A user may specify blending types for a material by writing them in the material name in curly brackets. For example, {opaque}, {blendalpha}, {add}, or {hollow}

Model Export considerations
-Texture order, blend type, and shader type are very important to prevent crashes and make the model look appropriate ingame.
-While the script will automatically handle this, PSO2 expects models separated by material and with a maximum of 16 bones per mesh. Export times may be longer if this is not done beforehand.
-Expect longer export times when there's more meshes in the scene. Maxscript exporting is bottlenecked, but the alternatives aren't particularly great and can raise compatibility issues.
