ClearListener()
FileIn @"include\MaxScriptExtensions\FileStreamReader.ms"
FileIn @"include\MaxScriptExtensions\FileUtils.ms"
FileIn @"include\UnusedBoneRemover.ms"
FileIn @"include\AQNBoneImportv1.4.ms"

if ghostingDoneAlready == undefined then
(
	--Borrowed from Oleksandr Kramer's post here: https://forums.cgsociety.org/t/interface-updates-while-busy/1495163/21
	fn DisableProcessWindowsGhosting =
	(
		if classof (dotnet.GetType "DisableWindowsGhosting")!=dotNetObject do
		(
			local source = StringStream ("
			using System.Runtime.InteropServices;

			public class DisableWindowsGhosting
			{
				[DllImport(\"user32.dll\")]
				public static extern bool DisableProcessWindowsGhosting();
			}")

			compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
			compilerParams.ReferencedAssemblies.Add("System.dll");
			compilerParams.GenerateInMemory = on
			csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
			compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(source as String)
			flush source
			close source
			if (compilerResults.Errors.Count > 0 ) then
			(
				local errs = stringstream ""
				for i = 0 to (compilerResults.Errors.Count-1) do
				(
					local err = compilerResults.Errors.Item[i]
					format "Error:% Line:% Column:% %" err.ErrorNumber err.Line err.Column err.ErrorText to:errs
				)
				format "%" errs
				undefined
			)
			else
			(
				compilerResults.CompiledAssembly.CreateInstance "DisableWindowsGhosting"
			)
		)
	)
	
	DisableWindowsGhosting = DisableProcessWindowsGhosting()
	DisableWindowsGhosting.DisableProcessWindowsGhosting()
)
ghostingDoneAlready = true

(
SKN_UnNRMVert =  skinOps.unNormalizeVertex
SKN_RepWeights = skinOps.ReplaceVertexWeights
						
importLOD = false
precisionNormals = true

struct matID_UV
(
	matID,
	uvIds
)
struct matInfo
(
	mateIndex,
	tsetIndex,
	shadIndex
)

fn setMatID obj id = 
(
	for f in 1 to obj.numfaces do 
	(
		setFaceMatID obj f id
	)
	update obj
)

fn SetupMaterials model filepath meshNum newMaterial matInfoArray =
(	
	startPath = getFilenamePath(getThisScriptFilename())
	dotnet.loadAssembly (startPath + @"\include\AquaLib\AquaModelLibrary.dll")
	aquaMethods = dotnetclass "AquaModelLibrary.AquaObjectMethods"
	modelMat = model.mateList.item[model.meshList.item[meshNum].mateIndex]
	matName = modelMat.matName.GetString();
	
	if meshNum != 0 then
	(
		newMaterial.numsubs += 1
	)
	matId = newMaterial.numsubs
	
	--Get extra info that we place in the material name
	shadIndex = model.meshList.item[meshNum].shadIndex
	shadSet = aquaMethods.GetShaderNames model shadIndex
	
	--Get opacity type
	opacityType = modelMat.alphaType.GetString();
	
	--Assemble and set name
	matName = "(" + shadSet.item[0] + "," + shadSet.item[1] + ")" + "{" + opacityType + "}" + matName
	newMaterial[matId] = standard name:matName
	
	--Set 2-sided flag
	rendIndex = model.meshList.item[meshNum].rendIndex
	if model.rendList.item[rendIndex].twosided > 0 then
	(
		newMaterial[matId].twoSided = true
	)
	
	--This may be necessary if NGS models ever use more than 11 textures... Blinn shaders do NOT support more nicely
	newMaterial[matId].shaderType = 3 -- MultiLayer. For 0xC32+ variants of models, texture counts can theoretically hit 16. While only 7 have been observed ever, max, this should account for the possibility since blinn shaders, the default, do not.
	
	--Might be BGRA order? If so, fix later
	newMaterial[matId].diffuse = color (modelMat.diffuseRGBA.X * 255) (modelMat.diffuseRGBA.Y * 255) (modelMat.diffuseRGBA.Z * 255)
	newMaterial[matId].opacity = (modelMat.diffuseRGBA.W * 100.0) 

	tsetindex = model.meshList.item[meshNum].tsetIndex
	tset = aquaMethods.GetTexListNames model tsetindex
	
	--Loop through and set texture maps. Set starting at 2 so we can at least have a passable diffuse/albedo map set in for previewing.
	--GIven the many shader setups, it's not realistic to handle those and all texture ordering/combinations so this will have to do.
	for i = 0 to (tset.Count - 1) do
	(
		map = bitmapTexture filename: (filepath + tset.item[i]) name:((getFilenameFile tset.item[i]) + ".dds")
		uvChan = model.tstaList.item[model.tsetList.item[tsetIndex].tstaTexIDs.item[i]].modelUVSet
		--Handle negative channel since max doesn't like that...
		if uvChan == -1 then
		(
			uvChan = 98
		)
		map.coords.mapChannel = uvChan + 1
		newMaterial[matId].maps[i + 2] = map
		if i == 0 then
		(
			newMaterial[matId].mapEnables[i + 2] = true
			if (getFiles (filepath + tset.item[i])).count != 0 then
			(
				showTextureMap newMaterial[matId] map true
			)
		) else
		(
			newMaterial[matId].mapEnables[i + 2] = false
		)
	)
		
	matId
)

fn importTCB fileName useAutoSize autoSizeValue useYZFlip =
(
	with undo off
	(
		startPath = getFilenamePath(getThisScriptFilename())
		currentPath = getFilenamePath(fileName)
		meshName = getFilenameFile(fileName) + getFilenameType(fileName)
		dotnet.loadAssembly (startPath + @"\include\AquaLib\AquaModelLibrary.dll")
		aquaUtil = dotNetObject "AquaModelLibrary.AquaUtil"
		aquaUtil.ReadCollision (dotNetObject "System.String" fileName)
			
		model = aquaUtil.tcbModels.item[0]
		--Get vert array
		vertArray = #()
		vertCount = model.vertices.count
		
		vertArray[vertCount] = [0, 0, 0]
		for vert = 0 to (vertCount - 1) do
		(
			vertVec3 = model.vertices.item[vert]
			if useYZFlip then
			(
				vertP3 = [vertVec3.X, -vertVec3.Z, vertVec3.Y]
			) else 
			(
				vertP3 = [vertVec3.X, vertVec3.Y, vertVec3.Z]
			)
			if useAutoSize then
			(
				vertP3 = vertP3 * autoSizeValue
			)
			vertArray[vert + 1] = vertP3
		)
		--Construct face array
		faceArray = #()
		psetTris = model.faces
		
		faceArray[psetTris.count] = [0,0,0]
		for face = 0 to (psetTris.count - 1) do
		(
			faceVec3 = psetTris.item[face]
			faceArray[face + 1] = [faceVec3.vertex0 + 1, faceVec3.vertex1 + 1, faceVec3.vertex2 + 1]
		)
		
		-- Construct the mesh object
		newMesh = mesh name:meshName pos:[0,0,0] \
							vertices:vertArray faces:faceArray
	)
)

fn importPRM fileName useAutoSize autoSizeValue useYZFlip =
(
	with undo off
	(
		startPath = getFilenamePath(getThisScriptFilename())
		currentPath = getFilenamePath(fileName)
		meshName = getFilenameFile(fileName) + getFilenameType(fileName)
		dotnet.loadAssembly (startPath + @"\include\AquaLib\AquaModelLibrary.dll")
		aquaUtil = dotNetObject "AquaModelLibrary.AquaUtil"
		aquaUtil.LoadPRM (dotNetObject "System.String" fileName)
			
		model = aquaUtil.prmModels.item[0]
		--Get vert array
		vertArray = #()
		vertCount = model.vertices.count
		
		vertArray[vertCount] = [0, 0, 0]
		for vert = 0 to (vertCount - 1) do
		(
			vertVec3 = model.vertices.item[vert].pos
			if useYZFlip then
			(
				vertP3 = [vertVec3.X, -vertVec3.Z, vertVec3.Y]
			) else 
			(
				vertP3 = [vertVec3.X, vertVec3.Y, vertVec3.Z]
			)
			if useAutoSize then
			(
				vertP3 = vertP3 * autoSizeValue
			)
			vertArray[vert + 1] = vertP3
		)
		--Construct face array
		faceArray = #()
		psetTris = model.faces
		
		faceArray[psetTris.count] = [0,0,0]
		for face = 0 to (psetTris.count - 1) do
		(
			faceVec3 = psetTris.item[face]
			faceArray[face + 1] = [faceVec3.X + 1, faceVec3.Y + 1, faceVec3.Z + 1]
		)
		
		-- Construct the mesh object
		newMesh = mesh name:meshName pos:[0,0,0] \
							vertices:vertArray faces:faceArray
		
		meshop.setMapSupport newMesh 1 true
		meshop.setNumMapVerts newMesh 1 vertCount
		meshop.setNumMapFaces newMesh 1 (meshop.getNumFaces newMesh) 
		
		for j = 0 to (vertCount - 1) do
		(
			meshop.setMapVert newMesh 1 (j + 1) [model.vertices.item[j].uv1.X, -model.vertices.item[j].uv1.Y, 0]
		)
		for j = 1 to (meshop.getNumFaces newMesh) do
		(
			face = getFace newMesh j
			meshop.setMapFace newMesh 1 j face
		)
		
		meshop.setNumMaps newMesh ((meshop.getNumMaps newMesh) + 1) keep:true
		meshop.setMapSupport newMesh 2 true
		meshop.setNumMapVerts newMesh 2 vertCount
		meshop.setNumMapFaces newMesh 2 (meshop.getNumFaces newMesh) 
		
		for j = 0 to (vertCount - 1) do
		(
			meshop.setMapVert newMesh 2 (j + 1) [model.vertices.item[j].uv2.X, -model.vertices.item[j].uv2.Y, 0]
		)
		for j = 1 to (meshop.getNumFaces newMesh) do
		(
			face = getFace newMesh j
			meshop.setMapFace newMesh 2 j face
		)
		setNumCPVVerts newMesh newMesh.numverts

		-- Set vertex coloring -- 
		for j = 0 to (vertCount - 1) do
		(
			setvertcolor newMesh (j + 1) (color (model.vertices.item[j].color[3]) (model.vertices.item[j].color[2]) (model.vertices.item[j].color[1]) (model.vertices.item[j].color[4]))
			meshop.setvertalpha newMesh -2 (j + 1) (model.vertices.item[j].color[4])
		)
		defaultVCFaces newMesh
		newMesh.showVertexColors = true
	)
)

fn importAQO fileName useBones useAutoSize autoSizeValue useYZFlip keepBoneIds prog =
(
	with undo off
	(
		startPath = getFilenamePath(getThisScriptFilename())
		currentPath = getFilenamePath(fileName)
		dotnet.loadAssembly (startPath + @"\include\AquaLib\AquaModelLibrary.dll")
		aquaUtil = dotNetObject "AquaModelLibrary.AquaUtil"
		if (ext == ".axs") then
		(
			aquaUtil.aquaBones.Clear()
		) 
		aquaUtil.ReadModel (dotNetObject "System.String" fileName) true

		pso2BoneArray = undefined
			
		--If the user wants to import PSO2 skinning, do so
		if (useBones) then
		(
			ext = getFilenameType fileName
			boneFileName = filterString (filenameFromPath fileName) "."
			if(ext == ".trp") then
			(
				newExt = ".trn"
			) else
			(
				newExt = ".aqn"
			)
			boneFileName = (currentPath + boneFileName[1] + newExt)
			
			if ((doesFileExist boneFileName) == false) then
			(
				boneFileName = undefined
			)
			
			if (boneFileName != undefined) then
			(
				aquaUtil.ReadBones (dotNetObject "System.String" boneFileName)
				pso2BoneArray = (SkelImportNET aquaUtil.aquaBones.item[0] false useAutoSize autoSizeValue useYZFlip keepBoneIds)
			) else if (ext == ".axs") then
			(
				pso2BoneArray = (SkelImportNET aquaUtil.aquaBones.item[0] false useAutoSize autoSizeValue useYZFlip keepBoneIds)
			) else
			(
				useBones = false
			)
		)	
		
		fullAQPCount = aquaUtil.aquaModels.item[0].models.Count - 1
		
		if importLOD == false then
		(
			fullAqpCount = 0
		)
		
		for mdl = 0 to fullAqpCount do
		(
			model = aquaUtil.aquaModels.item[0].models.item[mdl]
			
			if model.objc.type >= 0xC33 then
			(
				model.splitVSETPerMesh()
			)
			
			--Create multi material for adding materials we make later. Materials *must* be generated using mesh data since materials with different texture sets are possible and max doesn't separate texture sets from materials
			newMaterial = multimaterial numsubs:0
			newMaterial.name = (getFilenameFile fileName)	
			
			matInfoArray = #()
			importList = #()
			--Generate Meshes
			for i = 0 to (model.objc.vsetCount - 1) do
			(
				--Name the mesh
				meshName = "mesh" + "[" + i as string + "]" + "_" + model.meshList.item[i].mateIndex as string + "_" + model.meshList.item[i].rendIndex as string + "_" + model.meshList.item[i].shadIndex as string + "_" + model.meshList.item[i].tsetIndex as string

				--Create the material if nonexistant, add it to multimat. If it does exist, find it and use it.
				matId = -1

				for j = 1 to matInfoArray.count do
				(
					mat = matInfoArray[j]
					if(model.meshList.item[i].mateIndex == mat.mateIndex and model.meshList.item[i].tsetIndex == mat.tsetIndex and model.meshList.item[i].shadIndex == mat.shadIndex ) then
					(
						matId = j
					)
				)
				if matId == -1 then
				(
					matId = SetupMaterials model (getFileNamepath fileName) i newMaterial matInfoArray
					append matInfoArray (matInfo mateIndex:model.meshList.item[i].mateIndex  tsetIndex:model.meshList.item[i].tsetIndex shadIndex:model.meshList.item[i].shadIndex)
				)
				
				--Get vert array
				local vertArray = #()
				local vsetIndex = model.meshList.item[i].vsetIndex
				local vertCount = model.vtxlList.item[vsetIndex].vertPositions.count
				
				vertArray[vertCount] = [0, 0, 0]
				for vert = 0 to (vertCount - 1) do
				(
					vertVec3 = model.vtxlList.item[vsetIndex].vertPositions.item[vert]
					if useYZFlip then
					(
						vertArray[vert + 1] = [vertVec3.X, -vertVec3.Z, vertVec3.Y]
					) else 
					(
						vertArray[vert + 1] = [vertVec3.X, vertVec3.Y, vertVec3.Z]
					)
				)

				--Construct face array
				local faceArray = #()
				local psetIndex = model.meshList.item[i].psetIndex
				local psetTris = model.strips.item[psetIndex].getTriangles(true)
				
				faceArray[psetTris.count] = [0,0,0]
				for face = 0 to (psetTris.count - 1) do
				(
					faceVec3 = psetTris.item[face]
					faceArray[face + 1] = [faceVec3.X + 1, faceVec3.Y + 1, faceVec3.Z + 1]
				)
				-- Construct the mesh object
				newMesh = mesh name:meshName pos:[0,0,0] \
									vertices:vertArray faces:faceArray \
									material:newMaterial
				vertArray = undefined
				faceArray = undefined
				psetTris = undefined
				setMatID newMesh matId
				--update newMesh
				meshop.setNumMaps newMesh 20 keep:true
				meshop.setMapSupport newMesh 7 false
				meshop.setMapSupport newMesh 8 false
				meshop.setMapSupport newMesh 1 false
				meshop.setMapSupport newMesh 2 false
				meshop.setMapSupport newMesh 3 false
				meshop.setMapSupport newMesh 4 false
				meshop.setMapSupport newMesh 5 false
				meshop.setMapSupport newMesh 6 false
				
				if model.vtxlList.item[vsetIndex].uv1List.Count > 0 then
				(
					local uv1List = model.vtxlList.item[vsetIndex].uv1List
					meshop.setMapSupport newMesh 1 true
					meshop.setNumMapVerts newMesh 1 uv1List.Count
					meshop.setNumMapFaces newMesh 1 (meshop.getNumFaces newMesh) 
					
					for j = 0 to (uv1List.count - 1) do
					(
						meshop.setMapVert newMesh 1 (j + 1) [uv1List.item[j].X, -uv1List.item[j].Y, 0]
					)
					for j = 1 to (meshop.getNumFaces newMesh) do
					(
						face = getFace newMesh j
						meshop.setMapFace newMesh 1 j face
					)
					uv1List = undefined
				)
				if model.vtxlList.item[vsetIndex].uv2List.Count > 0 then
				(
					local uv2List = model.vtxlList.item[vsetIndex].uv2List
					meshop.setMapSupport newMesh 2 true
					meshop.setNumMapVerts newMesh 2 uv2List.Count
					meshop.setNumMapFaces newMesh 2 (meshop.getNumFaces newMesh) 
					
					for j = 0 to (uv2List.count - 1) do
					(
						meshop.setMapVert newMesh 2 (j + 1) [uv2List.item[j].X, -uv2List.item[j].Y, 0]
					)
					for j = 1 to (meshop.getNumFaces newMesh) do
					(
						face = getFace newMesh j
						meshop.setMapFace newMesh 2 j face
					)
					uv2List = undefined
				)
				if model.vtxlList.item[vsetIndex].uv3List.Count > 0 then
				(
					local uv3List = model.vtxlList.item[vsetIndex].uv3List
					meshop.setMapSupport newMesh 3 true
					meshop.setNumMapVerts newMesh 3 uv3List.Count
					meshop.setNumMapFaces newMesh 3 (meshop.getNumFaces newMesh) 
					
					for j = 0 to (uv3List.count - 1) do
					(
						meshop.setMapVert newMesh 3 (j + 1) [uv3List.item[j].X, -uv3List.item[j].Y, 0]
					)
					for j = 1 to (meshop.getNumFaces newMesh) do
					(
						face = getFace newMesh j
						meshop.setMapFace newMesh 3 j face
					)
					uv3List = undefined
				)
				if model.vtxlList.item[vsetIndex].uv4List.Count > 0 then
				(
					local uv4List = model.vtxlList.item[vsetIndex].uv4List
					meshop.setMapSupport newMesh 4 true
					meshop.setNumMapVerts newMesh 4 uv4List.Count
					meshop.setNumMapFaces newMesh 4 (meshop.getNumFaces newMesh) 
					
					for j = 0 to (uv4List.count - 1) do
					(
						meshop.setMapVert newMesh 4 (j + 1) [uv4List.item[j].X, -uv4List.item[j].Y, 0]
					)
					for j = 1 to (meshop.getNumFaces newMesh) do
					(
						face = getFace newMesh j
						meshop.setMapFace newMesh 4 j face
					)
					uv4List = undefined
				)
				if model.vtxlList.item[vsetIndex].vert0x22.Count > 0 then
				(
					local vert0x22 = model.vtxlList.item[vsetIndex].vert0x22
					meshop.setMapSupport newMesh 5 true
					meshop.setNumMapVerts newMesh 5 vert0x22.Count
					meshop.setNumMapFaces newMesh 5 (meshop.getNumFaces newMesh) 
					
					for j = 0 to (vert0x22.count - 1) do
					(
						meshop.setMapVert newMesh 5 (j + 1) [((vert0x22.item[j][1] as float)/ 32767), -((vert0x22.item[j][2] as float) / 32767), 0]
					)
					for j = 1 to (meshop.getNumFaces newMesh) do
					(
						face = getFace newMesh j
						meshop.setMapFace newMesh 5 j face
					)
					vert0x22 = undefined
				)
				if model.vtxlList.item[vsetIndex].vert0x23.Count > 0 then
				(
					local vert0x23 = model.vtxlList.item[vsetIndex].vert0x23
					meshop.setMapSupport newMesh 6 true
					meshop.setNumMapVerts newMesh 6 vert0x23.Count
					meshop.setNumMapFaces newMesh 6 (meshop.getNumFaces newMesh) 
					
					for j = 0 to (vert0x23.count - 1) do
					(
						meshop.setMapVert newMesh 6 (j + 1) [((vert0x23.item[j][1] as float) / 32767), -((vert0x23.item[j][2] as float) / 32767), 0]
					)
					for j = 1 to (meshop.getNumFaces newMesh) do
					(
						face = getFace newMesh j
						meshop.setMapFace newMesh 6 j face
					)
					vert0x23 = undefined
				)
				if model.vtxlList.item[vsetIndex].vertColors.Count > 0 then
				(
					setNumCPVVerts newMesh newMesh.numverts
					local colorList = model.vtxlList.item[vsetIndex].vertColors

					-- Set vertex coloring -- 
					for j = 0 to (colorList.Count - 1) do
					(
						setvertcolor newMesh (j + 1) (color (colorList.item[j][3]) (colorList.item[j][2]) (colorList.item[j][1]) (colorList.item[j][4]))
						meshop.setvertalpha newMesh -2 (j + 1) (colorList.item[j][4])
					)
					defaultVCFaces newMesh
					newMesh.showVertexColors = true 
					colorList = undefined
				) else 
				(
					meshop.setMapSupport newMesh 0 false
				)
				if model.vtxlList.item[vsetIndex].vertColor2s.Count > 0 then
				(
					--Probably should try to find a use for this...
				)
				
				-- Crude scaling. Do this before potential skinning
				if useAutoSize then
				(
					local scale = [autoSizeValue, autoSizeValue, autoSizeValue]
					
					for j = 1 to newMesh.numverts do
					(
						local v = getvert newMesh j
						v *= scale
						setvert newMesh j v
					)
				)
				meshop.removeDegenerateFaces newMesh
				--update newMesh
				
				if model.vtxlList.item[vsetIndex].vertNormals.Count > 0 and precisionNormals then
				(
					local nrmList = model.vtxlList.item[vsetIndex].vertNormals
					--Set Normals
					max modify mode
					select newMesh
					addmodifier newMesh (Edit_Normals ()) ui:off
					local nMNorms = newMesh.modifiers[#Edit_Normals]	
					
					--Finish setting normals
					newMesh.Edit_Normals.MakeExplicit selection:#{1..newMesh.verts.count}
					local EN_convertVS = newMesh.Edit_Normals.ConvertVertexSelection
					local EN_setNormal = newMesh.Edit_Normals.SetNormal
					local EN_getNormal = newMesh.Edit_Normals.GetNormal
					local EN_getVertexID = newMesh.Edit_Normals.GetVertexID
					local EN_getNormalID = newMesh.Edit_Normals.GetNormalID
					local EN_getDegree = newMesh.Edit_Normals.GetFaceDegree
					local EN_setSelection = newMesh.Edit_Normals.SetSelection
					local EN_setExplicit = newMesh.Edit_Normals.SetNormalExplicit
					local normID = #{}

					
					for v = 1 to newMesh.verts.count do(
						--free normID                                             use this if it's necessary, but it's honestly probably not. Free is kind of intensive...
						EN_convertVS #{v} &normID
						for id in normID do 
						(
							if useYZFlip then
							(
								nrm = [nrmList.item[v - 1].X, -nrmList.item[v - 1].Z, nrmList.item[v - 1].Y] 
							) else
							(
								nrm = [nrmList.item[v - 1].X, nrmList.item[v - 1].Y, nrmList.item[v - 1].Z] 
							)
							EN_setSelection #{id}
							EN_setExplicit id explicit:true
							EN_setNormal id nrm
						)
					)
						
					--update newMesh
					maxOps.CollapseNodeTo newMesh 1 true -- Collapse the Edit Normals modifier
					--update newMesh
				)
				if useBones then
				(
					prog.value += 50 / (model.objc.vsetCount)
					count =  0
					Max modify mode
					Select newMesh
					skinMod = Skin()
					AddModifier newMesh skinMod
					--If there's proper weights, use them. Otherwise, the model is probably a rigid assignment and so we apply accordingly.
					if model.vtxlList.item[vsetIndex].vertWeights.Count > 0 and model.vtxlList.item[vsetIndex].vertWeightIndices.Count > 0 and model.vtxlList.item[vsetIndex].bonePalette != undefined then
					(
						local wts = model.vtxlList.item[vsetIndex].trueVertWeights
						local ids = model.vtxlList.item[vsetIndex].trueVertWeightIndices
						 
						if model.objc.type >= 0xC33 then
						(
							bonePalette = model.bonePalette
							print "0xC33"
							print bonePalette.Count
						) else 
						(
							bonePalette = model.vtxlList.item[vsetIndex].bonePalette
							print "Classic"
						)
						
						--Apply Skinned Nodes 
						for b = 0 to (bonePalette.Count - 1) do
						(
							tempB = bonePalette.item[b] + 1
							if pso2BoneArray[tempB] != undefined then
							(
								SkinOps.AddBone skinMod (pso2BoneArray[tempB].MaxBone) 0
							)
						)
						
						-- Set the weight for each of them 
						ModPanel.SetCurrentObject skinMod
						
						for j = 1 to newMesh.numverts do 
						(
							trueIdArray = #()
							trueWeightArray = #()
							for vertWeight = 1 to ids.item[j - 1].count do
							(
								append trueIdArray (ids.item[j - 1][vertWeight] + 1)
								case vertWeight of
								(
									1: (append trueWeightArray wts.item[j - 1].X)
									2: (append trueWeightArray wts.item[j - 1].Y)
									3: (append trueWeightArray wts.item[j - 1].Z)
									4: (append trueWeightArray wts.item[j - 1].W)
								)
							)
							SKN_UnNRMVert skinMod j true
							SKN_RepWeights skinMod j trueIdArray trueWeightArray
						)
					) else 
					(
						boneId = model.meshList.item[i].baseMeshNodeId + 1
						if boneID < 1 then
						(
							boneId = 1
						)
						SkinOps.AddBone skinMod (pso2BoneArray[boneId].MaxBone) 0
					)
					--skinMod.always_deform = true;
					prog.value += 50 / (model.objc.vsetCount)
				) else
				(
					prog.value += 100 / (model.objc.vsetCount)
				)
				
				Max create mode
				
				update newMesh
				append importList newMesh
				setUserProp newMesh "NodeID" model.meshList.item[i].baseMeshNodeId 
				setUserProp newMesh "MeshID" model.meshList.item[i].baseMeshDummyId 
				
				if i != 0 then
				(
					if (mod i 2) == 0 then
					(
						gc()
					)
				)
			)
			prog.value = 0
			group importList name:((getFilenameFile filename) + "_[" + mdl as string + "]")
			
		)
		
		completeRedraw()
		aquaUtil.aquaModels.Clear()
		print ( fileName as string +" file imported!")
	)
)

fn ModelDataCollector meshes extraBoneList fileName ResizeChecked ResizeValue YZRot BinormExport UNRMExport difWhite unrmAvg useFaceNrms boundZero baHack makeMeshDummies prog doNGS doRigid =
(
	with undo off
	(
		startPath = getFilenamePath(getThisScriptFilename())
		currentPath = getFilenamePath(fileName)
		dotnet.loadAssembly (startPath + @"\include\AquaLib\AquaModelLibrary.dll")
		aquaUtil = dotNetObject "AquaModelLibrary.AquaUtil"
		max modify mode
		matArray = #()
		
		--Maxscript gets funny about structs. This lets us create them somewhat normally
		--Fun fact, inner classes MUST be accessed via a '+' instead of a '.'. Why? I don't know!
		activator = dotNetClass "activator"
		vec2 = dotNetClass "System.Numerics.Vector2"
		vec3 = dotNetClass "System.Numerics.Vector3"
		vec4 = dotNetClass "System.Numerics.Vector4"
		mdlSet = dotNetClass "AquaModelLibrary.Utility.AquaUtilData+ModelSet"
		aqo = dotNetClass "AquaModelLibrary.ClassicAquaObject"
		ngsAqo = dotNetClass "AquaModelLibrary.NGSAquaObject"
		vertSet = dotNetClass "AquaModelLibrary.AquaObject+VTXL"
		genMate = dotNetClass "AquaModelLibrary.AquaObject+GenericMaterial"
		genTris = dotNetClass "AquaModelLibrary.AquaObject+GenericTriangles"
		netWeightsClass = dotNetClass "System.Collections.Generic.List`1[System.Single]"
		int32List = dotNetClass "System.Collections.Generic.List`1[System.Int32]"
		strList = dotNetClass "System.Collections.Generic.List`1[System.String]"
		byteArrClass = dotNetClass "System.Byte[]"
		shortArrClass = dotNetClass "System.Int16[]"
		try
		(
			activator.createInstance vec2
			activator.createInstance vec3
			activator.createInstance vec4
		)
		catch ()
		
		GetMVert = meshop.getMapVert 
		GetMFace = meshop.getMapFace 
		if(doNGS == true) then
		(
			aqobj = dotNetObject ngsAqo
		) else (
			aqobj = dotNetObject aqo
		)
		aqobj.applyNormalAveraging = unrmAvg
		
		for msh = 1 to meshes.count do
		(
			--Create arrays to store weight data since they're slow to retrieve since they're from a modiifer. Ironically, accessing the data directly is usually faster so it's not worth doing this for positions. 
			local tempVertWeight = #()
			local tempVertIds = #()
			tempVertWeight[meshes[msh].mesh.numVerts + 1] = #()
			tempVertIds[meshes[msh].mesh.numVerts + 1] = #()
			
			local tempMesh = dotNetObject genTris
			tempMesh.vertCount = meshes[msh].mesh.numVerts
			if baHack == false then
			(	
				MeshID = getUserProp meshes[msh] "MeshID"
				testNodeId = getUserProp meshes[msh] "NodeID"
				if testNodeId == undefined then					
				(	
					if extraBoneList.count > 0 then
					(
						tempMesh.baseMeshNodeId = ((getUserProp extraBoneList[MeshID + 1] "NodeID") + 1)
					) else
					(
						tempMesh.baseMeshNodeId = 0
					)
					
				) else
				(
					tempMesh.baseMeshNodeId = testNodeId
				)
				if MeshID == undefined then
				(
					MeshID = 0
				)
				tempMesh.baseMeshDummyId = MeshID
			)
			
			local meshMatArray = #()
			
			--Set up vert data test booleans
			useVertColor = meshop.getMapSupport meshes[msh].mesh 0
			useVertAlpha = meshop.getMapSupport meshes[msh].mesh -2
			useVertColor2 = meshop.getMapSupport meshes[msh].mesh 7
			useVertAlpha2 = meshop.getMapSupport meshes[msh].mesh 8
			useUV1 = meshop.getMapSupport meshes[msh].mesh 1
			useUV2 = meshop.getMapSupport meshes[msh].mesh 2
			useUV3 = meshop.getMapSupport meshes[msh].mesh 3
			useUV4 = meshop.getMapSupport meshes[msh].mesh 4
			use0x22 = meshop.getMapSupport meshes[msh].mesh 5
			use0x23 = meshop.getMapSupport meshes[msh].mesh 6
			
			hasSkinning = (for m in meshes[msh].modifiers where isKindOf m skin collect m).count > 0 

			if hasSkinning == true then
			(
				max modify mode
				objSkin = meshes[msh].skin
				modPanel.setCurrentObject objSkin
				
				--Loop to set up bone palette based on count (should be 1 to count)
				boneCount = skinOps.GetNumberBones objSkin
				for i = 1 to boneCount do
				(
					tempMesh.bonePalette.Add (GetUserProp (getnodebyname (skinOps.GetBoneName objSkin i 1)) "NodeID") -- This should already be set by the bone exporting portion
				)
			) else 
			(
				--Figure out something for this. Maybe just tell the user to use skining in all cases. Can't hurt them too much.
			)

			for f = 1 to (getNumFaces meshes[msh]) do
			(
				--Get the material id and material. We'll need to remap all of these later
				local id = getfacematid meshes[msh].mesh f
				appendIfUnique meshMatArray id
				tempMesh.matIdList.Add(id)
				
				local faceVerts = getface meshes[msh].mesh f
				local faceNrms = meshop.getFaceRNormals meshes[msh].mesh f
				tempMesh.triList.Add(dotNetObject vec3 (faceVerts[1] - 1) (faceVerts[2] - 1) (faceVerts[3] - 1))
				
				--Populate face vertex data; We need to split this. It's more efficient if we can split it in .NET after it's gathered since maxscript chugs for these things
				local vertData = dotNetObject vertSet
				--Get map information for each vertex
				for v = 1 to faceVerts.count do
				(					
					local tempPos = getVert meshes[msh] faceVerts[v]
					local tempNrms = faceNrms[v]
					vertData.rawVertId.Add(faceVerts[v] - 1)
					vertData.rawFaceId.Add(f - 1)
					
					if YZRot == true then
					(
						tempZ = tempPos.z
						tempPos.z = -tempPos.y
						tempPos.y = tempZ
						
						tempZ = tempNrms.z
						tempNrms.z = -tempNrms.y
						tempNrms.y = tempZ
					)
					if ResizeChecked == true then
					(	
						--Actual resizing
						tempPos *= ( 1 / ResizeValue )
					)
					vertData.vertPositions.Add(dotNetObject vec3 tempPos.X tempPos.Y tempPos.Z)
					tempPos = undefined
					if precisionNormals == false then
					(
						vertData.vertNormals.Add(dotNetObject vec3 tempNrms.X tempNrms.Y tempNrms.Z)
					)
					
					--Get vert colors
					if useVertColor == true then
					(
						local vcolor = (GetMVert meshes[msh] 0 ((GetMFace meshes[msh] 0 f)[v])) as color
						if useVertAlpha == true then
						(
							vcolor.alpha = (GetMVert meshes[msh] -2 (GetMFace meshes[msh] -2 1)[1]).x
						) else 
						(
							vcolor.alpha = 1.0;
						)
						
						vertData.vertColors.Add((dotnet.ValueToDotNetObject #(255 * vcolor.b, 255 * vcolor.g, 255 * vcolor.r, vcolor.a) byteArrClass))
						vcolor = undefined
					)
					
					--Get vert color2s
					if useVertColor2 == true then
					(
						local vcolor2 = (GetMVert meshes[msh] 7 ((GetMFace meshes[msh] 7 f)[v])) as color
						if useVertAlpha2 == true then
						(
							vcolor2.alpha = (GetMVert meshes[msh] 8 (GetMFace meshes[msh] 8 1)[1]).x
						) else 
						(
							vcolor2.alpha = 1.0;
						)
						
						vertData.vertColor2s.Add((dotnet.ValueToDotNetObject #(255 * vcolor2.b, 255 * vcolor2.g, 255 * vcolor2.r, vcolor2.a) byteArrClass))
						vcolor2 = undefined
					)
					
					--Get first set of UVs 
					if useUV1 == true then
					(
						local uv1 = (meshop.getMapVert meshes[msh] 1 ((meshop.getMapFace meshes[msh] 1 f)[v]))
						vertData.uv1List.Add(dotNetObject vec2 uv1.X -uv1.Y)
						uv1 = undefined
					)
					
					--Get second set of UVs 
					if useUV2 == true then
					(
						local uv2 = (meshop.getMapVert meshes[msh] 2 ((meshop.getMapFace meshes[msh] 2 f)[v]))
						vertData.uv2List.Add(dotNetObject vec2 uv2.X -uv2.Y)
						uv2 = undefined
					)
					
					--Get third set of UVs 
					if useUV3 == true then
					(
						local uv3 = (meshop.getMapVert meshes[msh] 3 ((meshop.getMapFace meshes[msh] 3 f)[v]))
						vertData.uv3List.Add(dotNetObject vec2 uv3.X -uv3.Y)
						uv3 = undefined
					)
					
					--Get fourth set of UVs 
					if useUV4 == true then
					(
						local uv4 = (meshop.getMapVert meshes[msh] 4 ((meshop.getMapFace meshes[msh] 4 f)[v]))
						vertData.uv4List.Add(dotNetObject vec2 uv4.X -uv4.Y)
						uv4 = undefined
					)
					
					--Get 0x22 map
					if use0x22 == true then
					(
						local unk22 = (meshop.getMapVert meshes[msh] 5 ((meshop.getMapFace meshes[msh] 5 f)[v]))
						vertData.vert0x22.Add((dotnet.ValueToDotNetObject #((unk22.X * 32767), -(unk22.Y * 32767)) shortArrClass))
						unk22 = undefined
					)
					
					--Get 0x23 map
					if use0x23 == true then
					(
						local unk23 = (meshop.getMapVert meshes[msh] 6 ((meshop.getMapFace meshes[msh] 6 f)[v]))
						vertData.vert0x23.Add((dotnet.ValueToDotNetObject #((unk23.X * 32767), -(unk23.Y * 32767)) shortArrClass))
						unk23 = undefined
					)
					
					if hasSkinning == true then
					(
						local netWeights = dotnetobject netWeightsClass
						local netIds = dotnetobject int32List
						if tempVertWeight[faceVerts[v]] == undefined then
						(
							local wc = skinOps.GetVertexWeightCount objSkin faceVerts[v]
							local weights = #()
							local _bones = #()
							
							for b = 1 to wc do
							(
								append weights (skinOps.GetVertexWeight objSkin faceVerts[v] b)
								append _bones ((skinOps.GetVertexWeightBoneID objSkin faceVerts[v] b) - 1) -- We need this zero based
							)
							for i = 1 to (4 - wc) do
							(
								append weights 0
								append _bones 0
							)
							tempVertWeight[faceVerts[v]] = weights			
							tempVertIds[faceVerts[v]] = _bones

							for i = 1 to weights.count do
							(
								netWeights.Add weights[i]
								netIds.Add _bones[i]
							)
							wc = undefined
							weights = undefined
							_bones = undefined
						) else 
						(
							for i = 1 to tempVertWeight[faceVerts[v]].count do
							(
								netWeights.Add tempVertWeight[faceVerts[v]][i] 
								netIds.Add tempVertIds[faceVerts[v]][i]
							)
						)
						vertData.rawVertWeights.Add netWeights				
						vertData.rawVertWeightIds.Add netIds
					)
				)
				tempMesh.faceVerts.Add(vertData)
				
				if(mod f 500) == 0 then
				(
					gc()
				)
			)
			if precisionNormals == true then
			(
				prog.value += 60 / meshes.count
			) else (
				prog.value += 80 / meshes.count
			)
			
			--Gather material IDs and prep for remapping
			for matId = 1 to meshMatArray.Count do
			(
				mat = meshMatArray[matId]
				
				tempMat = meshes[msh].material
				--get true material if needed - A face's mat id in max will be used for its multimaterial and each successive level of multimaterial
				while ((classof tempMat) == Multimaterial) do
				(
					if tempMat.count >= mat then
					(
						tempMat = tempMat[mat]
					) else
					(
						tempMat = tempMat[tempMat.count]
					)
				)

				match = false
				for m = 1 to matArray.count while match == false do
				(
					if tempMat == matArray[m] then
					(
						match = true
						tempMesh.matIdDict.Add mat (m - 1)
					)
				)
				if match == false then
				(
					append matArray tempMat
					tempMesh.matIdDict.Add mat (matArray.count - 1)
				)
			)
			
			aqobj.tempTris.Add(tempMesh)
			print (meshes[msh].name + " processed.")
		)
		
		--Precise normals
		if precisionNormals == true then
		(
			for nrmMesh = 1 to meshes.count do
			(
				local modi = Edit_Normals()
				addmodifier meshes[nrmMesh] modi
				modPanel.setCurrentObject modi
				
				local _GetNumFaces = modi.GetNumFaces
				local _GetFaceDegree = modi.GetFaceDegree
				local _GetNormalID = modi.GetNormalID
				local _GetNormal = modi.GetNormal
				
				for f = 1 to _GetNumFaces() do
				(
					for v = 1 to _GetFaceDegree f do
					(
						local id = _GetNormalID f v 
						local tempNrms = _GetNormal id
						
						if YZRot == true then
						(
							tempZ = tempNrms.z
							tempNrms.z = -tempNrms.y
							tempNrms.y = tempZ
						)
						
						--local otherId = modi.GetVertexId f v
						aqobj.tempTris.item[nrmMesh - 1].faceVerts.item[f - 1].vertNormals.Add(dotNetObject vec3 tempNrms.X tempNrms.Y tempNrms.Z)
						id = undefined
						tempNrms = undefined
					)
				)
				
				_GetNumFaces = undefined
				_GetFaceDegree = undefined
				_GetNormalID = undefined
				_GetNormal = undefined
				deletemodifier meshes[nrmMesh] modi
				prog.value += 20 / meshes.count
			)
		)
		
		--Store material data
		for mat = 1 to matArray.count do
		(
			mate = (dotNetObject genMate)
			
			--Parse shader types, blend types, and special identifiers from material name while removing the aforementioned from the name
			matName = matArray[mat].name
			filter1 = (filterstring matName ")")
			if (filter1.count > 1) then
			(
				shaderText = (filterstring filter1[1] "(")[1]
				shaderSet = filterstring shaderText ","
				if shaderSet != undefined and shaderSet.count >= 2 then
				(
					mate.shaderNames = dotnetobject strList
					mate.shaderNames.Add(shaderSet[1])
					mate.shaderNames.Add(shaderSet[2])
				)
				
				matName = filter1[2]
			)
			filter2 = (filterstring matName "}")
			if (filter2.count > 1) then
			(
				mate.blendType = (filterstring filter2[1] "{")[1]
				matName = filter2[2]
			)
			filter3 = (filterstring matName "]")
			if (filter3.count > 1) then
			(
				mate.specialType = (filterstring filter3[1] "[")[1]
				matName = filter3[filter3.count]
			)
			
			mate.texNames = dotnetobject strList
			mate.texUVSets = dotnetobject int32List
			for map = 2 to matArray[mat].maps.count do
			(
				bmap = matArray[mat].maps[map]
				if (classof bmap) == bitmapTexture then
				(
					mate.texNames.Add((getFilenameFile bmap.filename) + ".dds")
					uvChan = bmap.coords.mapChannel
					
					--Handle -1 mapping workaround
					if uvChan == 99 then
					(
						uvChan = -1
					) else 
					(
						uvChan = uvChan - 1
					)
					mate.texUVSets.Add(uvChan)
				)
			)
			
			if difWhite != true then
			(
				local difColor = (GetProperty matArray[mat] #diffuseColor)
				mate.diffuseRGBA.X = difColor.R / 255.0
				mate.diffuseRGBA.Y = difColor.G / 255.0
				mate.diffuseRGBA.Z = difColor.B / 255.0
				mate.diffuseRGBA.W = matArray[mat].opacity / 100.0
				difColor = undefined
			)
			
			if matArray[mat].twoSided == true then
			(
				mate.twoSided = 1
			) else 
			(
				mate.twoSided = 0
			)
			mate.matName = matName
			
			aqobj.tempMats.Add(mate)
		)
		prog.value += 10 
		
		newSet = dotNetObject mdlSet
		newSet.models.Add(aqobj)
		aquaUtil.aquaModels.Add(newSet)
		if(doNGS == true) then
		(
			aquaUtil.ConvertToNGSPSO2Mesh UNRMExport useFaceNrms baHack BinormExport boundZero doRigid true
			aquaUtil.WriteNGSNIFLModel fileName fileName
		) else 
		(
			aquaUtil.ConvertToClassicPSO2Mesh UNRMExport useFaceNrms baHack BinormExport boundZero doRigid true
			aquaUtil.WriteClassicNIFLModel fileName fileName
		)
		prog.value += 10
		aquaUtil.aquaModels.Clear()
		print (fileName + " was successfully output!")
	)
)

fn GeoExportNet aqpFile ResizeChecked ResizeValue YZRot BinormExport UNRMExport difWhite unrmAvg useFaceNrms boundZero baHack makeMeshDummies prog doNGS doRigid =
(
	with undo off
	(
		fName = (filenameFromPath aqpFile)
		
		--Gather meshes and create dummies for them for export
		sceneList = objects as array; for i = 1 to sceneList.count do ( if isGroupHead sceneList[i] then (ungroup sceneList[i]) ); free sceneList
		boneList = GetPSO2BoneArray false
		baseMeshes = #()
		for g in geometry where (g.parent == undefined or (isGroupHead g.parent)) and g.children.count == 0 and (isGroupHead g) != true and (finditem boneList.BoneList g) != true do
		(
			boneCheck = false
			for h in boneList.BoneList do
			(
				if g == h then
				(
					boneCheck = true
				)
			)
			if boneCheck == false then
			(
				append baseMeshes g
			)
		)


		extraBoneList = #()
		for i=1 to baseMeshes.count do 
		(
			if makeMeshDummies == true then
			(
				setUserProp baseMeshes[i] "MeshID" (i-1)
				temp = (getNodeByName (baseMeshes[i].name + "_dummy"))
				if  temp == undefined then
				(
					temp = dummy pos: ( [0, 0, 0] ) name: ( baseMeshes[i].name + "_dummy")
				)
				temp.parent = boneList.BoneList[1]
				append extraBoneList temp
				
				if boneList.BoneOrdering == undefined then 
				(
					temp.name = "(" + ((boneList.BoneList.count + i-1) as string) + ")" + temp.name
				)
				setUserProp temp "NodeID" (boneList.BoneList.count + i-1)
			)
		)
		
		
		--Export Bones
		currentPath = getFilenamePath aqpFile
		boneFileName = filterString (filenameFromPath aqpFile) "."
		boneFileName = (currentPath + boneFileName[1] + ".aqn")
		SkelExport boneFileName ResizeChecked ResizeValue YZRot doNGS
		
		--Throw model data to our .NET library
		ModelDataCollector baseMeshes extraBoneList aqpFile ResizeChecked ResizeValue YZRot BinormExport UNRMExport difWhite unrmAvg useFaceNrms boundZero baHack makeMeshDummies prog doNGS doRigid
	)
)

fn PRMDataCollector prmMesh fileName ResizeChecked ResizeValue YZRot prog =
(
	meshes = #()
	append meshes prmMesh
	
	with undo off
	(
		startPath = getFilenamePath(getThisScriptFilename())
		currentPath = getFilenamePath(fileName)
		dotnet.loadAssembly (startPath + @"\include\AquaLib\AquaModelLibrary.dll")
		aquaUtil = dotNetObject "AquaModelLibrary.AquaUtil"
		max modify mode
		matArray = #()
		
		activator = dotNetClass "activator"
		vec2 = dotNetClass "System.Numerics.Vector2"
		vec3 = dotNetClass "System.Numerics.Vector3"
		vec4 = dotNetClass "System.Numerics.Vector4"
		mdlSet = dotNetClass "AquaModelLibrary.AquaUtil+ModelSet"
		aqo = dotNetClass "AquaModelLibrary.ClassicAquaObject"
		vertSet = dotNetClass "AquaModelLibrary.AquaObject+VTXL"
		genMate = dotNetClass "AquaModelLibrary.AquaObject+GenericMaterial"
		genTris = dotNetClass "AquaModelLibrary.AquaObject+GenericTriangles"
		netWeightsClass = dotNetClass "System.Collections.Generic.List`1[System.Single]"
		int32List = dotNetClass "System.Collections.Generic.List`1[System.Int32]"
		strList = dotNetClass "System.Collections.Generic.List`1[System.String]"
		byteArrClass = dotNetClass "System.Byte[]"
		try
		(
			activator.createInstance vec2
			activator.createInstance vec3
			activator.createInstance vec4
		)
		catch ()
		
		GetMVert = meshop.getMapVert 
		GetMFace = meshop.getMapFace 
		aqobj = dotNetObject aqo
		
		for msh = 1 to meshes.count do
		(
			--Create arrays to store weight data since they're slow to retrieve since they're from a modiifer. Ironically, accessing the data directly is usually faster so it's not worth doing this for positions. 
			tempVertWeight = #()
			tempVertIds = #()
			tempVertWeight[meshes[msh].mesh.numVerts + 1] = #()
			tempVertIds[meshes[msh].mesh.numVerts + 1] = #()
			
			tempMesh = dotNetObject genTris
			tempMesh.vertCount = meshes[msh].mesh.numVerts
			
			--Set up vert data test booleans
			useVertColor = meshop.getMapSupport meshes[msh].mesh 0
			useVertAlpha = meshop.getMapSupport meshes[msh].mesh -2
			useUV1 = meshop.getMapSupport meshes[msh].mesh 1
			useUV2 = meshop.getMapSupport meshes[msh].mesh 2

			for f = 1 to (getNumFaces meshes[msh]) do
			(
				--Get the material id and material. We'll need to remap all of these later
				faceVerts = getface meshes[msh].mesh f
				faceNrms = meshop.getFaceRNormals meshes[msh].mesh f
				tempMesh.triList.Add(dotNetObject vec3 (faceVerts[1] - 1) (faceVerts[2] - 1) (faceVerts[3] - 1))
				
				--Populate face vertex data; We need to split this. It's more efficient if we can split it in .NET after it's gathered since maxscript chugs for these things
				vertData = dotNetObject vertSet
				--Get map information for each vertex
				for v = 1 to faceVerts.count do
				(					
					tempPos = getVert meshes[msh] faceVerts[v]
					tempNrms = faceNrms[v]
					vertData.rawVertId.Add(faceVerts[v] - 1)
					vertData.rawFaceId.Add(f - 1)
					
					if YZRot == true then
					(
						tempZ = tempPos.z
						tempPos.z = -tempPos.y
						tempPos.y = tempZ
						
						tempZ = tempNrms.z
						tempNrms.z = -tempNrms.y
						tempNrms.y = tempZ
					)
					if ResizeChecked == true then
					(	
						--Actual resizing
						tempPos *= ( 1 / ResizeValue )
					)
					vertData.vertPositions.Add(dotNetObject vec3 tempPos.X tempPos.Y tempPos.Z)
					if precisionNormals == false then
					(
						vertData.vertNormals.Add(dotNetObject vec3 tempNrms.X tempNrms.Y tempNrms.Z)
					)
					
					--Get vert colors
					if useVertColor == true then
					(
						vcolor = (GetMVert meshes[msh] 0 ((GetMFace meshes[msh] 0 f)[v])) as color
						if useVertAlpha == true then
						(
							vcolor.alpha = (GetMVert meshes[msh] -2 (GetMFace meshes[msh] -2 1)[1]).x
						) else 
						(
							vcolor.alpha = 1.0;
						)
						vertData.vertColors.Add((dotnet.ValueToDotNetObject #(255 * vcolor.b, 255 * vcolor.g, 255 * vcolor.r, vcolor.a) byteArrClass))
					)
					
					--Get first set of UVs 
					if useUV1 == true then
					(
						uv1 = (meshop.getMapVert meshes[msh] 1 ((meshop.getMapFace meshes[msh] 1 f)[v]))
						vertData.uv1List.Add(dotNetObject vec2 uv1.X -uv1.Y)
					)
					
					--Get second set of UVs 
					if useUV2 == true then
					(
						uv2 = (meshop.getMapVert meshes[msh] 2 ((meshop.getMapFace meshes[msh] 2 f)[v]))
						vertData.uv2List.Add(dotNetObject vec2 uv2.X -uv2.Y)
					)
					
				)
				tempMesh.faceVerts.Add(vertData)
			)
			if precisionNormals == true then
			(
				prog.value += 60 / meshes.count
			) else (
				prog.value += 80 / meshes.count
			)
			
			aqobj.tempTris.Add(tempMesh)
			print (meshes[msh].name + " processed.")
		)
		
		--Precise normals
		if precisionNormals == true then
		(
			for nrmMesh = 1 to meshes.count do
			(
				modi = Edit_Normals()
				addmodifier meshes[nrmMesh] modi
				modPanel.setCurrentObject modi
				
				_GetNumFaces = modi.GetNumFaces
				_GetFaceDegree = modi.GetFaceDegree
				_GetNormalID = modi.GetNormalID
				_GetNormal = modi.GetNormal
				
				for f = 1 to _GetNumFaces() do
				(
					for v = 1 to _GetFaceDegree f do
					(
						id = _GetNormalID f v 
						tempNrms = _GetNormal id
						
						if YZRot == true then
						(
							tempZ = tempNrms.z
							tempNrms.z = -tempNrms.y
							tempNrms.y = tempZ
						)
						
						otherId = modi.GetVertexId f v
						aqobj.tempTris.item[nrmMesh - 1].faceVerts.item[f - 1].vertNormals.Add(dotNetObject vec3 tempNrms.X tempNrms.Y tempNrms.Z)
					)
				)
				
				deletemodifier meshes[nrmMesh] modi
				prog.value += 20 / meshes.count
			)
		)
		
		prog.value += 10 
		
		newSet = dotNetObject mdlSet
		newSet.models.Add(aqobj)
		aquaUtil.aquaModels.Add(newSet)
		aquaUtil.ConvertToPRM()
		aquaUtil.WritePRM fileName 4
		prog.value += 10 
		print (fileName + " was successfully output!")
	)
)

--Only takes in the selected object on purpose. PRM can only be one model
fn PRMExportNet fileName ResizeChecked ResizeValue YZRot prog =
(
	if $ != undefined then
	(
		with undo off
		(
			PRMDataCollector $ fileName ResizeChecked ResizeValue YZRot prog
		)
	)
)

fn FIGImport fileName ResizeChecked ResizeValue YZRot prog =
(
	figColId = 0 --ID for the state we're pulling collision from. Colliders are set per state, but often just have one state.
	with undo off
	(
		startPath = getFilenamePath(getThisScriptFilename())
		currentPath = getFilenamePath(fileName)
		dotnet.loadAssembly (startPath + @"\include\AquaLib\AquaModelLibrary.dll")
		aquaUtil = dotNetObject "AquaModelLibrary.AquaUtil"
		aquaUtil.ReadFig (dotNetObject "System.String" fileName)
		
		if aquaUtil.aquaFigures.item[0].statestructs == undefined or aquaUtil.aquaFigures.item[0].statestructs.item[figColId].collision == undefined or aquaUtil.aquaFigures.item[0].statestructs.item[figColId].collision.colliders == undefined then
		(
			return undefined
		)
		figCol = aquaUtil.aquaFigures.item[0].statestructs.item[figColId].collision.colliders
		
		objList = #()
		for o in objects do append objlist o
		for i = 0 to (figCol.Count - 1) do
		(
			col = figCol.item[i]
			colShape = undefined
			case col.colStruct.shape of 
			(
				0: (colshape = sphere name:col.name pos:[0,0,0] radius:col.colStruct.shapeParam0)
				1: (colshape = cylinder name:col.name pos:[0,0,0] radius:col.colStruct.shapeParam0 height:col.colStruct.shapeParam1; rotate colShape (eulerangles 90 0 90))
				2: (colshape = box name:col.name pos:[0,0,0] length:col.colStruct.shapeParam0 width:col.colStruct.shapeParam1 height:col.colStruct.shapeParam2; rotate colShape (eulerangles 90 0 90))
				3: (colshape = plane name:col.name pos:[0,0,0] length:col.colStruct.shapeParam0 width:col.colStruct.shapeParam1; rotate colShape (eulerangles 90 0 90))
				4: (colshape = cone name:col.name pos:[0,0,0] radius1:col.colStruct.shapeParam0 radius2:col.colStruct.shapeParam1 height:col.colStruct.shapeParam2; rotate colShape (eulerangles 90 0 90))
				5: (colShape = pyramid name:col.name pos:[0,0,0] width:col.colStruct.shapeParam0 depth:col.colStruct.shapeParam1 height:col.colStruct.shapeParam2; rotate colShape (eulerangles 0 0 45); colShape.pivot = (getvert colShape.mesh 1))
			)
			if ResizeChecked == true then
			(
				scale colShape [ResizeValue, ResizeValue, ResizeValue]
			)
			ResetXForm colShape
			found = false
			for o in objList while found == false do
			(
				bnName = filterString o.name ")"
				if(bnName.count > 1) then
				(
					bnName = bnName[2]
				) else 
				(
					bnName = bnName[1]
				)
				
				if(bnName == col.text1) then
				(
					tfm = (matrix3 o.transform.row1 o.transform.row2 o.transform.row3 o.transform.row4)
					colShape.transform = (matrix3 tfm.row1 tfm.row2 tfm.row3 tfm.row4)
					colShape.parent = o
					found = true
				)
			)
		)
		
		
		
	)
)


rollout pso2ImportRollout "PSO2 Model Importer"
(
	--------------------
	-- User Interface --
	--------------------
	group "About"
	(
		Label lab2 "By Shadowth117"
	)
	group "Settings"
	(
		checkBox autoSizeCheckBox "Rescale" checked:true align:#center
		spinner autoSizeSpinner "Scale by:" align:#center type:#float range:[0,10000,100] enabled:false
		checkBox YZCheckBox "Y-Z Axis Flip" checked:true align:#center
		checkBox useBones "Skin with aqn/trn" checked:true align:#center
		checkBox preciseNormals "Precise Normals (longer import/export)" checked:true align:#center
		checkBox importLevelOfDetail "Import LOD models" checked:false align:#center
		checkBox KeepBoneIds "Bone IDs in object name" checked:true align:#left
		progressbar prog color:blue
	)	
	group "Import"
	(
		button importButton "Import..."
		button importFigButton "Import Fig..."
		button importPath "Batch Import..."
	)
	group "Export AQP/TRP/PRM"
	(
		button exportAQPButton "Export..."
		checkBox ngsExport "Export NGS type model" checked:true align:#left
		checkBox binorm "Binormal+Tangent" checked:true align:#left
		checkBox playerModel "Add UNRMS (Not recommended)" checked:false align:#left
		checkBox difWhite "White Diffuse Tint" checked:true align:#left
		checkBox rigidWeights "Rigid weights" checked:false align:#left
		checkBox unrmAvg "Average UNRM Normals" checked:false align:#left
		checkBox faceNormals "Use Face Normals" checked:false align:#left
		checkBox boundZero "Zero out bounds" checked:false align:#left
		checkBox meshDummies "Make Mesh Dummies" checked:false align:#left
		checkBox baHack "Basewear culling hack" checked:false align:#left
		Label exportNote "Note: Vertex weights past the"
		Label exportNote2 "4th greatest are redistributed."
		Label exportNote3 "Object Groups will be Ungrouped."
	)
	group "AQN/TRN"
	(
		button importAQNButton "Import..."
		button exportAQNButton "Export..."
	)
	group "AQM Tool"
	(
		button openAQMButton "Open AQM Tool"
	)
	
	on autoSizeCheckBox changed nowChecked do
	(
		autoSizeSpinner.enabled = nowChecked
	)
	
	on importFigButton pressed do
	(
		-- Open up a dialog box
		local	boneFileName = getOpenFileName caption:"Import Phantasy Star Online 2 .fig" \
				types:"PSO2 Figure (*.fig)|*.fig|All Files (*.*)|*.*|"
        
		if (boneFileName != undefined) then
		(		
				FIGImport boneFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked prog
		) 
		
		-- Redraw max viewports
		max views redraw
	)
	
	on importButton pressed do
	(
		
		local objFileName = undefined
		-- Open up a dialog box
		objFileName = getOpenFileName caption:"Import Phantasy Star Online 2 or Phantasy Star Nova model" \
					types:"PSO2 Model (*.aqo, *.tro, *.aqp, *.trp, *.tcb, *.prm, *.prx, *.axs)|*.aqo;*.tro;*.aqp;*.trp;*.tcb;*.prm;*.prx;*.axs|All Files (*.*)|*.*|"
        if (objFileName != undefined) then
		(
			importLOD = importLevelOfDetail.checked
			precisionNormals = preciseNormals.checked
			if (getFilenameType objFileName) == ".tcb" then
			(
				importTCB objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked 
			) else if (getFilenameType objFileName) == ".prm"  or  (getFilenameType objFileName) == ".prx" then
			(
				importPRM objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked 
			) else 
			(
				importAQO objFileName useBones.checked autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked true prog
			)
		)
		prog.value = 0
		-- Redraw max viewports
		max views redraw
		-- Ta-daa! You should now see a lovely new imported model in all its glory.
		--print "Import completed."
	)
	
	on importPath pressed do
	(
		-- Open up a dialog box
		local objFileName = getOpenFileName caption:"Import Phantasy Star Online 2 or Phantasy Star Nova model" \
					types:"PSO2 Model (*.aqo, *.tro, *.aqp, *.trp, *.tcb, *.prm, *.prx)|*.aqo;*.tro;*.aqp;*.trp;*.tcb;*.prm;*.prx|All Files (*.*)|*.*|"
		
		if objFileName != undefined then--if the user did not cancel
        (	
			thePath = getFilenamePath objFileName
			
          theFiles = (getFiles (thePath+"\\*.aqp")) + (getFiles (thePath+"\\*.aqo")) + (getFiles (thePath+"\\*.trp")) + (getFiles (thePath+"\\*.tro")) + (getFiles (thePath+"\\*.tcb")) + (getFiles (thePath+"\\*.prm"))  + (getFiles (thePath+"\\*.prx")) 
		  for objFileName = theFiles do-- go through all of them
          (
			print objFileName
			importLOD = importLevelOfDetail.checked
			precisionNormals = preciseNormals.checked
			if (getFilenameType objFileName) == ".tcb"  then
			(
				importTCB objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked 
			) else if (getFilenameType objFileName) == ".prm" or  (getFilenameType objFileName) == ".prx" then
			(
				importPRM objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked 
			) else 
			(
				importAQO objFileName useBones.checked autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked true prog
			)
		  )
	    )
		
	    -- Redraw max viewports
		max views redraw
	)
	
	on importAQNButton pressed do
	(
		-- Open up a dialog box
		local	boneFileName = getOpenFileName caption:"Import Phantasy Star Online 2 .aqn/.trn" \
				types:"PSO2 Skeleton AQN/TRN (*.aqn,*.trn)|*.aqn;*.trn|All Files (*.*)|*.*|"
        
		if (boneFileName != undefined) then
		(		
			startPath = getFilenamePath(getThisScriptFilename())
			dotnet.loadAssembly (startPath + @"\include\AquaLib\AquaModelLibrary.dll")
			aquaUtil = dotNetObject "AquaModelLibrary.AquaUtil"
			aquaUtil.ReadBones (dotNetObject "System.String" boneFileName)
				
			--SkelImport boneFileName prsVals.checked autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked KeepBoneIds.checked
			--SkelImport boneFileName false autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked KeepBoneIds.checked
			SkelImportNET aquaUtil.aquaBones.item[0] false autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked KeepBoneIds.checked
		) 
		
		-- Redraw max viewports
		max views redraw
	)
	
	
	on exportAQNButton pressed do
	(
		-- Open up a dialog box
		local objFileName = getSaveFileName "Export pso2 .aqn/.trn" \
				types:"pso2 .aqn (*.aqn)|*.aqn|pso2 .trn (*.trn)|*.trn|All Files (*.*)|*.*|"
		
		--Export the skeleton
		if (objFileName != undefined) then
		(
			SkelExport objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked ngsExport.checked
		)

	)
	
	on exportAQPButton pressed do
	(
		-- Open up a dialog box
		local objFileName = getSaveFileName "Export pso2 .aqp/.trp/.aqo/.tro/.prm (prm requires a single selected object)" \
				types:"pso2 .aqp (*.aqp)|*.aqp|pso2 .trp (*.trp)|*.trp|pso2 .aqo (*.aqo)|*.aqo|pso2 .tro (*.tro)|*.tro|pso2 .prm (*.prm)|*.prm"


		if (objFileName != undefined) then
		(	
			--Don't let user export filename greater than 32 characters due to size limits
			if (filenameFromPath objFileName).count > 32 then
			(
				messageBox "Filename with extension must be less than 32 characters long"
			) else
			(
				if (findstring objFileName ".prm") != undefined then
				(
					PRMExportNet objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked prog
				) else 
				(
					GeoExportNet objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked binorm.checked playerModel.checked difWhite.checked unrmAvg.checked faceNormals.checked boundZero.checked baHack.checked meshDummies.checked prog ngsExport.checked rigidWeights.checked
				)
				prog.value = 0
			)
		)

	)
	
	on openAQMButton pressed do
	(
		FileIn @"PSO2AQM_IO_v1.5.3.ms"
	)
	
	on importTCBButton pressed do
	(
		-- Open up a dialog box
		local	colFileName = getOpenFileName caption:"Import Phantasy Star Online 2 .tcb" \
				types:"PSO2 Collision (*.tcb)|*.tcb|All Files (*.*)|*.*|"
        
		if (colFileName != undefined) then
		(
			importTCB colFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked 
		)
    )
)
createDialog pso2ImportRollout 220 770
)