ClearListener()
FileIn @"include\MaxScriptExtensions\FileStreamReader.ms"
FileIn @"include\MaxScriptExtensions\FileUtils.ms"
FileIn @"include\UnusedBoneRemover.ms"
FileIn @"include\AQNBoneImportv1.4.ms"
FileIn @"include\AQPGeoExportv1.0.ms"

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
	
struct matInfo
(
	mateIndex,
	tsetIndex
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
	aquaMethods = dotnetobject "AquaModelLibrary.AquaMethods.AquaObjectMethods"
	modelMat = model.mateList.item[model.meshList.item[meshNum].mateIndex]
	matName = aquaMethods.GetMatName(modelMat);
	
	if meshNum != 0 then
	(
		newMaterial.numsubs += 1
	)
	matId = newMaterial.numsubs
	
	--Get extra info that we place in the material name
	shadIndex = model.meshList.item[meshNum].shadIndex
	shadSet = aquaMethods.GetShaderNames model shadIndex
	
	--Get opacity type
	opacityType = aquaMethods.GetMatOpacity(modelMat);
	
	--Assemble and set name
	matName = "(" + shadSet.item[0] + "," + shadSet.item[1] + ")" + "{" + opacityType + "}" + matName
	newMaterial[matId] = standard name:matName
	
	--Set 2-sided flag
	rendIndex = model.meshList.item[meshNum].rendIndex
	if model.rendList.item[rendIndex].twosided > 0 then
	(
		newMaterial[matId].twoSided = true
	)
	
	--Might be BGRA order? If so, fix later
	newMaterial[matId].diffuse = color (modelMat.diffuseRGBA.X * 255) (modelMat.diffuseRGBA.Y * 255) (modelMat.diffuseRGBA.Z * 255)
	
	tsetindex = model.meshList.item[meshNum].tsetIndex
	tset = aquaMethods.GetTexListNames model tsetindex
	
	if tset.count > 0 then
	(
		diffuseMapFile = tset.item[0]
	)
	if tset.count > 1 then
	(
		specularMapFile = tset.item[1]
	)
	if tset.count > 2 then
	(
		specularLevelMapFile = tset.item[2]
	)
	if tset.count > 3 then
	(
		bumpMapFile = tset.item[3]
	)
	
	if diffuseMapFile != undefined then
	(
		--Set texture map and leave a placeholder name if it doesn't exist or isn't in the right folder
		diffMap = bitmapTexture filename: (filepath + diffuseMapFile) name:(getFilenameFile diffuseMapFile)
		newMaterial[matId].maps[2] = diffMap 
		newMaterial[matId].mapEnables[2] = true
		
		if (getFiles (filepath + diffuseMapFile)).count != 0 then
		(
			showTextureMap newMaterial[matId] diffMap true
		)
	)
		
	if specularMapFile != undefined then
	(
		newMaterial[matId].specularMap = bitmapTexture filename: (filepath + specularMapFile) name:(getFilenameFile specularMapFile)
		
		--We don't want to enable this since this isn't necessarily the correct map for this; We're just using the material slots for set things
		newMaterial[matId].specularMapEnable = false 
	)
	if specularLevelMapFile != undefined then
	(
		newMaterial[matId].specularLevelMap = bitmapTexture filename: (filepath + specularLevelMapFile) name:(getFilenameFile specularLevelMapFile)
		
		--We don't want to enable this since this isn't necessarily the correct map for this; We're just using the material slots for set things
		newMaterial[matId].specularLevelMapEnable = false 
	)
	if bumpMapFile != undefined then
	(
		newMaterial[matId].bumpMap = bitmapTexture filename: (filepath + bumpMapFile) name:(getFilenameFile bumpMapFile)
		
		--We don't want to enable this since this isn't necessarily the correct map for this; We're just using the material slots for set things
		newMaterial[matId].bumpMapEnable = false 
	)
		
	matId
)

fn importAQO fileName useBones useAutoSize autoSizeValue useYZFlip keepBoneIds prog =
(
	with undo off
	(
		startPath = getFilenamePath(getThisScriptFilename())
		currentPath = getFilenamePath(fileName)
		dotnet.loadAssembly (startPath + @"\include\AquaLib\AquaModelLibrary.dll")
		aquaUtil = dotNetObject "AquaLibrary.AquaUtil"
		aquaUtil.ReadModel (dotNetObject "System.String" fileName)
			
		
		pso2BoneArray = undefined
			
		--If the user wants to import PSO2 skinning, do so
		if (useBones) then
		(
			boneFileName = filterString (filenameFromPath fileName) "."
			boneFileName = (currentPath + boneFileName[1] + ".aqn")
		    aquaUtil.ReadBones (dotNetObject "System.String" boneFileName)
			
			if ((doesFileExist boneFileName) == false) then
			(
				boneFileName = undefined
			)
			
			if (boneFileName != undefined) then
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
					if(model.meshList.item[i].mateIndex == mat.mateIndex and model.meshList.item[i].tsetIndex == mat.tsetIndex) then
					(
						matId = j - 1
					)
				)
				if matId == -1 then
				(
					matId = SetupMaterials model (getFileNamepath fileName) i newMaterial matInfoArray
					append matInfoArray (matInfo mateIndex:model.meshList.item[i].mateIndex  tsetIndex:model.meshList.item[i].tsetIndex)
				)
				
				--Get vert array
				vertArray = #()
				vsetIndex = model.meshList.item[i].vsetIndex
				vertCount = model.vtxlList.item[vsetIndex].vertPositions.count
				
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
				faceArray = #()
				psetIndex = model.meshList.item[i].psetIndex
				psetTris = model.strips.item[psetIndex].getTriangles(true)
				
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
				setMatID newMesh matId
				--update newMesh
				
				if model.vtxlList.item[i].uv1List.Count > 0 then
				(
					uv1List = model.vtxlList.item[i].uv1List
					meshop.setNumMaps newMesh ((meshop.getNumMaps newMesh) + 1) keep:true
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
					--free uv1List
				)
				
				if model.vtxlList.item[i].uv2List.Count > 0 then
				(
					uv2List = model.vtxlList.item[i].uv2List
					meshop.setNumMaps newMesh ((meshop.getNumMaps newMesh) + 1) keep:true
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
					--free uv2List
				)
				
				if model.vtxlList.item[i].uv3List.Count > 0 then
				(
					uv3List = model.vtxlList.item[i].uv3List
					meshop.setNumMaps newMesh ((meshop.getNumMaps newMesh) + 1) keep:true
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
					--free uv3List
				)
				
				if model.vtxlList.item[i].vertColors.Count > 0 then
				(
					setNumCPVVerts newMesh newMesh.numverts
					colorList = model.vtxlList.item[i].vertColors
					
					-- Set vertex coloring -- 
					for j = 0 to (colorList.Count - 1) do
					(
						setvertcolor newMesh (j + 1) (color (colorList.item[j][1]) (colorList.item[j][2]) (colorList.item[j][3]) (colorList.item[j][4]))
						meshop.setvertalpha newMesh -2 (j + 1) (colorList.item[j][4])
					)
					defaultVCFaces newMesh
					newMesh.showVertexColors = true 
					--free colorList
				)
				
				if model.vtxlList.item[i].vertColor2s.Count > 0 then
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
				
				if model.vtxlList.item[i].vertNormals.Count > 0 and precisionNormals then
				(
					nrmList = model.vtxlList.item[i].vertNormals
					--Set Normals
					max modify mode
					select newMesh
					addmodifier newMesh (Edit_Normals ()) ui:off
					nMNorms = newMesh.modifiers[#Edit_Normals]	
					
					--Finish setting normals
					newMesh.Edit_Normals.MakeExplicit selection:#{1..newMesh.verts.count}
					EN_convertVS = newMesh.Edit_Normals.ConvertVertexSelection
					EN_setNormal = newMesh.Edit_Normals.SetNormal
					EN_getNormal = newMesh.Edit_Normals.GetNormal
					EN_getVertexID = newMesh.Edit_Normals.GetVertexID
					EN_getNormalID = newMesh.Edit_Normals.GetNormalID
					EN_getDegree = newMesh.Edit_Normals.GetFaceDegree
					EN_setSelection = newMesh.Edit_Normals.SetSelection
					EN_setExplicit = newMesh.Edit_Normals.SetNormalExplicit
					normID = #{}

					
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
					if model.vtxlList.item[i].vertWeights.Count > 0 and model.vtxlList.item[i].vertWeightIndices.Count > 0 then
					(
						wts = model.vtxlList.item[i].trueVertWeights
						ids = model.vtxlList.item[i].trueVertWeightIndices
						
						bonePalette = model.vtxlList.item[i].bonePalette
						
						--Apply Skinned Nodes 
						for b = 0 to (bonePalette.count - 1) do
						(
							tempB = bonePalette.item[b] + 1
							SkinOps.AddBone skinMod (pso2BoneArray[tempB].MaxBone) 0
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
						SkinOps.AddBone skinMod (pso2BoneArray[boneId].MaxBone) 0
					)
					prog.value += 50 / (model.objc.vsetCount)
				) else
				(
					prog.value += 100 / (model.objc.vsetCount)
				)
				
				Max create mode
				
				update newMesh
				append importList newMesh
			)
			prog.value = 0
			group importList name:((getFilenameFile filename) + "_[" + mdl as string + "]")
		)
		
		completeRedraw()
		print ( fileName as string +" file imported!")
	)
)


	
rollout pso2ImportRollout "PSO2 Model Importer"
(
	--------------------
	-- User Interface --
	--------------------
	group "About"
	(
		label lab1 "PSO2 Model Importer"
		Label lab2 "By Shadowth117"
	)
	group "Settings"
	(
		checkBox autoSizeCheckBox "Rescale" checked:true align:#center
		spinner autoSizeSpinner "Scale by:" align:#center type:#float range:[0,10000,100] enabled:false
		checkBox YZCheckBox "Y-Z Axis Flip" checked:true align:#center
		checkBox useBones "Skin with aqn/trn" checked:true align:#center
		checkBox preciseNormals "Precise Normals" checked:true align:#center
		checkBox importLevelOfDetail "Import LOD models" checked:false align:#center
		checkBox KeepBoneIds "Bone IDs in object name" checked:true align:#left
		progressbar prog color:blue
	)	
	group "Import"
	(
		button importButton "Import..."
		button importPath "Batch Import..."
	)
	group "Export AQP/TRP (To be replaced)"
	(
		button exportAQPButton "Export..."
		checkBox playerModel "Player Model (Add UNRMS)" checked:true align:#left
		checkBox difWhite "White Diffuse Tint" checked:true align:#left
		checkBox unrmAvg "Average UNRM Normals" checked:true align:#left
		checkBox faceNormals "Use Face Normals" checked:false align:#left
		checkBox boundZero "Zero out bounds" checked:false align:#left
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
	
	on importButton pressed do
	(
		
		local objFileName = undefined
		-- Open up a dialog box
		objFileName = getOpenFileName caption:"Import Phantasy Star Online 2 model" \
					types:"PSO2 Model (*.aqo, *.tro, *.aqp, *.trp)|*.aqo;*.tro;*.aqp;*.trp|All Files (*.*)|*.*|"
        if (objFileName != undefined) then
		(
			importLOD = importLevelOfDetail.checked
			precisionNormals = preciseNormals.checked
			importAQO objFileName useBones.checked autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked true prog
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
		local objFileName = getOpenFileName caption:"Import Phantasy Star Online 2 model" \
					types:"PSO2 Model (*.aqo, *.tro, *.aqp, *.trp)|*.aqo;*.tro;*.aqp;*.trp|All Files (*.*)|*.*|"
		
		if objFileName != undefined then--if the user did not cancel
        (	
			thePath = getFilenamePath objFileName
			
          theFiles = (getFiles (thePath+"\\*.aqp")) + (getFiles (thePath+"\\*.aqo")) + (getFiles (thePath+"\\*.trp")) + (getFiles (thePath+"\\*.tro"))   
		  for objFileName = theFiles do-- go through all of them
          (
			print objFileName
			importLOD = importLevelOfDetail.checked
			precisionNormals = preciseNormals.checked
		    importAQO objFileName useBones.checked autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked true prog
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
			aquaUtil = dotNetObject "AquaLibrary.AquaUtil"
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
			SkelExport objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked
		)

	)
	
	on exportAQPButton pressed do
	(
		-- Open up a dialog box
		local objFileName = getSaveFileName "Export pso2 .aqp/.trp/.aqo/.tro" \
				types:"pso2 .aqp (*.aqp)|*.aqp|pso2 .trp (*.trp)|*.trp|pso2 .aqo (*.aqo)|*.aqo|pso2 .tro (*.tro)|*.tro|"


		if (objFileName != undefined) then
		(	
			--Don't let user export filename greater than 32 characters due to size limits
			if (filenameFromPath objFileName).count > 32 then
			(
				messageBox "Filename with extension must be less than 32 characters long"
			) else
			(
				GeoExport objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked playerModel.checked difWhite.checked unrmAvg.checked faceNormals.checked boundZero.checked baHack.checked
			)
		)

	)
	
	on openAQMButton pressed do
	(
		FileIn @"PSO2AQM_IO_v1.5.1ms"
	)
	
)
createDialog pso2ImportRollout 180 680
)