/*
	PSO2 .aqp/.aqo geometry export

	-Huge Thanks to TGE for function(s) from other scripts
	-Thanks to Liinko for his DetachElementsFromSkin function from the FFXIV Modding Tool script
*/

ClearListener()
FileIn @"MaxScriptExtensions\FileStreamReader.ms"
FileIn @"MaxScriptExtensions\FileUtils.ms"
FileIn @"UnusedBoneRemover.ms"
FileIn @"AQNBoneImportv1.3.ms"

struct matSetExtras
(
	ShaderList,
	MatShaderIndex,
	MatAlphaType,
	MatPlayer,
	TextureSets,
	TextureIdSets,
	TextureCount
	
)

struct pSetOff 
(
	CountOff,
	FaceOff
)

struct uNRMStruct
(
	MeshNum,
	VertID
)

struct uNRMHolder
(
	UNRMs,
	UNRMVertCount
)

struct aqpBounding
(
	OrigX,
	OrigY,
	OrigZ,
	Radius,
	DiffX,
	DiffY,
	DiffZ
)

struct pso2Vert
(
	VertPos,
	VertWeights,
	VertBones,
	VertNormal,
	VertBinormalArray,
	VertTangentArray,
	VertColorArray,
	VertColor2Array,
	VertUV1Array,
	VertUV2Array,
	VertUV3Array,
	VertFaceArray,
	VertUNRMs
)

struct pso2Mesh
(
	MeshMat,
	MeshMatId,
	MeshFaces,
	MeshVerts,
	MeshEdgeVerts,
	MeshId,
	MeshBonePalette,
	MeshValidVTypes,
	MeshVertSize   
)

struct VSetOff
(
	VTXEOff,
	VTXLOff,
	BPalOff,
	EVertOff
)

fn WriteFixedLengthString stream str len =
(
	str = substring str 1 len -- avoid going over
	extraSpace = len - (str.count) --calculate space left to 20 (if any)
	WriteString stream str -- name
	fseek pso2Model (-1) #seek_cur
	for e = 1 to extraSpace do -- add padding to reach 0x20 if needed
	(
		WriteByte stream 0x0
	)
)

fn originMinMax objList ResizeChecked ResizeValue YZRot =
(
	maxPoint = undefined
	minPoint = undefined
	
	--Get maximum xyz values of every vertex in the mesh(es) given
	for o in objList do
	(
		count = getNumVerts o
		for i = 1 to count do
		(
			vert = getVert o i
			if maxPoint == undefined then
			(
				maxPoint = copy vert
				minPoint = copy vert
			) else
			(
				if maxPoint.x < vert.x then 
				( 
					maxPoint.x = vert.x
				)
				if minPoint.x > vert.x then 
				( 
					minPoint.x = vert.x 
				)
				if maxPoint.y < vert.y then 
				( 
					maxPoint.y = vert.y 
				)
				if minPoint.y > vert.y then 
				( 
					minPoint.y = vert.y 
				)
				if maxPoint.z < vert.z then 
				( 
					maxPoint.z = vert.z 
				)
				if minPoint.z > vert.z then 
				( 
					minPoint.z = vert.z 
				)
			)
		)
	)
	
	--Calculate difference between all max and min points, then calculate model's center
	difference = [(abs(maxPoint.x - minPoint.x) / 2), (abs(maxPoint.y - minPoint.y) / 2), (abs(maxPoint.z - minPoint.z) / 2)]
	origin = [maxPoint.x - difference.x, maxPoint.y - difference.y, maxPoint.z - difference.z]
	
	--Calculate furthest real vertex in mesh(es) and store the distance for a bounding radius
	radius = 0
	for o in objList do
	(
		count = getNumVerts o
		for i = 1 to count do
		(
			vert = getVert o i
			dist = distance origin vert
			if dist > radius then
			(
				radius = dist
			)
		)
	)
	/*
	print("Max Values " + "x: " + (maxPoint.x as string) + " y: " + (maxPoint.y as string) + " z: " + (maxPoint.z as string) )
	print("Min Values " + "x: " + (minPoint.x as string) + " y: " + (minPoint.y as string) + " z: " + (minPoint.z as string) )
	print("Origin Values " + "x: " + (origin.x as string) + " y: " + (origin.y as string) + " z: " + (origin.z as string))
	print("Radius: " + (radius as string))
	*/
	
	--Recalculate based on scale as needed
	if ResizeChecked == true then
	(
		origin.x *= ResizeValue
		origin.y *= ResizeValue
		origin.z *= ResizeValue
		radius *= ResizeValue
		difference.x *= ResizeValue
		difference.y *= ResizeValue
		difference.z *= ResizeValue
	)
	
	--Handle YZ orientating as needed
	if YZRot == true then
	(
		temp = -origin.z
		origin.z = origin.y
		origin.y = temp
		
		temp = difference.z
		difference.z = difference.y
		difference.y = temp
	)
	
	bounds = (aqpBounding OrigX:origin.x OrigY:origin.y OrigZ:origin.z Radius:radius DiffX:difference.x DiffY:difference.y DiffZ:difference.z)
)

fn GetUniqueMats objList =
(
	matArray = #()
	for obj = 1 to objList.count do
	(
		match = false
		for m = 1 to matArray.count while match == false do
		(
			if objList[obj].MeshMat == matArray[m] then
			(
				match = true
				objList[obj].MeshMatId = m
			)
		)
		if match == false then
		(
			append matArray objList[obj].MeshMat
			objList[obj].MeshMatId = matArray.count
		)
	)
	
	matArray
)

--Find shaders and alpha settings for given material set
fn GetMatExtras aqpMats =
(
	texCount = 0
	matExtras = matSetExtras()
	for mat in aqpMats do
	(
		--Filterstring first ( ) for shadertype, second shadertype after "," inside shadertype ( ), filterstring { } for the alpha type. Append unique shaders and set the index for the respective materials. Append all alpha types
		shaderSet = #()
		alphaType = #()
		strStart = findstring mat.name "("
		if strStart != undefined then
		(
			strStart += 1
			strLength = (findstring mat.name ")") 
			if strLength != undefined then
			(
				strLength -= strStart
				if strLength != 0 then
				(
					shaderSet = filterstring (substring mat.name strStart strLength) ","
				) 
			)
		)
		if shaderSet = undefined then
		(
			shaderSet[1] = "0100p"
			shaderSet[2] = "0100"
		)
		
		strStart = findstring mat.name "{"
		if strStart != undefined then
		(
			strStart += 1
			strLength = (findstring mat.name "}") 
			if strLength != undefined then
			(
				strLength -= strStart
				if strLength != 0 then
				(
					alphaType = substring mat.name strStart strLength
				) 
			)
		) else 
		(
			alphaType = "blendalpha"
		)
		
		plFlag = false
		if matchPattern mat.name pattern:"*[pl]*" then
		(
			plFlag = true
			append matExtras.MatPlayer true
		) else
		(
			append matExtras.MatPlayer false
		)
		
		shaderFound = undefined
		for shd=1 to matExtras.ShaderList.count while shaderFound == undefined do
		(
			if matExtras.ShaderList[shd][0] == shaderSet[0] and matExtras.ShaderList[shd][1] == shaderSet[1] then
			(
				shaderFound = shd
			)
		)
		if shaderFound == undefined then
		(
			append matExtras.ShaderList shaderSet
			shaderFound = matExtras.ShaderList.count
		)
		
		append matExtras.MatShaderIndex = shaderFound-1
		append matExtras.MatAlphaType = alphaType
		
		--Grab textures and assemble texture sets
		textureSet = #()
		textureIdSet = #()
		if plFlag == true then
		(
			for i = 1 to 4 do
			(
				append textureIdSet texCount
				texCount +=1
			)
			append textureSet "pl_body_diffuse.dds"
			append textureSet "pl_body_multi.dds"
			append textureSet "pl_body_decal.dds"
			append textureSet "pl_body_normal.dds"
		) else
		(
			if mat.diffuseMap != undefined then
			(
				dif = (getFilenameFile mat.diffuseMap.filename) + ".dds"
				append textureSet dif
				append textureIdSet texCount
				texCount += 1
			)
			if mat.specularMap != undefined then
			(
				spec = (getFilenameFile mat.specularMap.filename) + ".dds"
				append textureSet spec
				append textureIdSet texCount
				texCount += 1
			)
			if mat.specularLevelMap != undefined then
			(
				specLev = (getFilenameFile mat.specularLevelMap.filename) + ".dds"
				append textureSet specLev
				append textureIdSet texCount
				texCount += 1
			)
			if mat.bumpMap != undefined then
			(
				bump = (getFilenameFile mat.specularBumpMap.filename) + ".dds"
				append textureSet bump
				append textureIdSet texCount
				texCount += 1
			)
		)
		append TextureSets textureSet
		append TextureIdSets textureIdSet
	)
	matExtras.TextureCount = texCount
	
	matExtras
)

fn GetFacesByMatId obj =
(
	matIds = #()
	faceCount = getNumFaces obj.mesh
	
	for f = 1 to (getNumFaces obj.mesh) do
	(
		id = getfacematid obj.mesh f
		if matIds[id] == undefined then
		(
			matIds[id] = -#{1..faceCount}
		)
		matIds[id][f] = true
	)
	
	matIds
)

fn getAllMaterialGroups obj =
(
	local faceArray,liveArray,materialList,faceCount

	materialList = #()

	faceCount = getNumFaces obj.mesh

	faceArray = #{1..faceCount}
	
	matIdFaces = GetFacesByMatId obj
	usedMatIds = #()
	
	for i=1 to matIdFaces.count do
	(
		if matIdFaces[i] != undefined then
		(
			append usedMatIds i
		)
	)
	
	for i in usedMatIds do
	(
		append materialList (faceArray-matIdFaces[i])
	)
	
	materialList
)
	
fn meshSplitter obj objInvArray =
(
	max modify mode
	splitMeshes = #()
	skinMode = true
	if (for m in obj.modifiers where isKindOf m skin collect m).count < 1 then
	(
		skinMode = false
	)
	
	--CREATE A BIT ARRAY TO INVERT FOR THE VERTICES
	faceCount = getNumFaces obj.mesh
	faceArray = #{1..faceCount}
	
	if skinMode == true then
	(
		--detachElementsWithSkin logic start. Original script by Liinko
		--BAKE AND REMOVE ZERO WEIGHTS ON THE SKIN
		objSkin = obj.skin
		modPanel.setCurrentObject objSkin
		vertCount = (skinOps.GetNumberVertices objSkin)
		skinOps.SelectVertices objSkin vertCount
		skinOps.bakeSelectedVerts objSkin
		objSkin.clearZeroLimit = 0.000
		skinOps.RemoveZeroWeights objSkin

		--STORE THE VERTEX WEIGHTS
		vertWeightsArray = #()

		for ele in objInvArray do
		(
			verts = meshop.getVertsUsingFace obj.mesh (faceArray - ele)
			vertsEle = #()

			for v in verts do
			(
				weights = #()
				_bones = #()

				wc = skinOps.GetVertexWeightCount objSkin v

				for b = 1 to wc do
				(
					append weights (skinOps.GetVertexWeight objSkin v b)
					append _bones (skinOps.GetVertexWeightBoneID objSkin v b)
				)
				while weights.count > 4 do
				(
					lowestWeightId = 1
					lowestWeight = weights[1]
					for i=2 to weights.count do
					(
						if lowestWeight > weights[i] then
						(
							lowestWeightId = i
							lowestWeight = weights[i]
						)
					)
					deleteItem _bones lowestWeightId
					deleteItem weights lowestWeightId
				)
				append vertsEle #(_bones,weights)
			)

			append vertWeightsArray vertsEle

		)
	)

	--CLONE AND FIX THE SKIN WEIGHTS
	for i = 1 to objInvArray.count do
	(
		--DUPE THE OBJECT
		max create mode
		maxOps.cloneNodes obj newNodes:&newObjs
		select newObjs[1]
		addModifier newObjs[1] (turn_to_mesh()) before:newObjs[1].modifiers.count	
		maxOps.CollapseNodeTo newObjs[1] newObjs[1].modifiers.count false
			
		meshop.deleteFaces newObjs[1] objInvArray[i]
		
		max modify mode
		if skinMode == true then
		(
			newObjSkin = newObjs[1].skin

			modPanel.setCurrentObject newObjSkin

			--LOAD THE VERTEX WEIGHTS
			vCount = (skinOps.GetNumberVertices newObjSkin)

			for v = 1 to vCount do
			(
				skinOps.ReplaceVertexWeights newObjSkin v vertWeightsArray[i][v][1] vertWeightsArray[i][v][2]
			)
		)
		append splitMeshes newObjs[1]
	)
	
	splitMeshes
)

fn splitMeshByMaterial meshes =
(
	max modify mode
	splitMeshes = #()
	for obj in meshes do
	(
		matArray = getAllMaterialGroups obj
		matSplitMeshes = meshSplitter obj matArray
		for mObj in matSplitMeshes do
		(
			append splitMeshes mObj
		)
	)
	
	splitMeshes
)

fn boneCountSplitter obj boneLimit =
(
	fCount = (getNumFaces obj.mesh)
	idToRemove = -#{1..fCount}
	objOut = #()
	objEdgeVertsList = #()
	objFaceArrayList = #()
	filled = false
	meshop.setNumVDataChannels obj.mesh ((meshop.getNumVDataChannels obj.mesh) + 1) keep:true
	meshop.setVDataChannelSupport obj.mesh 26 false
	
	while filled == false do
	(
		objSkin = obj.skin
		modPanel.setCurrentObject objSkin

		fStart = undefined 
		
		for i = 1 to idToRemove.count while fstart == undefined do
		(
			if idToRemove[i] == false then
			(
				fStart = i
			)
		)
			
		objBones = #()
		objFaceArray = #{1..fCount}
		for f = fstart to fCount do
		(
			faceBones = #()
			newBones = 0
			
			--Get verts of the face
			faceVerts = (meshop.getVertsUsingFace obj.mesh f) as array
			faceVertsCheck = #() --Array for gathering edge vert candidates
			--Get bones in this face
			for v in faceVerts do
			(
				weightCount = skinOps.GetVertexWeightCount objSkin v
				
				vertCheck = false
				for b = 1 to weightCount do
				(
					bId = (skinOps.GetVertexWeightBoneID objSkin v b)
					appendIfUnique faceBones bId
					if (finditem objBones bId) == 0 then (vertCheck = true)
				)
				if vertCheck == true then (append faceVertsCheck v)
			)
			
			--Check what's new
			for fb in faceBones do
			(
				if (findItem objBones fb) == 0 then
				(
					newBones += 1
				)
			)
			
			--If enough space or no new, add to the object amount as well as mark face
			if newBones + objBones.count <= boneLimit then
			(
				for fb in faceBones do
				(
					appendIfUnique objBones fb
				)
				objFaceArray[f] = false
			) else 
			(
				for vert in faceVertsCheck do (appendIfUnique objEdgeVertsList vert)
			)
		)
		append objFaceArrayList objFaceArray
		
		idToRemove += -objFaceArray 
		
		filled = true
		for i = 1 to idToRemove.count do
		(
			if idToRemove[i] == false then
			(
				filled = false
			)
		)
	)
	
	--Mark edge verts
	for vert in objEdgeVertsList do
	(
		meshop.setVDataValue obj.mesh 26 vert 5.0
	)
	
	objOut = meshSplitter obj objFaceArrayList
	
	objOut
)

--Split meshes until each resulting mesh has less bones than the limit given
fn splitMeshByBoneCount meshes boneLimit =
(
	RemoveUnusedBones meshes
	
	splitMeshes = #()
	for obj in meshes do
	(
		if (for m in obj.modifiers where isKindOf m skin collect m).count > 0 then
		(
			max modify mode
			objSkin = obj.skin
			modPanel.setCurrentObject objSkin
			if (skinOps.GetNumberBones objSkin) > boneLimit then
			(
				boneSplitMeshes = boneCountSplitter obj boneLimit
				for bObj in boneSplitMeshes do
				(
					append splitMeshes bObj
				)
			) else
			(
				append splitMeshes obj
			)
		) else 
		(
			append splitMeshes obj
		)
	)
	
	RemoveUnusedBones splitMeshes
	
	splitMeshes
)

fn pso2VertOptimizer meshes UNRMExport =
(
	meshData = #()
	for obj in meshes do
	(
		local pso2VertArr = #()
		fCount = (getNumFaces obj.mesh)
		objFaces = #()
		objEdgeVerts = #()
		
		max modify mode
		objSkin = obj.skin
		modPanel.setCurrentObject objSkin
		
		--Loop through faces for each mesh. Append the vertices, their values for respective maps on respective faces, and said faces to an array of the original vertex indices.
		for f = 1 to fCount do
		(
			--Get verts of the face
			faceVerts = (getFace obj.mesh f)
			append objFaces faceVerts
			
			--Get map information for each vertex
			for v = 1 to faceVerts.count do
			(
				--Create temporary struct for comparison later
				local tempVert = pso2Vert()
				
				--Set the vert if it's not there
				if pso2VertArr[faceVerts[v]] == undefined then
				(
					tempVert.VertPos = getVert obj.mesh faceVerts[v]
					tempVert.VertNormal = getNormal obj.Mesh faceVerts[v]
					
					wc = skinOps.GetVertexWeightCount objSkin v
					weights = #()
					_bones = #()
					for b = 1 to wc do
					(
						append weights (skinOps.GetVertexWeight objSkin v b)
						append _bones (skinOps.GetVertexWeightBoneID objSkin v b)
						appendIfUnique objBonePalette (skinOps.GetVertexWeightBoneID objSkin v b)
					)
					
					tempVert.VertBones = _bones
					tempVert.VertWeights = weights
					
					if (meshop.getVDataValue obj.mesh 26 faceVerts[v]) == 5.0 then ( append objEdgeVerts faceVerts[v] ) 
					
					append tempVert.VertFaceArray #(f)
				)
				
				--Get vert colors
				if (meshop.getMapSupport obj.mesh 0) == true then
				(
					vcolor = (meshop.getMapVert obj.mesh 0 ((meshop.getMapFace obj.mesh 0 f)[v])) as color
					if (meshop.getMapSupport obj.mesh -2) == true then
					(
						vcolor.alpha = (meshop.getMapVert $.mesh -2 (meshop.getMapFace $.mesh -2 1)[1]).x
					) else 
					(
						vcolor.alpha = 0xFF;
					)
					append tempVert.VertColorArray vcolor
				) else
				(
					append tempVert.VertColorArray undefined
				)
				
				--Get secondary vert colors (unsure if that's actually what these are, but w/e). For now, pull from maps 4 and 5
				if (meshop.getMapSupport obj.mesh 4) == true then
				(
					vcolor = (meshop.getMapVert obj.mesh 4 ((meshop.getMapFace obj.mesh 4 f)[v])) as color
					if (meshop.getMapSupport obj.mesh 5) == true then
					(
						vcolor.alpha = (meshop.getMapVert $.mesh 5 (meshop.getMapFace $.mesh 5 1)[1]).x
					) else
					(
						vcolor.alpha = 0xFF;
					)
					append tempVert.VertColor2Array vcolor
				) else
				(
					append tempVert.VertColor2Array undefined
				)
				
				--Get first set of UVs and assign binormals and tangents
				if (meshop.getMapSupport obj.mesh 1) == true then
				(
					uv1 = (meshop.getMapVert obj.mesh 1 ((meshop.getMapFace obj.mesh 1 f)[v]))
					append tempVert.VertUV1Array uv1
					
					--Calculate binormal + tangent, based off this post: https://forums.cgsociety.org/t/finding-bi-normals-tangents/975005/3
					local dV1 = pso2VertArr[faceVerts[v]].VertPos.x - pso2VertArr[faceVerts[v]].VertPos.y
					local dV2 = pso2VertArr[faceVerts[v]].VertPos.x - pso2VertArr[faceVerts[v]].VertPos.z
					local dUV1 = uv1.x - uv1.y
					local dUV2 = uv1.x - uv1.z
					local sign = if (dUV1.x * dUV2.y - dUV1.y * dUV2.x) < 0 then -1 else 1
					local tangent = [1,0,0]

					tangent.x = dV1.x * dUV2.y - dUV1.y * dV2.x
					tangent.y = dV1.y * dUV2.y - dUV1.y * dV2.y
					tangent.z = dV1.z * dUV2.y - dUV1.y * dV2.z
					tangent = (normalize tangent) * sign
					local binormal = (normalize (cross pso2VertArr[faceVerts[v]].VertNormal tangent)) * sign
					
					append tempVert.VertBinormalArray binormal
					append tempVert.VertTangentArray tangent
				) else
				(
					append tempVert.VertUV1Array undefined
					append tempVert.BinormalArray undefined
					append tempVert.TangentArray undefined
				)
				
				--Get second set of UVs
				if (meshop.getMapSupport obj.mesh 2) == true then
				(
					append tempVert.VertUV2Array (meshop.getMapVert obj.mesh 2 ((meshop.getMapFace obj.mesh 2 f)[v]))
				) else
				(
					append tempVert.VertUV2Array undefined
				)
				
				--Get third set of UVs
				if (meshop.getMapSupport obj.mesh 3) == true then
				(
					append tempVert.VertUV3Array (meshop.getMapVert obj.mesh 3 ((meshop.getMapFace obj.mesh 3 f)[v]))
				) else
				(
					append tempVert.VertUV3Array undefined
				)
				
				--Compare with previous vertex data if it existed. If all map data is the equivalent to an entry, append the face, else append all
				if pso2VertArr[faceVerts[v]] == undefined then
				(
					pso2VertArr[faceVerts[v]] = tempVert
				) else
				(
					--See if there's already an existing vertex with the same attributes
					arrCheck = true
					for i = 1 to pso2VertArr[faceVerts[v]].VertUV1Array.count while arrCheck == true do
					(
						--Check attribute equivalence. Ignore binormal/tangent arrays for this since they're generated from UV1 + vertex position and vertex position will remain the same
						if pso2VertArr[faceVerts[v]].VertColorArray != tempVert.VertColorArray or pso2VertArr[faceVerts[v]].VertColor2Array != tempVert.VertColor2Array or pso2VertArr[faceVerts[v]].VertUV1Array != tempVert.VertUV1Array or pso2VertArr[faceVerts[v]].VertUV2Array != tempVert.VertUV2Array or pso2VertArr[faceVerts[v]].VertUV3Array != tempVert.VertUV3Array then
						(
							--Add face to current vert data's equivalent faces list
							append pso2VertArr[faceVerts[v]].VertFaceArray[i] f
							arrCheck = false
						)
					)
					
					--If not found, add it as its own entry
					if arrCheck == false then
					(
						append pso2VertArr[faceVerts[v]].BinormalArray tempVert.BinormalArray 
						append pso2VertArr[faceVerts[v]].TangentArray tempVert.TangentArray 
						append pso2VertArr[faceVerts[v]].VertColorArray tempVert.VertColorArray 
						append pso2VertArr[faceVerts[v]].VertColor2Array tempVert.VertColor2Array 
						append pso2VertArr[faceVerts[v]].VertUV1Array tempVert.VertUV1Array 
						append pso2VertArr[faceVerts[v]].VertUV2Array tempVert.VertUV2Array 
						append pso2VertArr[faceVerts[v]].VertUV3Array tempVert.VertUV3Array
						append pso2VertArr[faceVerts[v]].VertFaceArray #(f)
					)

				)
			)
		)
		
		--Retrieve and adjust face data, creating new vertices when necessary. When creating vertices, note down all new ids with the old ids in an array for unrms
		for f = 1 to fCount do
		(
			faceVerts = objFaces[f]
			for v in faceVerts do
			(
				--loop through verts and access pso2VertArr with them. If the vert for that face isn't the first vertdata set for that vertex, create a new pso2Vert at end of vertarray with that data.
				faceFound == false
				for vertData = 1 to pso2VertArr[v].VertUV1Array.count while faceFound == false do
				(
					
					for face in pso2VertArr[v].VertFaceArray[vertData] while faceFound == false do
					(
						if f == face then
						(
							faceFound = true
						)
					)
					if faceFound == true and vertData != 1 then
					(
						tempVert = pso2Vert()
						tempVert.VertPos = pso2VertArr[v].VertPos
						tempVert.VertWeights = pso2VertArr[v].VertWeights
						tempVert.VertBones = pso2VertArr[v].VertBones
						tempVert.VertNormal = pso2VertArr[v].VertNormal
						append tempVert.VertBinormalArray   pso2VertArr[v].VertBinormalArray[vertData]
						append tempVert.VertTangentArray  	pso2VertArr[v].VertTangentArray[vertData]
						append tempVert.VertColorArray  	pso2VertArr[v].VertColorArray[vertData]
						append tempVert.VertColor2Array  	pso2VertArr[v].VertColor2Array[vertData]
						append tempVert.VertUV1Array  		pso2VertArr[v].VertUV1Array[vertData]
						append tempVert.VertUV2Array  		pso2VertArr[v].VertUV2Array[vertData]
						append tempVert.VertUV3Array  		pso2VertArr[v].VertUV3Array[vertData]
						append tempVert.VertFaceArray f
						
						pso2VertArr[pso2VertArr.count+1] = tempVert
						--append pso2VertArr[v].VertUNRMs pso2VertArr.count
						objFaces[f][v] = pso2VertArr.count
					)
				)
			)
		)
		
		--Get Valid Vert Types and Size
		validVertTypes = #()
		vertTypeSize = 0 
		append validVertTypes 0x0 --Position
		vertTypeSize += 0xC
		if objBonePalette > 1 then
		(
			append validVertTypes 0x1 --Bone Weights
			vertTypeSize += 0x10
		)
		append validVertTypes 0x2 --Normal
		vertTypeSize += 0xC
		if UNRMExport == true then
		(
			append validVertTypes 0x21 --Binormals
			append validVertTypes 0x20 --Tangents
			vertTypeSize += 0x18
		)
		if pso2VertArr[1].VertColorArray[1][1] != undefined then
		(
			append validVertTypes 0x3 --Vert Color
			vertTypeSize += 0x4
		)
		if pso2VertArr[1].VertColor2Array[1][1] != undefined then
		(
			append validVertTypes 0x4 --Vert Color 2?
			vertTypeSize += 0x4
		)
		if objBonePalette > 1 then
		(
			append validVertTypes 0xb --Bone Indices
			vertTypeSize += 0x4
		)
		if pso2VertArr[1].VertUV1Array[1][1] != undefined then
		(
			append validVertTypes 0x10 --Vert UV1
			vertTypeSize += 0x8
		)
		if pso2VertArr[1].VertUV2Array[1][1] != undefined then
		(
			append validVertTypes 0x11 --Vert UV2
			vertTypeSize += 0x8
		)
		if pso2VertArr[1].VertUV3Array[1][1] != undefined then
		(
			append validVertTypes 0x12 --Vert UV3
			vertTypeSize += 0x8
		)
		
		--append vertex, material, original mesh id, and face data to an array when done
		tempMesh 				 = pso2Mesh()
		tempMesh.MeshMat 		 = obj.material[GetFaceMatId obj.mesh 1]
		tempMesh.MeshFaces  	 = objFaces
		tempMesh.MeshVerts 		 = pso2VertArr
		tempMesh.MeshEdgeVerts   = objEdgeVerts
		tempMesh.MeshBonePalette = objBonePalette
		tempMesh.MeshValidVTypes = validVertTypes
		tempMesh.MeshVertSize    = vertTypeSize
		tempMesh.MeshId 		 = (getUserProp bMesh[i] "meshId")
		append meshData tempMesh
	)
	
	--return array with face, material, and vertex data for final write, delete export processed meshes
	meshData
)

--Check vert positions, normals, and first UV coord sets in order to find UNRM candidates 
fn calcUNRMs meshData =
(
	unrms = #()
	unrmVertCount = 0
	
	--boolean array to track progress
	meshCheckArr = #()
	for m = 1 to meshData.count do
	(
		meshCheck = #()
		for v = 1 to meshData[m].MeshVerts.count do
		(
			append meshCheck false
		)
		append meshCheckArr meshCheck
	)
	
	--Go through all verts and check for matches. Only append UNRMs if there's more than one in the unrm temp struct (ie at least one match)
	for m = 1 to meshData.count do
	(
		for v = 1 to meshData[m].MeshVerts.count do
		(
			unrm = #()
			append unrm (uNRMStruct MeshNum:m VertId:v)
			for n=m to meshData.count do
			(
				for w=1 to meshData[n].MeshVerts.count do
				(
					if (meshCheckArr[n][w] == true or (m == n and v == w)) then
					(
						continue
					)
					if (meshCheckArr[m][v].VertPos == meshCheckArr[n][w].VertPos and meshCheckArr[m][v].VertNormal == meshCheckArr[n][w].VertNormal and meshCheckArr[m][v].VertUV1Array[1] == meshCheckArr[n][w].VertUV1Array[1]) then
					(
						meshCheckArr[n][w] = true
						append unrm (uNRMStruct MeshNum:n VertId:w)
					)
				)
			)
			meshCheckArr[m][v] = true
			if unrm.count > 1 then
			(
				unrmVertCount += unrm.count
				append unrms unrm
			)
		)
	)
	
	UNRMContainer = (uNRMHolder UNRMs:unrms UNRMVertCount:unrmVertCount)
)

fn GeoExport aqpFile ResizeChecked ResizeValue YZRot UNRMExport =
(	
	ftype = getFilenameType aqpFile
	
	startPath = getFilenamePath(getThisScriptFilename())
	dotnet.loadAssembly (startPath + "\\NvTriStripDotNet.dll")
	
	--Gather meshes and create dummies for them for export
	baseMeshes = for g in geometry where g.parent == undefined and g.children.count == 0 collect g
	boneList = GetPSO2BoneArray false
	extraBoneList = #()
	for i=1 to baseMeshes.count do 
	(
		setUserProp baseMeshes[i] "meshId" (i-1)
		temp = dummy pos: ( [0, 0, 0] ) name: ( baseMeshes[i].name + "_dummy")
		temp.parent = boneList.BoneList[1]
		append extraBoneList temp
		if boneList.BoneOrdering == undefined then 
		(
			temp.name = "(" + ((boneList.BoneList.count + i-1) as string) + ")" + temp.name
		)
		setUserProp temp "NodeID" (boneList.BoneList.count + i-1)
	)
	
	--Export Bones
	currentPath = getFilenamePath aqpFile
	boneFileName = filterString (filenameFromPath aqpFile) "."
	boneFileName = (currentPath + boneFileName[1] + ".aqn")
	SkelExport boneFileName ResizeChecked ResizeValue YZRot
	
	--Split meshes by material - note: ReplaceVertexWeights automatically reevaluates weight(s) that do not total 1 by increasing the ratios of each existing weight proportionally to sum to 1. 
	aqpMeshes = splitMeshByMaterial baseMeshes
	
	--Possible 16 bone limit per mesh? If so, split per that as well. Generate dummy nodes for each final mesh with one name and a number. Dummy nodes should be placed before physics nodes (though this may not be required)
	aqpMeshes = splitMeshByBoneCount aqpMeshes 16
	
	--Check for used vertex types: (0x0 Vertex Position) (0x1 Vertex Weights) (0x2 Vertex Normal) (0x21 Binormals) (0x20 Tangents) (0x3 Vertex Color) (0x4 Vertex Color 2?) (0xb Weight Index) (0x10 UV1 Buffer) (0x11 UV2 Buffer) (0x12 UV3 Buffer)
		--Duplicate and separate vertices based on if multiple UV channels/VC channels exist for it. 
	aqpMeshData = pso2VertOptimizer aqpMeshes UNRMExport
	
	unrmData = undefined
	if UNRMExport == true then
	(
		unrmData = (calcUNRMs aqpMeshData)
	)
	
	--Get all unique mats and assign the array index of each to the respective objects
	aqpMats = GetUniqueMats aqpMeshData
	
	--Get all unique shaders from material, textures, texture sets, and alpha setting
	aqpMatExtra = GetMatExtras aqpMats

	--Calculate geometry bounds OBJC. As duplicated vertices and changed faces won't change this, we feed it the export prepped mesh array
	aqpBounds = originMinMax aqpMeshes ResizeChecked ResizeValue YZRot
	
	--Get rid of objects generated for export
	for o in aqpMeshes do (delete o)
	
	--Generate tristrips from tris
	aqpStrips = #()
	totalFaces = 0
	totalVertices = 0
	for m in aqpMeshData do
	(
		faceSet = #()
		for i = 1 to (m.MeshFaces.count) do
		(
			append faceSet (m.MeshFaces[i].x-1)
			append faceSet (m.MeshFaces[i].y-1)
			append faceSet (m.MeshFaces[i].z-1)
		)
		
		strippifier = dotNetObject "NvTriStripDotNet.NvStripifier"
		strips = strippifier.GenerateStripsReturner faceSet true
		append aqpStrips strips[1].indices
		totalFaces += strips[1].indices.count
		totalVertices += m.MeshVerts.count
	)
	
	pso2Model = fopen aqpFile "wb"
	
	relAddresses = #()
	fileOffset = 0x20
	--AFP Header
	if (ftype != "aqo" and ftype != "tro") then
	(
		fileOffset += 0x40                 --add extra offset to our main offset
		
		WriteString pso2Model "afp"        -- Type
		fseek pso2Model (-1) #seek_cur
		WriteByte pso2Model 0 
		WriteLong pso2Model 1              -- AFP container filecount. Seems to be used for level of detail models in observed cases; game simply won't try using LOD models if not provided
		WriteLong pso2Model 0              -- Reserve
		WriteLong pso2Model 1              -- Always 1
		WriteString pso2Model fname        -- Model filename
		fseek pso2Model (-2) #seek_cur
		WriteByte pso2Model 0x6F           -- Change aqp/trp to aqo/tro text. Game reads files the same regardless of aqo vs tro in observed cases, but good to be safe.
		
		extraSpace = 0x20 - (fname.count)  -- calculate space left to 0x20 (if any)
		for e = 1 to extraSpace do 		   -- add padding to reach 0x20 if needed
		(
			WriteByte pso2Model 0x0
		)
		afpDataSizeOff = (ftell pso2Model) 
		WriteLong pso2Model 0			   -- Filesize after write minus fileOffset
		WriteLong pso2Model 0x30           -- afp added offset?
		WriteLong pso2Model 0              -- Filesize minus 0x10; This is the offset of the leading 0x10 of 0s before a second AFP file. This is filled regardless, however.
		WriteString pso2Model ftype        -- Filetype
		fseek pso2Model (-2) #seek_cur
		WriteByte pso2Model 0x6F           -- Change aqp/trp to aqo/tro text. These two spots are technically the only spots where aqp/aqo and trp/tro are differentiated in the file.
	)
	
	--NIFL Header
	--should be populated later with a few values once the final is finished writing almost
	WriteString pso2Model "NIFL"
	fseek pso2Model (-1) #seek_cur
	WriteLong  pso2Model 0x18 -- offset to a u32 that is some length of something? Always seems to be 0x18
	WriteLong  pso2Model 1 -- Just 1
	WriteLong  pso2Model 0x20 -- REL0 offset
	nofMinus20Add = (ftell pso2Model)
	WriteLong  pso2Model 0 --NOF0 offset - fileOffset
	nofAdd = (ftell pso2Model)
	WriteLong  pso2Model 0 --NOF0 offset
	nofSizeAdd = (ftell pso2Model)
	WriteLong  pso2Model 0x20 --Size of NOF0 block - For aqn, always appears to be 0x20, but we have to go back and write it for models
	WriteLong  pso2Model 0 --Padding
	-----------------------------------------------------------------
	
	--REL0 Struct
	WriteString pso2Model "REL0"
	fseek pso2Model (-1) #seek_cur
	relSizeAdd = (ftell pso2Model)
	WriteLong pso2Model 0 --Size of REL0. Fill this in later
	WriteLong pso2Model 0x10 --Just 0x10
	WriteLong pso2Model 0 -- Just 0
	
	--OBJC Struct (This and upcoming struct names based on VTBF model equivalents)
	WriteLong pso2Model 0xC2A			--0xC2A
	WriteLong pso2Model 0xA4			--OBJC Size, always 0xA4
	WriteLong pso2Model 0x17			--Unknown value, related to second value of MESH?	
	maxVTXLOff = (ftell pso2Model); append relAddresses maxVTXLOff	--Size of largest VTXL Vertex struct
	WriteLong pso2Model 0				
	WriteLong pso2Model totalFaces		--Total Strip Face Indices count
	WriteLong pso2Model 0				--Reserve 0
	WriteLong pso2Model totalVertices	--Total VTXL/Vertex Count
	WriteLong pso2Model 0				--Reserve 0
	WriteLong pso2Model aqpMeshData.count --Unknown Count (The following counts share a value)
	WriteLong pso2Model aqpMeshData.count --VSET Count 
	WriteLong pso2Model 0xC0			  --VSET Offset - We can write this one immediately since it's the first struct set and so it's at a set place in all models
	WriteLong pso2Model aqpMeshData.count --PSET Count
	pSetOBJCOff = (ftell pso2Model); append relAddresses pSetOBJCOff 	--PSET Offset
	WriteLong pso2Model 0
	WriteLong pso2Model aqpMeshData.count --MESH Count; Count values stop being shared
	meshOBJCOff = (ftell pso2Model); append relAddresses meshOBJCOff 	--MESH Offset
	WriteLong pso2Model 0
	WriteLong pso2Model aqpMats.count   --MATE Count
	mateOBJCOff = (ftell pso2Model); append relAddresses mateOBJCOff 	--MATE Offset
	WriteLong pso2Model 0
	WriteLong pso2Model aqpMats.count 	--REND Count
	rendOBJCOff = (ftell pso2Model); append relAddresses rendOBJCOff 	--REND Offset
	WriteLong pso2Model 0
	WriteLong pso2Model aqpMatExtra.ShaderList.count 	--SHAD Count
	shadOBJCOff = (ftell pso2Model); append relAddresses shadOBJCOff 	--SHAD Offset
	WriteLong pso2Model 0
	WriteLong pso2Model aqpMatExtra.TextureCount	--TSTA Count - should be reliant on the shader technically, may fix at a later date.
	tstaOBJCOff = (ftell pso2Model); append relAddresses tstaOBJCOff 	--TSTA Offset
	WriteLong pso2Model 0
	WriteLong pso2Model aqpMats.count	--TSET Count
	tsetOBJCOff = (ftell pso2Model); append relAddresses tsetOBJCOff 	--TSET Offset
	WriteLong pso2Model 0
	WriteLong pso2Model aqpMatExtra.TextureCount	--TEXF Count - same count as tsta
	texfOBJCOff = (ftell pso2Model); append relAddresses texfOBJCOff 	--TEXF Offset
	WriteLong pso2Model 0
	--Field with Model Center xyz, 0, Bounding Radius, Model Center xyz again, 0, Max minus Min Point distance / 2 xyz, 0
	WriteFloat pso2Model aqpBounds.OrigX
	WriteFloat pso2Model aqpBounds.OrigY
	WriteFloat pso2Model aqpBounds.OrigZ
	WriteLong pso2Model 0
	WriteFloat pso2Model aqpBounds.Radius
	WriteFloat pso2Model aqpBounds.OrigX
	WriteFloat pso2Model aqpBounds.OrigY
	WriteFloat pso2Model aqpBounds.OrigZ
	WriteLong pso2Model 0
	WriteFloat pso2Model aqpBounds.DiffX
	WriteFloat pso2Model aqpBounds.DiffY
	WriteFloat pso2Model aqpBounds.DiffZ
	WriteFloat pso2Model 0
	uNRMOff = (ftell pso2Model); append relAddresses uNRMOff 	--UNRM Offset (If available, usually only for player models?)
	WriteLong pso2Model 0
	--Padding
	WriteLongLong pso2Model 0
	WriteLong pso2Model 0
	
	VSetOffsets = #()
	--VSET Struct Vertex Set(s)
	for obj in aqpMeshData do
	(
		offs = VSetOff()
	
		WriteLong pso2Model obj.MeshVertSize			--Total size per chunk of vertex data
		WriteLong pso2Model obj.MeshValidVTypes.count	--Number of VTXE Structs (vertex data structs) per vertex
		offs.VTXEOff = (ftell pso2Model); append relAddresses offs.VTXEOff 	--Offset of VTXE
		WriteLong pso2Model obj.MeshVerts.count		--Number of VTXL Structs/Vertices
		offs.VTXLOff = (ftell pso2Model); append relAddresses offs.VTXLOff 	--Offset of VTXL Structs
		WriteLong pso2Model 0
		WriteLong pso2Model 0	--Unknown 0
		if obj.MeshBonePalette.count > 1 then --Bone Palette 1 Bone Count    (May need to stay under 16?)
		( 
			WriteLong pso2Model obj.MeshBonePalette.count 
			append relAddresses (ftell pso2Model)
		) else 
		( 
			WriteLong pso2Model 0 
		)
		offs.BPalOff = (ftell pso2Model) 		--Bone Palette 1 Offset
		WriteLong pso2Model 0
		WriteLong pso2Model 0	--Unknown 1
		WriteLong pso2Model 0	--Unknown 2
		WriteLong pso2Model 0	--Unknown 3
		if UNRMExport == true then	--Autosplit edge vertex count - Basically, vertices in the splitting process on the edges that were split. Unused on non unrm models?
		(
			if obj.MeshEdgeVerts.count > 1 then
			(
				WriteLong pso2Model obj.MeshEdgeVerts.count
				append relAddresses (ftell pso2Model)
			) else
			(
				WriteLong pso2Model 0
			)
		) else
		(
			WriteLong pso2Model 0	
		)	  
		offs.EVertOff = (ftell pso2Model) --Autosplit edge vertex offset
		WriteLong pso2Model 0
		
		append VSetOffsets offs
	)
	
	--VTXE Structs are written before their respective VTXL structs 
	biggestVTXL = 0
	for obj in aqpMeshData do
	(
		vertRelAdd = 0 --Vertex relative address. We need to note down where each data struct for the vertex is relative to the start of the vertex
		--VTXE Struct - These define the types of data each vertex has 
		for type in obj.MeshValidVTypes do
		(
			curLength = 0
			WriteLong pso2Model type	--Data Type ID, by Sega's order (0x0 Vertex Position) (0x1 Vertex Weights) (0x2 Vertex Normal) (0x21 Binormals) (0x20 Tangents) (0x3 Vertex Color) (0x4 Vertex Color 2?) (0xb Weight Index) (0x10 UV1 Buffer) (0x11 UV2 Buffer) (0x12 UV3 Buffer)
			case type of --Data Format ID (0x2 - UV FloatVector2) (0x3 - Various FloatVector3) (0x5 - Color, B G R A bytes)
			(
				0x0: (WriteLong pso2Model 3; curLength = 0xC)  --(0x0 Vertex Position) 
				0x1: (WriteLong pso2Model 4; curLength = 0x10) --(0x1 Vertex Weights)
				0x2: (WriteLong pso2Model 3; curLength = 0xC)  --(0x2 Vertex Normal)
				0x3: (WriteLong pso2Model 5; curLength = 0x4)  --(0x3 Vertex Color)
				0x4: (WriteLong pso2Model 5; curLength = 0x4)  --(0x4 Vertex Color 2?)
				0xb: (WriteLong pso2Model 7; curLength = 0x4)  --(0xb Weight Index)
				0x10: (WriteLong pso2Model 2; curLength = 0x8) --(0x10 UV1 Buffer)
				0x11: (WriteLong pso2Model 2; curLength = 0x8) --(0x11 UV2 Buffer)
				0x12: (WriteLong pso2Model 2; curLength = 0x8) --(0x12 UV3 Buffer)
				0x20: (WriteLong pso2Model 3; curLength = 0x8) --(0x20 Tangents)
				0x21: (WriteLong pso2Model 3; curLength = 0x8) --(0x21 Binormals)
				default: print "Bad vert type!"
			)
			WriteLong pso2Model vertRelAdd --Position in Vertex Data (Vert  data has each VTXE type laid out in sequence for a given vertex before moving to the next. This is the relative to the beginning of a particular vertex's data.) 
			WriteLong pso2Model 0	--Reserve
			vertRelAdd += curLength
			if vertRelAdd > biggestVTXL then (biggestVTXL = vertRelAdd)
		)
		--VTXL Struct - These are the vertex data structs defined in the VTXE before this
		for vert in obj.MeshVerts do
		(
			for type in obj.MeshValidVTypes do
			(
				case type of
				(
					0x0: (WriteLong pso2Model vert.VertPos.x; WriteLong pso2Model vert.VertPos.y; WriteLong pso2Model vert.VertPos.z)  --(0x0 Vertex Position) 
					0x1: (WriteLong pso2Model vert.VertWeights[1]; WriteLong pso2Model VertWeights[2]; WriteLong pso2Model VertWeights[3]; WriteLong pso2Model VertWeights[4]) --(0x1 Vertex Weights)
					0x2: (WriteLong pso2Model vert.VertNormal.x; WriteLong pso2Model vert.VertNormal.y; WriteLong pso2Model vert.VertNormal.z)  --(0x2 Vertex Normal)
					0x3: (WriteLong pso2Model vert.VertColorArray[1].b; WriteLong pso2Model vert.VertColorArray[1].g; WriteLong pso2Model vert.VertColorArray[1].r; WriteLong pso2Model vert.VertColorArray[1].a)  --(0x3 Vertex Color)
					0x4: (WriteLong pso2Model vert.VertColor2Array[1].b; WriteLong pso2Model vert.VertColor2Array[1].g; WriteLong pso2Model vert.VertColor2Array[1].r; WriteLong pso2Model vert.VertColor2Array[1].a)  --(0x4 Vertex Color 2?)
					0xb: (WriteLong pso2Model vert.VertBones[1]; WriteLong pso2Model vert.VertBones[2]; WriteLong pso2Model vert.VertBones[3]; WriteLong pso2Model vert.VertBones[4])  --(0xb Weight Index)
					0x10: (WriteLong pso2Model vert.VertUV1Array[1].x; WriteLong pso2Model vert.VertUV1Array[1].y) --(0x10 UV1 Buffer)
					0x11: (WriteLong pso2Model vert.VertUV2Array[1].x; WriteLong pso2Model vert.VertUV2Array[1].y) --(0x11 UV2 Buffer)
					0x12: (WriteLong pso2Model vert.VertUV3Array[1].x; WriteLong pso2Model vert.VertUV3Array[1].y) --(0x12 UV3 Buffer)
					0x20: (WriteLong pso2Model vert.VertTangentArray[1].x; WriteLong pso2Model vert.VertTangentArray[1].y; WriteLong pso2Model vert.VertTangentArray[1].z) --(0x20 Tangents)
					0x21: (WriteLong pso2Model vert.VertBinormalArray[1].x; WriteLong pso2Model vert.VertBinormalArray[1].y; WriteLong pso2Model vert.VertBinormalArray[1].z) --(0x21 Binormals)
					default: print "Bad vert type!"
				)
			)
		)
		--Pad for alignment
		while ( (mod (ftell pso2Model) 0x10) != 0) do
		(
			WriteByte pso2Model 0 --Write padding
		)
	)
	--Set largest VTXL in OBJC
	temp = (ftell pso2Model)
	fseek pso2Model maxVTXLOff #seek_set          -- Go back and fill in 
	WriteLong pso2Model biggestVTXL
	fseek pso2Model temp #seek_set                 --Return to current address
	pSetOffs = #()
	
	
	
	--PSET Structs - Struct to provide information on triangle strip sets
	temp = (ftell pso2Model)
	fseek pso2Model pSetOBJCOff #seek_set          -- Go back and fill in address
	WriteLong pso2Model (temp - fileOffset)
	fseek pso2Model temp #seek_set                 --Return to current address
	pSetOffs = #()
	for i = 1 to aqpMeshes.count do
	(
		WriteLong pso2Model 0x2100                  --0x2100?
		WriteLong pso2Model 0x1                     --0x1? Face type?
		faceCountOff = (ftell pso2Model); append relAddresses faceCountOff
		WriteLong pso2Model 0                       --FaceCount Offset
		WriteLong pso2Model aqpStrips[i].count      --Pset face count
		faceOff = (ftell pso2Model); append relAddresses faceOff
		WriteLong pso2Model 0                       --Face Offset
		append pSetOffs (pSetOff CountOff:FaceCountOff FaceOff:faceOff)
	)
	
	--Pad as needed
	if (mod aqpMeshes.count 2) != 0 then
	(
		WriteLongLong pso2Model 0
	)
	
	--FACE Data - Triangle strip sets
	for i = 1 to aqpMeshes.count do
	(
		--Fill in addresses
		temp = (ftell pso2Model)
		fseek pso2Model pSetOffs[i].CountOff #seek_set
		WriteLong pso2Model (temp - fileOffset - 0x10)
		fseek pso2Model pSetOffs[i].FaceOff #seek_set
		WriteLong pso2Model (temp - fileOffset)
		fseek pso2Model temp #seek_set
		--Write Face data
		WriteLong pso2Model aqpStrips[i].count --Face count
		WriteLong pso2Model 0				   --Face count padding
		WriteLongLong pso2Model 0		       --Face count padding
		for strip in aqpStrips[i] do
		(
			WriteShort pso2Model strip
		)
		--Pad for alignment
		while ( (mod (ftell pso2Model) 0x10) != 0) do
		(
			WriteByte pso2Model 0 --Write padding
		)
	)
	
	--MESH Structs
	temp = (ftell pso2Model)
	fseek pso2Model meshOBJCOff #seek_set          -- Go back and fill in address
	WriteLong pso2Model (temp - fileOffset)
	fseek pso2Model temp #seek_set                 --Return to current address
	for obj = 1 to aqpMeshData.count do
	(
		WriteShort pso2Model 0			--Unk U16, 0 or 10
		WriteShort pso2Model 0x17		--Unk U16, 0x11 or 0x14 often
		WriteShort pso2Model 0			--Unk U16, always 0?
		WriteByte pso2Model 0x64		--Unk U8, usually 0x63 or 0x64
		WriteByte pso2MOdel 0x80		--Unk U8, usually 0x80
		WriteLong pso2Model (aqpMeshData[obj].MeshMatId-1) --Material Index for current mesh
		WriteLong pso2Model (aqpMeshData[obj].MeshMatId-1) --Render Index for current mesh
		WriteLong pso2Model aqpMatExtra.MatShaderIndex[obj]  --Shader Index for current mesh
		WriteLong pso2Model (aqpMeshData[obj].MeshMatId-1) --Texture Set Index for current mesh
		WriteLong pso2Model (getUserProp "NodeID" extraBoneList[obj.MeshId+1])  --Bone Index for autogenerated base mesh dummy; These are ordered before physics bones, but after normal bones. 
																				--Presumably just for debugging/organization normally, but also used for rigid weighting objects that didn't originally have bones
																				--Assumedly, meshes outside hierarchy are weighted to root while those with a hierarchy are placed as such while placing the node's mesh in the mesh data.
		WriteLong pso2Model obj --VSET?, Mesh Index
		WriteLong pso2Model obj --PSET?, Mesh Index
		WriteLong pso2Model obj.MeshId	--Autogenerated base mesh dummy id. 0 if there's only one, presumably, though if multiple exist, the dummies are numbered. Dummy order seems arbitrary (ie. first num may be 6, followed by 2 in hierarchy etc.)
		WriteLong pso2Model 0 --Unk, often 0
		WriteLong pso2Model 0 --0
	)
	
	--MATE Structs
	temp = (ftell pso2Model)
	fseek pso2Model mateOBJCOff #seek_set          -- Go back and fill in address
	WriteLong pso2Model (temp - fileOffset)
	fseek pso2Model temp #seek_set 
	for mat = 1 to aqpMats do
	(
		--Material Diffuse Color Vector4 - RGBA format. "Alpha" value seems unused ingame
		WriteFloat pso2Model (aqpMats[mat].diffuse.r / 255);WriteFloat pso2Model (aqpMats[mat].diffuse.g / 255);WriteFloat pso2Model (aqpMats[mat].diffuse.b / 255);WriteFloat pso2Model 1;
		--Material Unknown Color? Vector4 - Defaults are .9,.9.9,1
		WriteFloat pso2Model 0.9;WriteFloat pso2Model 0.9;WriteFloat pso2Model 0.9;WriteFloat pso2Model 1
		--Material Unknown values? Third value can activate self illumination for the object. Vector4
		WriteFloat pso2Model 0;WriteFloat pso2Model 0;WriteFloat pso2Model 0;WriteFloat pso2Model 1
		--Material Unknown Values. Some values can activate self illumination for the object like above. Vector4
		WriteFloat pso2Model 0;WriteFloat pso2Model 0;WriteFloat pso2Model 0;WriteFloat pso2Model 1
		WriteLong pso2Model 0	--0
		WriteFloat pso2Model 8	--Unk Float, often 8 or 32
		WriteFloat pso2Model 1	--Unk Float, usually 1
		WriteLong pso2Model 100	--Unk Int, usually 100
		WriteLong pso2Model 0	--Unknown, usually 0
		
		--0x20 Char AlphaType String, "opaque", "hollow", "blendalpha","add" - Opaque is an opaque render, blendalpha is a proper alpha blending, add uses the alpha to make a glow effect
		/*
		alphaName = substring aqpMatExtra.MatAlphaType[mat] 1 0x20
		extraSpace = 0x20 - (alphaName.count) --calculate space left to 20 (if any)
		WriteString pso2Model alphaName -- name
		fseek pso2Model (-1) #seek_cur
		for e = 1 to extraSpace do -- add padding to reach 0x20 if needed
		(
			WriteByte pso2Model 0x0
		)*/
		WriteFixedLengthString pso2Model aqpMatExtra.MatAlphaType[mat] 0x20
		
		--Handle name string	-0x20 Char String, Material Name - we have to filter the shader and alphatype out  
		matName = aqpMats[mat].name	
		filter1 = (filterstring matName ")")
		if (filter1.count > 1) then
		(
			matName = filter1[2]
		)
		filter2 = (filterstring matName "}")
		if (filter2.count > 1) then
		(
			matName = filter2[2]
		)
		/*
		matName = substring  matName 1 0x20 -- avoid going over
		extraSpace = 0x20 - (matName.count) --calculate space left to 20 (if any)
		WriteString pso2Model matName -- name
		fseek pso2Model (-1) #seek_cur
		for e = 1 to extraSpace do -- add padding to reach 0x20 if needed
		(
			WriteByte pso2Model 0x0
		)*/	

		WriteFixedLengthString pso2Model matName 0x20
	)
	--Only align in post
	--Pad for alignment
	while ( (mod (ftell pso2Model) 0x10) != 0) do
	(
		WriteByte pso2Model 0 --Write padding
	)

	--REND Structs - Will set up better if possible as things are figured out
	for mat = 1 to aqpMats do
	(
		WriteLong pso2Model 255		-- 0x1FF
		WriteLong pso2Model 3		-- 3 usually
		WriteLong pso2Model aqpMats[mat].twoSided	-- 1 Two-sided, 0 Backface Cull, 2 used in persona live dance models but unknown
		WriteLong pso2Model	1		-- 1 Alpha blend enabling setting
		WriteLong pso2Model 5		-- 5 usually
		WriteLong pso2Model 6		-- 6 usually
		WriteLong pso2Model 1		-- 1 usually
		WriteLong pso2Model 0		-- 0 usually
		WriteLong pso2Model 5		-- 5 usually
		WriteLong pso2Model 6		-- 6 usually
		WriteLong pso2Model 1		-- 1 Another alpha setting? Maybe for multi/_s map?
		WriteLong pso2Model 5		-- 5 usually
		WriteLong pso2Model 0		-- 0-256, opaque alpha setting? (assumedly value of alpha at which a pixel is rendered invisible vs fully visible)
		WriteLong pso2Model 1		-- 1 usually
		WriteLong pso2Model 4		-- 4 usually
		WriteLong pso2Model 1		-- 1 usually
	)

	--SHAD Structs
	for shd = 1 to aqpMatExtra do
	(
		WriteLong pso2Model 0	-- 0 always?
		WriteFixedLengthString pso2Model aqpMatExtra.ShaderList[shd][0] 0x20	-- 0x20 Shadername string with modifier
		WriteFixedLengthString pso2Model aqpMatExtra.ShaderList[shd][1] 0x20	-- 0x20 Shadername string
		WriteLong pso2Model 0	-- 0 always?
		WriteLong pso2Model 0	-- 0 always (NIFL Tool doesn't account for this for some reason in its display output, causing a misalignment)
	)
	--Only align in post
	--Pad for alignment
	while ( (mod (ftell pso2Model) 0x10) != 0) do
	(
		WriteByte pso2Model 0 --Write padding
	)	
	
	--TSTA Structs
	for texSet in aqpMatExtra.TextureSets do
	(
		for tex = 1 to texSet.count do
		(
			WriteLong pso2Model 0x16	-- 0x16
			WriteLong pso2Model tex		-- TSET Texture Usage Order, 0,1,2,3
			-- UV set number (0 based), for env maps use -1 (FFFFFFFF)
			texType = subString texSet[tex] texSet.count-5 2
			if texSet[tex] != "pl_body_decal.dds" then
			(
				WriteLong pso2Model 2
			) else
			(
				case texType of
				(
					"_k": 	 (WriteLong pso2Model 2)
					"_t":	 (WriteLong pso2Model -1)
					default: (WriteLong pso2Model 1)
				)
			)
			WriteFloat pso2Model 0	-- 0                         Unknown float?
			WriteFloat pso2Model -0	-- negative 0 float     Unknown float?
			WriteFloat pso2Model 0	-- 0                         Unknown float?
			WriteFloat pso2Model 0	-- 0
			WriteFloat pso2Model 0	-- 0
			WriteFloat pso2Model 0	-- 0
			WriteLong pso2Model 1	-- 1 or 3 sometimes
			WriteLong pso2Model 1	-- 1 or 3 sometimes
			WriteLong pso2Model 1	-- 1
			WriteLong pso2Model 0	-- 0 
			WriteLong pso2Model 0	-- 0
			WriteFixedLengthString pso2Model texSet[tex] 0x20	-- 0x20 string of texture name with extension
		)
	)
	
	--TSET Structs (Texture Set)
	for texSet=1 to aqpMatExtra.TextureSets.count do
	(
		WriteLong pso2Model 0	-- 0?
		texCount = aqpMatExtra.TextureSets[texSet].count
		WriteLong pso2Model texCount	-- Used texture count
		WriteLong pso2Model 0	-- 0
		WriteLong pso2Model 0	-- 0
		WriteLong pso2Model 0	-- 0
		--Write tex ids
		for i = 1 to texCount do
		(
			WriteLong pso2Model aqpMatExtra.TextureIdSets[i]
		)
		--Write unused tex ids as -1
		for i = 1 to (4-texCount) do
		(
			WriteLong pso2Model -1
		)
	)
		
	--TEXF Structs
	for texSet in aqpMatExtra.TextureSets do
	(
		for tex = 1 to texSet.count do
		(
			WriteFixedLengthString pso2Model texSet[tex] 0x20	-- 0x20 string of texture name with extension
		)
	)	
	
	--Not all models need UNRMs
	if UNRMExport == true then
	(
		temp = (ftell pso2Model)
		fseek pso2Model uNRMOff #seek_set          -- Go back and fill in address
		WriteLong pso2Model (temp - fileOffset)
		fseek pso2Model temp #seek_set                 --Return to current address
		pSetOffs = #()
		
		--UNRM Struct - Links vertices split for various reasons (vertex colors per face, UVs, etc.)
		WriteLong pso2Model unrmData.UNRMs.count	--Vertex set count
		UNRMVSetCountOff = (ftell pso2Model); append relAddresses (ftell pso2Model)		-- Get vertex set offset
		WriteLong pso2Model 0
		WriteLong pso2Model unrmData.UNRMVertCount	--Total verts in upcoming data
		UNRMmeshIDOff = (ftell pso2Model); append relAddresses (ftell pso2Model)		--Offset of mesh id data
		WriteLong pso2Model 0
		UNRMvertIDOff = (ftell pso2Model); append relAddresses (ftell pso2Model)		-- Vertex ID data offset
		WriteLong pso2Model 0
		--Padding
		WriteLongLong pso2Model 0
		WriteLong pso2Model 0
		
		temp = (ftell pso2Model)
		fseek pso2Model UNRMVSetCountOff #seek_set          -- Go back and fill in address
		WriteLong pso2Model (temp - fileOffset)
		fseek pso2Model temp #seek_set                 --Return to current address
		--Begin vert set counts
		for o in unrmData.UNRMs do
		(
			WriteLong pso2Model o.count
		)
		--Pad for alignment
		while ( (mod (ftell pso2Model) 0x10) != 0) do
		(
			WriteByte pso2Model 0 --Write padding
		)
		
		temp = (ftell pso2Model)
		fseek pso2Model UNRMmeshIDOff #seek_set          -- Go back and fill in address
		WriteLong pso2Model (temp - fileOffset)
		fseek pso2Model temp #seek_set                 --Return to current address
		--Begin vert mesh IDs
		for o in unrmData.UNRMs do
		(
			for p in o do
			(
				WriteLong pso2Model p.MeshNum
			)
		)
		--Pad for alignment
		while ( (mod (ftell pso2Model) 0x10) != 0) do
		(
			WriteByte pso2Model 0 --Write padding
		)

		temp = (ftell pso2Model)
		fseek pso2Model UNRMvertIDOff #seek_set          -- Go back and fill in address
		WriteLong pso2Model (temp - fileOffset)
		fseek pso2Model temp #seek_set                 --Return to current address
		--Begin vert IDs
		for o in unrmData.UNRMs do
		(
			for p in o do
			(
				WriteLong pso2Model p.VertID
			)
		)
		--Pad for alignment
		while ( (mod (ftell pso2Model) 0x10) != 0) do
		(
			WriteByte pso2Model 0 --Write padding
		)
		
	)
	
	--NOF0
	nofBegin = (ftell pso2Model) 
	WriteString pso2Model "NOF0"    
	fseek pso2Model (-1) #seek_cur 
	nofSizeOff = (ftell pso2Model) 				-- Get size offset
	WriteLong pso2Model 0
	WriteLong pso2Model relAddresses.count		-- Entry count
	WriteLong pso2Model 0						-- 0
	nofSizeStart = (ftell pso2Model)
	--Write Addresses
	for rel in relAddresses do
	(
		WriteLong pso2Model (rel - fileOffset)
	)
	--Pad for alignment
	while ( (mod (ftell pso2Model) 0x10) != 0) do
	(
		WriteByte pso2Model 0 --Write padding
	)
	nofSize = (ftell pso2Model) - nofSizeStart
	temp = (ftell pso2Model)
	fseek pso2Model UNRMvertIDOff #seek_set          -- Go back and fill in address
	WriteLong pso2Model nofSize
	fseek pso2Model temp #seek_set                 --Return to current address
	
	--NEND
	WriteString pso2Model "NEND"
	fseek pso2Model (-1) #seek_cur 
	WriteLong pso2Model 0x8         -- Size of NEND
	for i = 1 to 3 do               -- Padding
	(
		WriteLongLong pso2Model 0
	)
	
	--Fill remaining addresses
	--Nifl Null addresses
	fseek pso2Model nofMinus20Add #seek_set
	WriteLong pso2Model (nofBegin - fileOffset)
	WriteLong pso2Model (nofBegin - fileOffset + 0x20)
	WriteLong pso2Model (nofSize + 0x10)
	--REL addresses
	fseek pso2Anim relSizeAdd #seek_set
	WriteLong pso2Model (nofBegin - (relSizeAdd + 0x04) - 0x40)
	
	
	fflush aqpFile
	fclose aqpFile 
	
	--Cleanup
	for o in extraBoneList do
	(
		delete o
	)
)