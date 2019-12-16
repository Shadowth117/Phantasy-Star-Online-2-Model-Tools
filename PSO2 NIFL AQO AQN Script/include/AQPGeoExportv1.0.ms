/*
	PSO2 .aqp/.aqo geometry export

	-Huge Thanks to TGE for function(s) from other scripts
	-Thanks to Liinko for his DetachElementsFromSkin function from the FFXIV Modding Tool script
*/

ClearListener()
FileIn @"MaxScriptExtensions\FileStreamReader.ms"
FileIn @"MaxScriptExtensions\FileUtils.ms"
FileIn @"UnusedBoneRemover.ms"

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
	MeshFaces,
	MeshVerts,
	MeshId
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
	objFaceArrayList = #()
	filled = false
	
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
			
			--Get bones in this face
			for v in faceVerts do
			(
				weightCount = skinOps.GetVertexWeightCount objSkin v
				
				for b = 1 to weightCount do
				(
					bId = (skinOps.GetVertexWeightBoneID objSkin v b)
					appendIfUnique faceBones bId
				)
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

fn pso2VertOptimizer meshes =
(
	meshData = #()
	for obj in meshes do
	(
		local pso2VertArr = #()
		fCount = (getNumFaces obj.mesh)
		objFaces = #()
		
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
					)
					
					tempVert.VertBones = _bones
					tempVert.VertWeights = weights
					append tempVert.VertFaceArray #(f)
				)
				
				--Get vert colors
				if (meshop.getMapSupport obj.mesh 0) == true then
				(
					vcolor = (meshop.getMapVert obj.mesh 0 ((meshop.getMapFace obj.mesh 0 f)[v])) as color
					if (meshop.getMapSupport obj.mesh -2) == true then
					(
						vcolor.alpha = (meshop.getMapVert $.mesh -2 (meshop.getMapFace $.mesh -2 1)[1]).x
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
						append pso2VertArr[v].VertUNRMs pso2VertArr.count
						objFaces[f][v] = pso2VertArr.count
					)
				)
			)
		)
		
		--append vertex, material, original mesh id, and face data to an array when done
		tempMesh 				= pso2Mesh()
		tempMesh.MeshMat 		= obj.material[GetFaceMatId obj.mesh 1]
		tempMesh.MeshFaces  	= objFaces
		tempMesh.MeshVerts 		= pso2VertArr
		tempMesh.MeshId 		= (getUserProp bMesh[i] "meshId")
		append meshData tempMesh
	)
	
	--return array with face, material, and vertex data for final write, delete export processed meshes
	meshData
)

--Unused; Made for calculating pso2 unrms (vertices split from the same base vertex) from scene meshes. Final functionality calculated this in the vertex optimization function 
fn calcUNRMs meshes =
(
	unrms = #()
	for m=1 to meshes.count do
	(
		for v=1 to (GetNumVerts meshes[m]) do
		(
			unrm = #()
			append unrm (uNRMStruct MeshNum:m VertId:v)
			for n=m to meshes.count do
			(
				for w=1 to (GetNumVerts meshes[n]) do
				(
					if n==m and v==w then
					(
						continue
					)
					if (GetVert meshes[m] v) == (GetVert meshes[n] w) then
					(
						append unrm (uNRMStruct MeshNum:m VertId:v)
					)
				)
			)
			append unrms unrm
		)
	)
	
	unrms
)

fn GeoExport aqpFile ResizeChecked ResizeValue YZRot =
(	
	ftype = getFilenameType aqpFile
	
	startPath = getFilenamePath(getThisScriptFilename())
	dotnet.loadAssembly (startPath + "\\NvTriStripDotNet.dll")
	
	--Split meshes by material - note: ReplaceVertexWeights automatically reevaluates weight(s) that do not total 1 by increasing the ratios of each existing weight proportionally to sum to 1. 
	baseMeshes = for g in geometry where g.parent == undefined and g.children.count == 0 collect g
	for i=1 to baseMeshes.count do (setUserProp bMesh[i] "meshId" i)
	aqpMeshes = splitMeshByMaterial baseMeshes
	
	--Possible 16 bone limit per mesh? If so, split per that as well. Generate dummy nodes for each final mesh with one name and a number. Dummy nodes should be placed before physics nodes (though this may not be required)
	aqpMeshes = splitMeshByBoneCount aqpMeshes 16
	
	--Check for used vertex types: (0x0 Vertex Position) (0x1 Vertex Weights) (0x2 Vertex Normal) (0x21 Binormals) (0x20 Tangents) (0x3 Vertex Color) (0x4 Vertex Color 2?) (0xb Weight Index) (0x10 UV1 Buffer) (0x11 UV2 Buffer) (0x12 UV3 Buffer)
		--Duplicate and separate vertices based on if multiple UV channels/VC channels exist for it. 
	aqpMeshData = pso2VertOptimizer aqpMeshes
	
	--Loop through all meshes and store ids for vertices with the same location together. Create UNRM information from this (Optional to store UNRM?)
	--unrmArray = CalcUNRMs aqpMeshes

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
	
	fileOffset = 0x20
	--AFP Header
	if (ftype != "aqo" and ftype != "tro") then
	(
		fileOffset += 0x30                 --add extra offset to our main offset
		
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
		WriteLong pso2Model 0			   -- Filesize after write minus fileOffset aka 0x50
		WriteLong pso2Model 0x30           -- afp added offset
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
	maxVTXLOff = (ftell pso2Model)
	WriteLong pso2Model 0				--Size of largest VTXL Vertex struct
	WriteLong pso2Model totalFaces		--Total Strip Face Indices count
	WriteLong pso2Model 0				--Reserve 0
	WriteLong pso2Model totalVertices	--Total VTXL/Vertex Count
	WriteLong pso2Model 0				--Reserve 0
	WriteLong pso2Model aqpMeshData.count --Unknown Count (The following counts share a value)
	WriteLong pso2Model aqpMeshData.count --VSET Count 
	vSetOBJCOff = (ftell pso2Model)		--VSET Offset
	WriteLong pso2Model 0
	WriteLong pso2Model aqpMeshData.count --PSET Count
	pSetOBJCOff = (ftell pso2Model) 	--PSET Offset
	WriteLong pso2Model 0
	WriteLong pso2Model aqpMeshData.count --MESH Count; Count values stop being shared
	meshOBJCOff = (ftell pso2Model) 	--MESH Offset
	WriteLong pso2Model 0
		--MATE Count
		--MATE Offset
		--REND Count
		--REND Offset
		--SHAD Count
		--SHAD Offset
		--TSTA Count
		--TSTA Offset
		--TSET Count
		--TEXF Count
		--TEXF Offset
		--Field with Model Center xyz, 0, Bounding Radius, Model Center xyz again, 0, Max minus Min Point distance / 2 xyz, 0
	WriteLong pso2Model aqpBounds.OrigX
	WriteLong pso2Model aqpBounds.OrigY
	WriteLong pso2Model aqpBounds.OrigZ
	WriteLong pso2Model 0
	WriteLong pso2Model aqpBounds.Radius
	WriteLong pso2Model aqpBounds.OrigX
	WriteLong pso2Model aqpBounds.OrigY
	WriteLong pso2Model aqpBounds.OrigZ
	WriteLong pso2Model 0
	WriteLong pso2Model aqpBounds.DiffX
	WriteLong pso2Model aqpBounds.DiffY
	WriteLong pso2Model aqpBounds.DiffZ
	WriteLong pso2Model 0
	uNRMOff = (ftell pso2Model) --UNRM Offset (If available, usually only for player models?)
	WriteLong pso2Model 0
	
	--VSET Struct Vertex Set
		--Total size per chunk of vertex data
		--Number of VTXE Structs (vertex data structs) per vertex
		--Offset of VTXE
		--Number of VTXL Structs/Vertices
		--Offset of VTXL Structs
		--Unknown 0
		--Bone Palette 1 Bone Count    (May need to stay under 16? The second palette, if is one, often exceeds thhis of course)
		--Bone Palette 1 Offset
		--Unknown 1
		--Unknown 2
		--Unknown 3
		--Bone Palette 2? Bone Count
		--Bone Palette 2? Offset
		
	--VTXE Struct - These define the types of data each vertex has 
		--Data Type ID, by Sega's order (0x0 Vertex Position) (0x1 Vertex Weights) (0x2 Vertex Normal) (0x21 Binormals) (0x20 Tangents) (0x3 Vertex Color) (0x4 Vertex Color 2?) (0xb Weight Index) (0x10 UV1 Buffer) (0x11 UV2 Buffer) (0x12 UV3 Buffer)
		--Data Format ID (0x2 - UV FloatVector2) (0x3 - Various FloatVector3) (0x5 - Color, B G R A bytes)
		--Position in Vertex Data (Vert  data has each VTXE type laid out in sequence for a given vertex before moving to the next. This is the relative to the beginning of a particular vertex's data.) 
		--Reserve
	--VTXL Struct - These are the vertex data structs defined in the VTXE before this
	
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
		faceCountOff = (ftell pso2Model)
		WriteLong pso2Model 0                       --FaceCount Offset
		WriteLong pso2Model aqpStrips[i].count      --Pset face count
		faceOff = (ftell pso2Model)
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
		paddingLoops = 8 - (mod aqpStrips[i].count 8)
		for i = 1 to paddingLoops do
		(
			WriteShort pso2Model 0
		)
	)
	
	--MESH Structs
		--Unk U16, 0 or 1
		--Unk U16, 0x11 or 0x14 often
		--Unk U16, always 0?
		--Unk U8, usually 0x63 or 0x64
		--Unk U8, usually 0x80
		--Material Index for current mesh
		--Render Index for current mesh
		--Shader Index for current mesh
		--Texture Set Index for current mesh
		--Bone Index for autogenerated base mesh dummy; These are ordered before physics bones, but after normal bones. 
			--Presumably just for debugging/organization normally, but also used for rigid weighting objects that didn't originally have bones
			--Assumedly, meshes outside hierarchy are weighted to root while those with a hierarchy are placed as such while placing the node's mesh in the mesh data.
		--VSET?, Mesh Index
		--PSET?, Mesh Index
		--Autogenerated base mesh dummy id. 0 if there's only one, presumably, though if multiple exist, the dummies are numbered. Dummy order seems arbitrary (ie. first num may be 6, followed by 2 in hierarchy etc.)
		--Unk, often 0
		--0
	
	--MATE Structs
		--Material Diffuse Color Vector4
		--Material Specular Color Vector4
		--Material Reflection Color? Vector4
		--Material Color Vector4; Maybe Ambient?
		--0
		--Unk Float, often 8 or 32
		--Unk Float, usually 1
		--Unk Int, usually 100
		--Unknown, usually 0
		--20 Char String, "opaque", "hollow", "blendalpha"
		--20 Char String, Material Name
		
	--REND Structs
		-- 0x1FF
		-- 3 usually
		-- 1 Two-sided, 0 Backface Cull, 2 used in persona live dance models but unknown
		-- 1 Alpha blend enabling setting
		-- 5 usually
		-- 6 usually
		-- 1 usually
		-- 0 usually
		-- 5 usually
		-- 6 usually
		-- 1 Another alpha setting? Maybe for multi/_s map?
		-- 5 usually
		-- 0-256, DXT 1 alpha setting? (assumedly value of alpha at which a pixel is rendered invisible vs fully visible)
		-- 1 usually
		-- 4 usually
		-- 1 usually
		
	--SHAD Structs
		-- 0 always?
		-- 0x20 Shadername string with p
		-- 0x20 Shadername string sans p
		-- 0 always?
		
	--TSTA Structs
		-- 0x16
		-- TSET Texture Usage Order, 0,1,2,3
		-- UV set number (0 based), for env maps use -1 (FFFFFFFF)
		-- 0                         Color related for these 3?
		-- negative 0 float     Color related for these 3?
		-- 0                         Color related for these 3?
		-- 0
		-- 0
		-- 0
		-- 1 or 3 sometimes
		-- 1 or 3 sometimes
		-- 1
		-- 0 
		-- 0
		-- 0x20 string of texture name with extension
		
	--TSET Structs (Texture Set)
		-- 0?
		-- Used texture count
		-- 0
		-- 0
		-- 0
		--First Tex ID - If no tex id, -1 for any null tex id
		--Second Tex ID
		--Third Tex ID
		--Fourth Tex ID
		
	--TEXF Structs
		-- 0x20 texture name string
	
	--UNRM Struct - Links vertices split for various reasons (vertex colors per face, UVs, etc.)
		-- Linked vertices amounts count (Each entry )
		-- Linked vertices amounts offsets
		-- VSet ID/Vertex ID list count
		-- VSet ID list offset
		-- Vertex ID offset
		
	--NOF0
	WriteString pso2Model "NOF0"    
	fseek pso2Model (-1) #seek_cur 
	NofSizeOff = (ftell pso2Model) 	-- Get size offset
	WriteLong pso2Model 0
	WriteLong pso2Model 0           -- Entry count
	
	--NEND
	WriteString pso2Model "NEND"
	fseek pso2Model (-1) #seek_cur 
	WriteLong pso2Model 0x8         -- Size of NEND
	for i = 1 to 3 do               -- Padding
	(
		WriteLongLong pso2Model 0
	)
)