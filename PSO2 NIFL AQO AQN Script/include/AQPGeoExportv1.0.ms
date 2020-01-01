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
	MatDiffuseColor,
	TextureSets,
	TextureIdSets,
	TextureCount,
	TwoSided
)

struct biTanArr
(
	vertsTangent,
	vertsBinormal
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
	--VertRendNormalArray,
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
	len -= 1
	str = substring str 1 len -- avoid going over
	extraSpace = len - (str.count) --calculate space left to len
	WriteString stream str -- name
	fseek pso2Model (-1) #seek_cur
	for e = 1 to (extraSpace) do -- add padding if needed
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
		origin.x *= (1 / ResizeValue)
		origin.y *= (1 / ResizeValue)
		origin.z *= (1 / ResizeValue)
		radius *= (1 / ResizeValue)
		difference.x *= (1 / ResizeValue)
		difference.y *= (1 / ResizeValue)
		difference.z *= (1 / ResizeValue)
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

--Adapted from this: https://forums.cgsociety.org/t/finding-bi-normals-tangents/975005/8 
--Binormals and tangents for each face are calculated and each face's values for a particular vertex are summed and averaged for the result before being normalized
--Though vertex position is used, due to the nature of the normalization applied during the process, resizing is unneeded.
fn computeTangentSpace objFaces pso2VertArr YZRot = 
(
	if pso2VertArr[1].VertUV1Array[1] != undefined then
	(
		local vertsBin = #()
		local vertsTan = #()
		local vertsNorm = #()
		--local vertsCounter = #()

		for f = 1 to objfaces.count do
		(
			face = objFaces[f]
			
			local v1 = pso2VertArr[face[1]].VertPos
			local v2 = pso2VertArr[face[2]].VertPos
			local v3 = pso2VertArr[face[3]].VertPos
			
			local uv1 = pso2VertArr[face[1]].VertUV1Array[1]
			local uv2 = pso2VertArr[face[2]].VertUV1Array[1]
			local uv3 = pso2VertArr[face[3]].VertUV1Array[1]
			
			local dV1 = v1 - v2
			local dV2 = v1 - v3

			local dUV1 = uv1 - uv2
			local dUV2 = uv1 - uv3
			
			local area = dUV1.x * dUV2.y - dUV1.y * dUV2.x
			local sign = if area < 0 then -1 else 1
			
			local tangent = [0,0,1]

			tangent.x = dV1.x * dUV2.y - dUV1.y * dV2.x
			tangent.y = dV1.y * dUV2.y - dUV1.y * dV2.y
			tangent.z = dV1.z * dUV2.y - dUV1.y * dV2.z

			tangent = (normalize tangent) * sign 
			
			--Face normal
			local u = v2 - v1
			local v = v3 - v1
			
			fNormal = cross u v
			
			local normal = normalize fnormal
			local binormal = (normalize (cross normal tangent)) * sign
			
			for i=1 to face.count do
			(
				if vertsBin[face[i]] == undefined then
				(
					vertsBin[face[i]] = binormal
					vertsTan[face[i]] = tangent
					vertsNorm[face[i]] = normal
					--vertsCounter[face[i]] = 1
				) else
				(
					vertsBin[face[i]] += binormal
					vertsTan[face[i]] += tangent
					vertsNorm[face[i]] += normal
					--vertsCounter[face[i]] += 1
				)
			)
		)
		
		for i = 1 to vertsNorm.count do
		(
			if YZRot == true then
			(
				temp = vertsNorm[i].y
				vertsNorm[i].y = vertsNorm[i].z
				vertsNorm[i].z = -temp
			)
			vertsNorm[i] = normalize vertsNorm[i]
		)	
		for i = 1 to vertsBin.count do
		(
			if YZRot == true then
			(
				temp = vertsBin[i].y
				vertsBin[i].y = vertsBin[i].z
				vertsBin[i].z = -temp
			)
			vertsBin[i] = normalize vertsBin[i]
		)
		for i = 1 to vertsTan.count do
		(
			if YZRot == true then
			(
				temp = vertsTan[i].y
				vertsTan[i].y = vertsTan[i].z
				vertsTan[i].z = -temp
			)
			vertsTan[i] = normalize vertsTan[i]
		)
		
		for v = 1 to vertsTan.count do
		(
			append pso2VertArr[v].VertBinormalArray vertsBin[v]
			append pso2VertArr[v].VertTangentArray vertsTan[v]
			--gc light:false delayed:false
		)
	)
	
	pso2VertArr
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
fn GetMatExtras aqpMats difWhite =
(
	texCount = 0
	matExtras = matSetExtras()
	
	matExtras.ShaderList = #()
	matExtras.MatShaderIndex = #()
	matExtras.MatAlphaType = #()
	matExtras.MatDiffuseColor = #()
	matExtras.MatPlayer = #()
	matExtras.TextureSets = #()
	matExtras.TextureIdSets = #()
	matExtras.TwoSided = #()
	
	for mat in aqpMats do
	(
		--Filterstring first ( ) for shadertype, second shadertype after "," inside shadertype ( ), filterstring { } for the alpha type. Append unique shaders and set the index for the respective materials. Append all alpha types
		shaderSet = undefined
		alphaType = #()
		strStart = findstring mat.name "("
		if strStart != undefined then
		(
			shaderSet = #()
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
		if shaderSet == undefined then
		(
			shaderSet = #()
			shaderSet[1] = "0301p"
			shaderSet[2] = "0301"
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
			if matExtras.ShaderList[shd][1] == shaderSet[1] and matExtras.ShaderList[shd][2] == shaderSet[2] then
			(
				shaderFound = shd
			)
		)
		if shaderFound == undefined then
		(
			append matExtras.ShaderList shaderSet
			shaderFound = matExtras.ShaderList.count
		)
		
		append matExtras.MatShaderIndex (shaderFound-1)
		append matExtras.MatAlphaType alphaType
		
		try(
			if mat.twoSided == true then
			(
				append matExtras.TwoSided 1
			) else
			(
				append matExtras.TwoSided 0
			)
		) catch (
			append matExtras.TwoSided 0
		)
		
		--Grab textures and assemble texture sets
		textureSet = #()
		textureIdSet = #()
		difColorsGrabbed = false
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
			if mat == undefined then
			(
				for i = 1 to 3 do
				(
					append textureIdSet texCount
					texCount +=1
				)
				append textureSet "generic_tex_d.dds"
				append textureSet "generic_tex_s.dds"
				append textureSet "generic_tex_n.dds"
			) else
			(
				if mat.diffuseMap != undefined then
				(
					dif = (getFilenameFile mat.diffuseMap.filename) + ".dds"
					if difWhite == false then
					(
						append matExtras.MatDiffuseColor mat.diffuse
						difColorsGrabbed = true
					)
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
					bump = (getFilenameFile mat.bumpMap.filename) + ".dds"
					append textureSet bump
					append textureIdSet texCount
					texCount += 1
				)
			)
		)
		append matExtras.TextureSets textureSet
		append matExtras.TextureIdSets textureIdSet
		
		--Default to white if not defined or if white mode is on
		if difColorsGrabbed == false or difWhite == true then
		(
			append matExtras.MatDiffuseColor (color 255 255 255 255)
		)
		
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
	
	--gc light:false delayed:false
	
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

	--Edge vert channel setup. Use channel 26 as a somewhat random channel that's well beyond what normal users will probably use
	if (meshop.getNumMaps obj) < 27 then (meshop.setNumMaps obj 27 keep:true) 
	meshop.setMapSupport obj 26 true
	meshop.setNumMapVerts obj 26 obj.verts.count
	meshop.setNumMapFaces obj 26 (meshop.getNumFaces obj) 
	
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
				for vert in faceVertsCheck do (meshop.setMapVert obj 26 vert [5,0,0])
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

fn pso2VertOptimizer meshes UNRMExport YZRot ResizeChecked ResizeValue =
(
	meshData = #()
	for obj in meshes do
	(
		local pso2VertArr = #()
		local fCount = (getNumFaces obj.mesh) 
		local objFaces = #()
		local objEdgeVerts = #()
		local objBonePalette = #()
		
		max modify mode
		objSkin = obj.skin
		modPanel.setCurrentObject objSkin
		
		--Loop through faces for each mesh. Append the vertices, their values for respective maps on respective faces, and said faces to an array of the original vertex indices.
		for f = 1 to fCount do
		(
			--Get verts of the face
			local faceVerts = (getFace obj.mesh f)
			--faceRNrms = (meshop.getFaceRNormals obj.mesh f)
			append objFaces faceVerts
			
			--Get map information for each vertex
			for v = 1 to faceVerts.count do
			(
				--Create temporary struct for comparison later
				local tempVert = pso2Vert()
				
				--Initialize tempVert arrays
				--tempVert.VertRendNormalArray = #()
				tempVert.VertBinormalArray = #()
				tempVert.VertTangentArray = #()
				tempVert.VertColorArray = #()
				tempVert.VertColor2Array = #()
				tempVert.VertUV1Array = #()
				tempVert.VertUV2Array = #()
				tempVert.VertUV3Array = #()
				tempVert.VertFaceArray = #()
				
				--Set the vert if it's not there
				if pso2VertArr[faceVerts[v]] == undefined then
				(
					tempPos = getVert obj.mesh faceVerts[v]
					tempVert.VertNormal = getNormal obj.Mesh faceVerts[v]
					--append tempVert.VertRendNormalArray faceRNrms[v]
					
					--Scale
					tempPos.x *= obj.transform.scale.x
					tempPos.y *= obj.transform.scale.y
					tempPos.z *= obj.transform.scale.z
					
					
					--Rot (rotate based on origin)
					tempRot = (quattoeuler obj.transform.rotation)
					if tempRot.X != 0 or tempRot.Y != 0 or tempRot.Z != 0 then
					(
						--Make point relative to origin for translation if not already there
						tempPos -= obj.transform.pos
						tempMatrix = (matrix3 [1,0,0] [0,1,0] [0,0,1] tempPos)
						rotate tempMatrix tempRot
						tempPos = tempMatrix.translationpart
						
						--Move point back relative to the object
						tempPos += obj.transform.pos
					)
					
					if YZRot == true then
					(
						tempZ = tempPos.z
						tempPos.z = -tempPos.y
						tempPos.y = tempZ
						
						tempNrm = tempVert.VertNormal.z
						tempVert.VertNormal.z = tempVert.VertNormal.y
						tempVert.VertNormal.y = -tempNrm
					)
					
					if ResizeChecked == true then
					(	
						--Actual resizing
						tempPos *= ( 1 / ResizeValue )
					)
					tempVert.VertPos = tempPos
					
					wc = skinOps.GetVertexWeightCount objSkin faceVerts[v]
					weights = #()
					_bones = #()
					
					for b = 1 to wc do
					(
						append weights (skinOps.GetVertexWeight objSkin faceVerts[v] b)
						boneId = (skinOps.GetVertexWeightBoneID objSkin faceVerts[v] b)
						boneId = (GetUserProp (getnodebyname (skinOps.GetBoneName objSkin boneId 1)) "NodeID")
						append _bones boneId
						appendIfUnique objBonePalette boneId
					)
					for i = 1 to (4 - wc) do
					(
						append weights 0
						append _bones 0
					)
					
					tempVert.VertBones = _bones
					tempVert.VertWeights = weights
					
					append tempVert.VertFaceArray #(f)
					pso2VertArr[faceVerts[v]] = tempVert
					--free weights
					--free _bones
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
						vcolor.alpha = 255;
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
						vcolor.alpha = 255
					)
					append tempVert.VertColor2Array vcolor
				) else
				(
					append tempVert.VertColor2Array undefined
				)
				
				--Get first set of UVs 
				if (meshop.getMapSupport obj.mesh 1) == true then
				(
					append tempVert.VertUV1Array (meshop.getMapVert obj.mesh 1 ((meshop.getMapFace obj.mesh 1 f)[v]))
				) else
				(
					append tempVert.VertUV1Array undefined
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
				
				--Check for edge verts in channel 26
				if (meshop.getMapSupport obj.mesh 26) == true then
				(
					--Check if this is an edge vert we set during the splitting process
					EdgeVert = (meshop.getMapVert obj.mesh 26 ((meshop.getMapFace obj.mesh 26 f)[v])).x
					if EdgeVert > 0.1 then (appendIfUnique objEdgeVerts faceVerts[v])
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
						append pso2VertArr[faceVerts[v]].VertColorArray tempVert.VertColorArray 
						append pso2VertArr[faceVerts[v]].VertColor2Array tempVert.VertColor2Array 
						append pso2VertArr[faceVerts[v]].VertUV1Array tempVert.VertUV1Array 
						append pso2VertArr[faceVerts[v]].VertUV2Array tempVert.VertUV2Array 
						append pso2VertArr[faceVerts[v]].VertUV3Array tempVert.VertUV3Array
						append pso2VertArr[faceVerts[v]].VertFaceArray #(f)
						--append pso2VertArr[faceVerts[v]].VertRendNormalArray faceRNrms[v]
					)

				)
				
				--free tempVert
				--gc light:false delayed:false
			)

		)
		
		--Retrieve and adjust face data, creating new vertices when necessary. When creating vertices, note down all new ids with the old ids in an array for unrms
		for f = 1 to fCount do
		(
			faceVerts = #()
			faceVerts[1] = objFaces[f][1]; faceVerts[2] = objFaces[f][2]; faceVerts[3] = objFaces[f][3]
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
						--tempVert.VertRendNormalArray = pso2VertArr[v].VertRendNormalArray
						append tempVert.VertColorArray  	pso2VertArr[v].VertColorArray[vertData]
						append tempVert.VertColor2Array  	pso2VertArr[v].VertColor2Array[vertData]
						append tempVert.VertUV1Array  		pso2VertArr[v].VertUV1Array[vertData]
						append tempVert.VertUV2Array  		pso2VertArr[v].VertUV2Array[vertData]
						append tempVert.VertUV3Array  		pso2VertArr[v].VertUV3Array[vertData]
						append tempVert.VertFaceArray 		f
						
						pso2VertArr[pso2VertArr.count+1] = tempVert
						--append pso2VertArr[v].VertUNRMs pso2VertArr.count
						objFaces[f][v] = pso2VertArr.count
						--free tempVert
					)
				)
			)
		)
		
		pso2VertArr = computeTangentSpace objFaces pso2VertArr YZRot
		
		--Get Valid Vert Types and Size
		validVertTypes = #()
		vertTypeSize = 0 
		append validVertTypes 0x0 --Position
		vertTypeSize += 0xC
		if objBonePalette.count >= 1 then
		(
			append validVertTypes 0x1 --Bone Weights
			vertTypeSize += 0x10
		)
		append validVertTypes 0x2 --Normal
		vertTypeSize += 0xC
		if pso2VertArr[1].VertUV1Array[1] != undefined then
		(
		--if UNRMExport == true then
		--(
			append validVertTypes 0x21 --Binormals
			vertTypeSize += 0xC
			append validVertTypes 0x20 --Tangents
			vertTypeSize += 0xC
		--)
		)
		if pso2VertArr[1].VertColorArray[1] != undefined then
		(
			append validVertTypes 0x3 --Vert Color
			vertTypeSize += 0x4
		)
		if pso2VertArr[1].VertColor2Array[1] != undefined then
		(
			append validVertTypes 0x4 --Vert Color 2?
			vertTypeSize += 0x4
		)
		if objBonePalette.count >= 1 then
		(
			append validVertTypes 0xb --Bone Indices
			vertTypeSize += 0x4
		)
		if pso2VertArr[1].VertUV1Array[1] != undefined then
		(
			append validVertTypes 0x10 --Vert UV1
			vertTypeSize += 0x8
		)
		if pso2VertArr[1].VertUV2Array[1] != undefined then
		(
			append validVertTypes 0x11 --Vert UV2
			vertTypeSize += 0x8
		)
		if pso2VertArr[1].VertUV3Array[1] != undefined then
		(
			append validVertTypes 0x12 --Vert UV3
			vertTypeSize += 0x8
		)
		
		tempMat = obj.material
		matId = GetFaceMatId obj.mesh 1
		--get true material if needed - A face's mat id in max will be used for its multimaterial and each successive level of multimaterial
		while ((classof tempMat) == Multimaterial) do
		(
			if tempMat.count >= matId then
			(
				tempMat = tempMat[matId]
			) else
			(
				tempMat = tempMat[tempMat.count]
			)
		)

		--PSO2 weight ids are relative to the bone palette, so we fix them here. Process Render normals as well while we're at this
		for vert = 1 to pso2VertArr.count do
		(
			/*
			if pso2VertArr[vert].VertRendNormalArray.count > 0 then
			(
				
				nrmSum = [0,0,0]
				for nrm in pso2VertArr[vert].VertRendNormalArray do
				(
					nrmSum += nrm
				)
				if YZRot == true then
				(
					temp = nrmSum.y
					nrmSum.y = nrmSum.z
					nrmSum.z = -temp
				)
				pso2VertArr[vert].VertNormal = normalize nrmSum 
			)*/
			for bon = 1 to pso2VertArr[vert].VertBones.count do
			(
				if pso2VertArr[vert].VertBones[bon] != 0 then
				(
					pso2VertArr[vert].VertBones[bon] = (finditem objBonePalette pso2VertArr[vert].VertBones[bon]) - 1
				)
			)
		)
		
		--append vertex, material, original mesh id, and face data to an array when done
		tempMesh 				 = pso2Mesh()
		tempMesh.MeshMat 		 = tempMat
		tempMesh.MeshFaces  	 = objFaces
		tempMesh.MeshVerts 		 = pso2VertArr
		tempMesh.MeshEdgeVerts   = objEdgeVerts
		tempMesh.MeshBonePalette = objBonePalette
		tempMesh.MeshValidVTypes = validVertTypes
		tempMesh.MeshVertSize    = vertTypeSize
		tempMesh.MeshId 		 = (getUserProp obj "meshId")
		append meshData tempMesh
		--free tempMesh
	)
	
	--return array with face, material, and vertex data for final write, delete export processed meshes
	meshData
)

--Check vert positions, normals, and first UV coord sets in order to find UNRM candidates 
fn calcUNRMs meshData unrmAvg =
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
	
	normals = undefined
	for m = 1 to meshData.count do
	(
		for v = 1 to meshData[m].MeshVerts.count do
		(
			unrm = #()
			append unrm (uNRMStruct MeshNum:m VertId:v)
			if (unrmAvg == true) then
			(
				normals = meshData[m].MeshVerts[v].VertNormal
			)
			for n = 1 to meshData.count do
			(
				for w=1 to meshData[n].MeshVerts.count do
				(
					sameVert = (m == n and v == w)
					if (meshData[m].MeshVerts[v].VertPos == meshData[n].MeshVerts[w].VertPos and sameVert == false and meshCheckArr[n][w] == false) then
					--if (meshData[m].MeshVerts[v].VertPos == meshData[n].MeshVerts[w].VertPos and meshData[m].MeshVerts[v].VertNormal == meshData[n].MeshVerts[w].VertNormal and meshData[m].MeshVerts[v].VertUV1Array[1] == meshData[n].MeshVerts[w].VertUV1Array[1] and meshCheckArr[n][w] == false and (m != n and v != w)) then
					(
						meshCheckArr[n][w] = true
						append unrm (uNRMStruct MeshNum:(n) VertId:(w))
						if (unrmAvg == true) then
						(
							normals += meshData[n].MeshVerts[w].VertNormal
						)
					)
				)
			)
			meshCheckArr[m][v] = true
			if unrm.count > 1 then
			(
				unrmVertCount += unrm.count
				append unrms unrm
				if (unrmAvg == true) then
				(
					normals = normalize normals
					for vert in unrm do
					(
						meshData[vert.MeshNum].MeshVerts[vert.VertId].VertNormal = normals
					)
				)							
			)
		)
	)
	
	UNRMContainer = (uNRMHolder UNRMs:unrms UNRMVertCount:unrmVertCount)
)

fn GeoExport aqpFile ResizeChecked ResizeValue YZRot UNRMExport difWhite unrmAvg =
(	
	undo off
	(
		fName = (filenameFromPath aqpFile)
		realFType = (substring (getFilenameType aqpFile) 2 3)
		fName[fName.count] = "o" 
		fType = (substring (getFilenameType fName) 2 3)
		
		startPath = getFilenamePath(getThisScriptFilename())
		dotnet.loadAssembly (startPath + "\\NvTriStripDotNet.dll")
		
		--Gather meshes and create dummies for them for export
		baseMeshes = for g in geometry where g.parent == undefined and g.children.count == 0 collect g
		boneList = GetPSO2BoneArray false
		extraBoneList = #()
		for i=1 to baseMeshes.count do 
		(
			setUserProp baseMeshes[i] "meshId" (i-1)
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
		
		--Export Bones
		currentPath = getFilenamePath aqpFile
		boneFileName = filterString (filenameFromPath aqpFile) "."
		boneFileName = (currentPath + boneFileName[1] + ".aqn")
		SkelExport boneFileName ResizeChecked ResizeValue YZRot
		
		--Split meshes by material - note: ReplaceVertexWeights automatically reevaluates weight(s) that do not total 1 by increasing the ratios of each existing weight proportionally to sum to 1. 
		aqpMeshes = splitMeshByMaterial baseMeshes
		print "MatSplit Done!"
		gc light:false delayed:false
		
		--Possible 16 bone limit per mesh? If so, split per that as well. Generate dummy nodes for each final mesh with one name and a number. Dummy nodes should be placed before physics nodes (though this may not be required)
		aqpMeshes = splitMeshByBoneCount aqpMeshes 16
		print "BoneSplit Done!"
		gc light:false delayed:false
		
		--Get rid of bad faces, just in case
		for aqpMesh in aqpMeshes do
		(
			meshop.removeDegenerateFaces aqpMesh
		)
		print "Degen Faces Eradicated!"
		
		--Check for used vertex types: (0x0 Vertex Position) (0x1 Vertex Weights) (0x2 Vertex Normal) (0x21 Binormals) (0x20 Tangents) (0x3 Vertex Color) (0x4 Vertex Color 2?) (0xb Weight Index) (0x10 UV1 Buffer) (0x11 UV2 Buffer) (0x12 UV3 Buffer)
			--Duplicate and separate vertices based on if multiple UV channels/VC channels exist for it. 
		aqpMeshData = pso2VertOptimizer aqpMeshes UNRMExport YZRot ResizeChecked ResizeValue
		print "Verts Optimized!"
		
		unrmData = undefined
		if UNRMExport == true then
		(
			unrmData = (calcUNRMs aqpMeshData unrmAvg)
		)
		
		--Get all unique mats and assign the array index of each to the respective objects
		aqpMats = GetUniqueMats aqpMeshData
		print "Mats collected!"
		--Get all unique shaders from material, textures, texture sets, and alpha setting
		aqpMatExtra = GetMatExtras aqpMats difWhite
		print "Extras Collected!"
		--Calculate geometry bounds OBJC. As duplicated vertices and changed faces won't change this, we feed it the export prepped mesh array
		aqpBounds = originMinMax aqpMeshes ResizeChecked ResizeValue YZRot
		print "Bounds Generated!"
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
		print "Strips Created!"
	)
	
	pso2Model = fopen aqpFile "wb"
	
	relAddresses = #()
	fileOffset = 0x20
	
	--AFP Header
	if (realFType != "aqo" and realFType != "tro") then
	(
		fileOffset += 0x40                 --add extra offset to our main offset
		WriteString pso2Model "afp"        -- Type
		fseek pso2Model (-1) #seek_cur
		WriteByte pso2Model 0 
		WriteLong pso2Model 1              -- AFP container filecount. Seems to be used for level of detail models in observed cases; game simply won't try using LOD models if not provided. May be used in level geometry variants?
		WriteLong pso2Model 0              -- Reserve
		WriteLong pso2Model 1              -- Always 1
		WriteFixedLengthString pso2Model fName 0x20        -- Model filename
		afpDataSizeOff = (ftell pso2Model) 
		WriteLong pso2Model 0			   -- Filesize after write minus 0x50
		WriteLong pso2Model 0x30           -- afp added offset?
		afpNextFileOff = (ftell pso2Model)
		WriteLong pso2Model 0              -- Filesize minus 0x10; This is the offset of the leading 0x10 of 0s before a second AFP file. This is filled regardless, however.
		WriteString pso2Model fType        -- Filetype
		fseek pso2Model (-1) #seek_cur
		WriteByte pso2Model 0x0			   -- 0
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
	maxVTXLOff = (ftell pso2Model)	--Size of largest VTXL Vertex struct
	WriteLong pso2Model 0				
	WriteLong pso2Model totalFaces		--Total Strip Face Indices count
	WriteLong pso2Model 0				--Reserve 0
	WriteLong pso2Model totalVertices	--Total VTXL/Vertex Count
	WriteLong pso2Model 0				--Reserve 0
	WriteLong pso2Model aqpMeshData.count --Unknown Count (The following counts share a value)
	WriteLong pso2Model aqpMeshData.count --VSET Count 
	vSetOBJCOff = (ftell pso2Model); append relAddresses vSetOBJCOff
	WriteLong pso2Model 0xC0 			  --VSET Offset - We can write this one immediately since it's the first struct set. Therefore, it's at a set place in all models
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
	if UNRMExport == true then
	(
		uNRMOff = (ftell pso2Model); append relAddresses uNRMOff 	--UNRM Offset (If available, usually only for player models?)
	)
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
		WriteLong pso2Model 0
		WriteLong pso2Model obj.MeshVerts.count		--Number of VTXL Structs/Vertices
		offs.VTXLOff = (ftell pso2Model); append relAddresses offs.VTXLOff 	--Offset of VTXL Structs
		WriteLong pso2Model 0
		WriteLong pso2Model 0	--Unknown 0
		if obj.MeshBonePalette.count > 0 then --Bone Palette 1 Bone Count    (May need to stay under 16?)
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
		if obj.MeshEdgeVerts.count > 0 then
		(
			print "edgeset 1"
			WriteLong pso2Model obj.MeshEdgeVerts.count
			append relAddresses (ftell pso2Model)
		) else
		(
			WriteLong pso2Model 0
		)  
		offs.EVertOff = (ftell pso2Model) --Autosplit edge vertex offset
		WriteLong pso2Model 0
		
		append VSetOffsets offs
	)
	
	--VTXE Structs are written before their respective VTXL structs 
	offsSet = 1
	biggestVTXL = 0
	for obj in aqpMeshData do
	(
		temp = (ftell pso2Model)
		fseek pso2Model VSetOffsets[offsSet].VTXEOff #seek_set          -- Go back and fill in 
		WriteLong pso2Model (temp - fileOffset)
		fseek pso2Model temp #seek_set                 --Return to current address
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
				0x20: (WriteLong pso2Model 3; curLength = 0xC) --(0x20 Tangents)
				0x21: (WriteLong pso2Model 3; curLength = 0xC) --(0x21 Binormals)
				default: print "Bad vert type!"
			)
			WriteLong pso2Model vertRelAdd --Position in Vertex Data (Vert  data has each VTXE type laid out in sequence for a given vertex before moving to the next. This is the relative to the beginning of a particular vertex's data.) 
			WriteLong pso2Model 0	--Reserve
			vertRelAdd += curLength
			if vertRelAdd > biggestVTXL then (biggestVTXL = vertRelAdd)
		)
		--VTXL Struct - These are the vertex data structs defined in the VTXE before this
		temp = (ftell pso2Model)
		fseek pso2Model VSetOffsets[offsSet].VTXLOff #seek_set          -- Go back and fill in 
		WriteLong pso2Model (temp - fileOffset)
		fseek pso2Model temp #seek_set                 --Return to current address
		for vert in obj.MeshVerts do
		(
			for type in obj.MeshValidVTypes do
			(
				case type of
				(
					0x0: (WriteFloat pso2Model vert.VertPos.x; WriteFloat pso2Model vert.VertPos.y; WriteFloat pso2Model vert.VertPos.z)  --(0x0 Vertex Position) 
					0x1: (WriteFloat pso2Model vert.VertWeights[1]; WriteFloat pso2Model vert.VertWeights[2]; WriteFloat pso2Model vert.VertWeights[3]; WriteFloat pso2Model vert.VertWeights[4]) --(0x1 Vertex Weights)
					0x2: (WriteFloat pso2Model vert.VertNormal.x; WriteFloat pso2Model vert.VertNormal.y; WriteFloat pso2Model vert.VertNormal.z)  --(0x2 Vertex Normal)
					0x3: (WriteByte pso2Model vert.VertColorArray[1].b; WriteByte pso2Model vert.VertColorArray[1].g; WriteByte pso2Model vert.VertColorArray[1].r; WriteByte pso2Model (vert.VertColorArray[1].a * 255))  --(0x3 Vertex Color)
					0x4: (WriteByte pso2Model vert.VertColor2Array[1].b; WriteByte pso2Model vert.VertColor2Array[1].g; WriteByte pso2Model vert.VertColor2Array[1].r; WriteByte pso2Model (vert.VertColor2Array[1].a * 255))  --(0x4 Vertex Color 2?)
					0xb: (WriteByte pso2Model vert.VertBones[1]; WriteByte pso2Model vert.VertBones[2]; WriteByte pso2Model vert.VertBones[3]; WriteByte pso2Model vert.VertBones[4])  --(0xb Weight Index)
					0x10: (WriteFloat pso2Model vert.VertUV1Array[1].x; WriteFloat pso2Model (-vert.VertUV1Array[1].y)) --(0x10 UV1 Buffer)
					0x11: (WriteFloat pso2Model vert.VertUV2Array[1].x; WriteFloat pso2Model (-vert.VertUV2Array[1].y)) --(0x11 UV2 Buffer)
					0x12: (WriteFloat pso2Model vert.VertUV3Array[1].x; WriteFloat pso2Model (-vert.VertUV3Array[1].y)) --(0x12 UV3 Buffer)
					0x20: (WriteFloat pso2Model vert.VertTangentArray[1].x; WriteFloat pso2Model vert.VertTangentArray[1].y; WriteFloat pso2Model vert.VertTangentArray[1].z) --(0x20 Tangents)
					0x21: (WriteFloat pso2Model vert.VertBinormalArray[1].x; WriteFloat pso2Model vert.VertBinormalArray[1].y; WriteFloat pso2Model vert.VertBinormalArray[1].z) --(0x21 Binormals)
					default: print "Bad vert type!"
				)
			)
		)
		--Pad for alignment
		while ( (mod (ftell pso2Model) 0x10) != 0) do
		(
			WriteByte pso2Model 0 --Write padding
		)
		
		if obj.MeshBonePalette.count > 0 then
		(
			temp = (ftell pso2Model)
			fseek pso2Model VSetOffsets[offsSet].BPalOff #seek_set          -- Go back and fill in 
			WriteLong pso2Model (temp - fileOffset)
			fseek pso2Model temp #seek_set                 --Return to current address
			--Write bones
			for bon in obj.MeshBonePalette do
			(
				WriteShort pso2Model bon
			)
			--Pad for alignment
			while ( (mod (ftell pso2Model) 0x10) != 0) do
			(
				WriteByte pso2Model 0 --Write padding
			)
		)
		if obj.MeshEdgeVerts.count > 0 then
		(
			print "edgeset 2"
			temp = (ftell pso2Model)
			fseek pso2Model VSetOffsets[offsSet].EVertOff #seek_set          -- Go back and fill in 
			WriteLong pso2Model (temp - fileOffset)
			fseek pso2Model temp #seek_set                 --Return to current address
			--Write edge verts
			for vertEdge in obj.MeshEdgeVerts do
			(
				WriteShort pso2Model vertEdge
			)
			--Pad for alignment
			while ( (mod (ftell pso2Model) 0x10) != 0) do
			(
				WriteByte pso2Model 0 --Write padding
			)
		)
		offsSet += 1
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
		WriteLong pso2Model 0
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
		WriteLong pso2Model (temp - fileOffset)
		fseek pso2Model pSetOffs[i].FaceOff #seek_set
		WriteLong pso2Model (temp - fileOffset + 0x10)
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
		WriteShort pso2Model 0x17		--Unk U16, 0x11 or 0x14 often
		WriteShort pso2Model 0			--Unk U16, 0 or 10
		WriteByte pso2Model 0x80		--Unk U8, usually 0x80
		WriteByte pso2Model 0x64		--Unk U8, usually 0x63 or 0x64
		WriteShort pso2Model 0			--Unk U16, always 0?
		WriteLong pso2Model (aqpMeshData[obj].MeshMatId - 1) --Material Index for current mesh
		WriteLong pso2Model (aqpMeshData[obj].MeshMatId - 1) --Render Index for current mesh
		WriteLong pso2Model aqpMatExtra.MatShaderIndex[aqpMeshData[obj].MeshMatId]  --Shader Index for current mesh
		WriteLong pso2Model (aqpMeshData[obj].MeshMatId - 1) --Texture Set Index for current mesh
		WriteLong pso2Model ((getUserProp extraBoneList[aqpMeshData[obj].MeshId+1] "NodeID") + 1)  --Bone Index for autogenerated base mesh dummy; These are ordered before physics bones, but after normal bones. 
																				--Presumably just for debugging/organization normally, but also used for rigid weighting objects that didn't originally have bones
																				--Assumedly, meshes outside hierarchy are weighted to root while those with a hierarchy are placed as such while placing the node's mesh in the mesh data.
		WriteLong pso2Model (obj - 1) --VSET?, Mesh Index
		WriteLong pso2Model (obj - 1) --PSET?, Mesh Index
		WriteLong pso2Model aqpMeshData[obj].MeshId	--Autogenerated base mesh dummy id. 0 if there's only one, presumably, though if multiple exist, the dummies are numbered. Dummy order seems arbitrary (ie. first num may be 6, followed by 2 in hierarchy etc.)
		WriteLong pso2Model 0 --Unk, often 0
		WriteLong pso2Model 0 --0
	)
	
	--MATE Structs
	temp = (ftell pso2Model)
	fseek pso2Model mateOBJCOff #seek_set          -- Go back and fill in address
	WriteLong pso2Model (temp - fileOffset)
	fseek pso2Model temp #seek_set 
	for mat = 1 to aqpMats.count do
	(
		--Material Diffuse Color Vector4 - RGBA format. "Alpha" value seems unused ingame
		WriteFloat pso2Model (aqpMatExtra.MatDiffuseColor[mat].r / 255);WriteFloat pso2Model (aqpMatExtra.MatDiffuseColor[mat].g / 255);WriteFloat pso2Model (aqpMatExtra.MatDiffuseColor[mat].b / 255);WriteFloat pso2Model 1;
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

		WriteFixedLengthString pso2Model matName 0x20
	)
	--Only align in post
	--Pad for alignment
	while ( (mod (ftell pso2Model) 0x10) != 0) do
	(
		WriteByte pso2Model 0 --Write padding
	)

	temp = (ftell pso2Model)
	fseek pso2Model rendOBJCOff #seek_set          -- Go back and fill in address
	WriteLong pso2Model (temp - fileOffset)
	fseek pso2Model temp #seek_set 
	--REND Structs - Will set up better if possible as things are figured out
	for mat = 1 to aqpMats.count do
	(
		WriteLong pso2Model 0x1FF	-- 0x1FF
		WriteLong pso2Model 3		-- 3 usually
		WriteLong pso2Model aqpMatExtra.TwoSided[mat]	-- 1 Two-sided, 0 Backface Cull, 2 used in persona live dance models but unknown
		WriteLong pso2Model	1		-- 1 Alpha blend enabling setting
		WriteLong pso2Model 5		-- 5 usually
		WriteLong pso2Model 6		-- 6 usually
		WriteLong pso2Model 1		-- 1 usually
		WriteLong pso2Model 0		-- 0 usually
		WriteLong pso2Model 5		-- 5 usually
		WriteLong pso2Model 6		-- 6 usually
		WriteLong pso2Model 1		-- 1 Another alpha setting? Maybe for multi/_s map?
		WriteLong pso2Model 1       -- 1 usually
		WriteLong pso2Model 5		-- 5 usually
		WriteLong pso2Model 0		-- 0-256, opaque alpha setting? (assumedly value of alpha at which a pixel is rendered invisible vs fully visible)
		WriteLong pso2Model 1		-- 1 usually
		WriteLong pso2Model 4		-- 4 usually
		WriteLong pso2Model 1		-- 1 usually
	)
	--Pad for alignment
	while ( (mod (ftell pso2Model) 0x10) != 0) do
	(
		WriteByte pso2Model 0 --Write padding
	)	
	
	temp = (ftell pso2Model)
	fseek pso2Model shadOBJCOff #seek_set          -- Go back and fill in address
	WriteLong pso2Model (temp - fileOffset)
	fseek pso2Model temp #seek_set 
	--SHAD Structs
	for shd = 1 to aqpMatExtra.ShaderList.count do
	(
		WriteLong pso2Model 0	-- 0 always?
		WriteFixedLengthString pso2Model aqpMatExtra.ShaderList[shd][1] 0x20	-- 0x20 Shadername string with modifier
		WriteFixedLengthString pso2Model aqpMatExtra.ShaderList[shd][2] 0x20	-- 0x20 Shadername string
		WriteLong pso2Model 0	-- 0 always?
		WriteLong pso2Model 0	-- 0 always (NIFL Tool doesn't account for this for some reason in its display output, causing a misalignment)
	)
	--Only align in post
	--Pad for alignment
	while ( (mod (ftell pso2Model) 0x10) != 0) do
	(
		WriteByte pso2Model 0 --Write padding
	)	
	
	temp = (ftell pso2Model)
	fseek pso2Model tstaOBJCOff #seek_set          -- Go back and fill in address
	WriteLong pso2Model (temp - fileOffset)
	fseek pso2Model temp #seek_set 
	--TSTA Structs
	for texSet in aqpMatExtra.TextureSets do
	(
		for tex = 1 to texSet.count do
		(
			WriteLong pso2Model 0x16	-- 0x16
			WriteLong pso2Model tex		-- TSET Texture Usage Order, 0,1,2,3
			-- UV set number (0 based), for env maps use -1 (FFFFFFFF)
			if texSet[tex].count >= 7 then
			(
				texType = subString texSet[tex] (texSet[tex].count-5) 2
			) else
			(
				texType = "_d"
			)
			if texSet[tex] == "pl_body_decal.dds" then
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
	--Pad for alignment
	while ( (mod (ftell pso2Model) 0x10) != 0) do
	(
		WriteByte pso2Model 0 --Write padding
	)
	
	
	temp = (ftell pso2Model)
	fseek pso2Model tsetOBJCOff #seek_set          -- Go back and fill in address
	WriteLong pso2Model (temp - fileOffset)
	fseek pso2Model temp #seek_set 
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
			WriteLong pso2Model aqpMatExtra.TextureIdSets[texSet][i]
		)
		--Write unused tex ids as -1
		for i = 1 to (4-texCount) do
		(
			WriteLong pso2Model -1
		)
	)
	--Pad for alignment
	while ( (mod (ftell pso2Model) 0x10) != 0) do
	(
		WriteByte pso2Model 0 --Write padding
	)
	
	temp = (ftell pso2Model)
	fseek pso2Model texfOBJCOff #seek_set          -- Go back and fill in address
	WriteLong pso2Model (temp - fileOffset)
	fseek pso2Model temp #seek_set 		
	--TEXF Structs
	for texSet in aqpMatExtra.TextureSets do
	(
		for tex = 1 to texSet.count do
		(
			WriteFixedLengthString pso2Model texSet[tex] 0x20	-- 0x20 string of texture name with extension
		)
	)	
	--Pad for alignment
	while ( (mod (ftell pso2Model) 0x10) != 0) do
	(
		WriteByte pso2Model 0 --Write padding
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
				WriteLong pso2Model (p.MeshNum - 1)
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
				WriteLong pso2Model (p.VertID - 1)
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
	nofDataSizeOff = (ftell pso2Model) 				-- Get size offset
	WriteLong pso2Model 0
	WriteLong pso2Model relAddresses.count		-- Entry count
	nofDataSizeStart = (ftell pso2Model)
	WriteLong pso2Model 0						-- 0
	
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
	nofSize = (ftell pso2Model) - nofBegin
	nofDataSize = (ftell pso2Model) - nofDataSizeStart
	
	temp = (ftell pso2Model)
	fseek pso2Model nofDataSizeOff #seek_set          -- Go back and fill in address
	WriteLong pso2Model nofDataSize
	fseek pso2Model temp #seek_set                 --Return to current address
	
	--NEND
	WriteString pso2Model "NEND"
	fseek pso2Model (-1) #seek_cur 
	WriteLong pso2Model 0x8         -- Size of NEND
	for i = 1 to 3 do               -- Padding
	(
		WriteLongLong pso2Model 0
	)
	
	fEnd = (ftell pso2Model)
	--Fill remaining addresses
	--afp Null addresses
	if (realFType != "aqo" and realFType != "tro") then
	(
		fseek pso2Model afpDataSizeOff #seek_set
		WriteLong pso2Model (fEnd-0x50)
		fseek pso2Model afpNextFileOff #seek_set
		WriteLong pso2Model (fEnd-0x10)
	)
	--Nifl Null addresses
	fseek pso2Model nofMinus20Add #seek_set
	WriteLong pso2Model (nofBegin - fileOffset)
	WriteLong pso2Model (nofBegin - fileOffset + 0x20)
	WriteLong pso2Model (nofSize + 0x10)
	--REL addresses
	fseek pso2Anim relSizeAdd #seek_set
	WriteLong pso2Model (nofBegin - (relSizeAdd + 0x04) - 0x40)
	
	
	fflush pso2Model
	fclose pso2Model
	
	--Cleanup
	for o in extraBoneList do
	(
		delete o
	)
	
	print "Success!"
)