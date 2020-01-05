------------------------------------------------------------------
--PSO2 vertex colored obj importer

--Heavily altered from Chris Cookson's original import script
--by Shadowth117

------------------------------------------------------------------
--Original script

-- Wavefront OBJ/MTL Import Utility	for gmax, v1.1				--
-- by Chris Cookson (cjcookson@hotmail.com)						--
--																--
-- All code (c) Copyright Chris Cookson, 2001					--
-- Please use this script any way you wish - just				--
-- drop me a line if you do something cool with it!				--
-- 																--
-- With thanks to Jack Palevich									--
--																--
-- Changelog:													--
--																--
-- v1.1(a)	Fixed bug with importing objects with no materials	--
-- v1.1		Should now work with 3DSMAX R3/4					--
--																--
------------------------------------------------------------------

ClearListener()
FileIn @"include\AQNBoneImportv1.3.ms"
FileIn @"include\AQPGeoExportv1.0.ms"

rollout objImport "PSO2 AQP/AQN Tool"
(
		--------------------
	-- User Interface --
	--------------------
	group "About"
	(
		label lab1 "PSO2 AQP/AQN Tool"
		Label lab2 "By Shadowth117"
	)
	group "Settings"
	(
		checkBox autoSizeCheckBox "Rescale" checked:true align:#center
		spinner autoSizeSpinner "Scale by:" align:#center type:#float range:[0,10000,100] enabled:false
		checkBox YZCheckBox "Y-Z Axis Flip" checked: true align:#center
		checkBox UVFlip "Vertical UV Flip" checked: true align:#center
		checkBox PSO2Bones "Skin with PSO2 bones" checked:true align:#center
		checkBox BonesByFN "Bones by model filename" checked:true align:#center
		--checkBox prsVals "PRS values on bones" checked:false align:#center
		checkBox KeepBoneIds "Bone IDs in object name" checked:true align:#center
	)	
	group "Import"
	(
		button importButton "Import..."
	)
	group "Batch Import from Path"
	(
		button importPath "Import..."
	)
	group "Export AQP/TRP"
	(
		button exportAQPButton "Export..."
		checkBox playerModel "Player Model" checked:true align:#center
		checkBox difWhite "White Diffuse Tint" checked:true align:#center
		checkBox unrmAvg "Average UNRM Normals" checked:true align:#center
		Label exportNote "Note: Vertex weights past the"
		Label exportNote2 "4th greatest are redistributed"
	)
	/*
	group "Convert hierarchy to bones"
	(
		button convToBones "Convert..."
	)*/
	group "Import AQN Only"
	(
		button importAQNButton "Import..."
	)
	group "Export AQN"
	(
		button exportAQNButton "Export..."
	)
	group "AQM Tool"
	(
		button openAQMButton "Open AQM Tool"
	)
	----------
	-- Vars --
	----------
	local currentPath=""

	-------------
	-- Structs --
	-------------
	struct Tokenizer
	(
		tokens = #(),
		
		fn SetString str=
		(
			tokens = filterString str "\t ,"
		),
		
		fn ReadToken=
		(
			if tokens.count > 0 then
			(
				local tok = tokens[1]
				deleteItem tokens 1
				tok
			) else
			(
				undefined
			)
		),
		
		fn PeekToken=
		(
			if tokens.count > 0 then tokens[1] else undefined
		)
	)
	

	
	----------------------
	-- Helper Functions --
	----------------------

	-- Read a float from a tokenizer with default fallback
	function ReadFloat tkzr default:0.0 =
	(
		local floatStr = tkzr.ReadToken()
		if (floatStr != undefined and floatStr != "nan") then
			return floatStr as float
		else
			return default
	)
	
	-- Read an integer from a tokenizer with default fallback
	function ReadInt tkzr default:0 =
	(
		local intStr = tkzr.ReadToken()
		if intStr != undefined then
			return intStr as float
		else
			return default
	)
	
	-- Read a face vertex definition of the form v/t/n where t or n are optional
	function ReadFaceVertex tkzr =
	(
		local token = tkzr.ReadToken()
		local vdef = filterString token "/"

		local v = vdef[1] as integer
		local t = 0
		local n = 0
		
		-- Is there a texcoord or just a blank?
		if (vdef.count > 1) and (findString token "//") == undefined then
		(
			t = vdef[2] as integer
			if vdef.count == 3 then n = vdef[3] as integer
		) else
		(
			if vdef.count == 2 then n = vdef[2] as integer
		)
		
		[ v, t, n ]
	)
	
	-- Load a MTL material library definition file and return a gmax multi material
	function LoadMaterialLibrary filename: filepath: =
	(
		local newMaterial = multimaterial numsubs:0
		if filename == undefined then
		(
			-- Return a default MAX material
			newMaterial.numsubs = 1
			newMaterial[1] = standard name:"Unnamed"
			return newMaterial
		)
		
		-- Check file exists
		if (getFiles filename).count == 0 then
		(
			newMaterial.numsubs = 1
			newMaterial[1] = standard name:(getFilenameFile filename)
			return newMaterial
		)
		newMaterial.name = (getFilenameFile filename)
		
		local curIndex = 0
		
		mtlStream = openFile filename mode:"r"

		try
		(
			local materialName
			local curMaterialID = -1
			
			local diffuse, specular, ambient, specularPower, diffuseMap
			
			while not (eof mtlStream) do
			(
				local lineTokenizer = Tokenizer()
				local curLine = readLine mtlStream
				lineTokenizer.SetString curLine
				local idToken = lineTokenizer.ReadToken()
				
				case idToken of
				(
					"newmtl": -- Define a new material
					(
						local materialName = lineTokenizer.ReadToken()
						
						curIndex += 1
						newMaterial.numsubs += 1
						newMaterial[curIndex] = standard name:materialName
					)
					
					"Kd": -- Diffuse reflectivity
					(
						local red = ReadFloat lineTokenizer
						local green = ReadFloat lineTokenizer
						local blue = ReadFloat lineTokenizer
						diffuse = color (red*255) (green*255) (blue*255)
						newMaterial[curIndex].diffuse = diffuse
					)
					
					"Ks": -- Specular reflectivity
					(
						red = ReadFloat lineTokenizer
						green = ReadFloat lineTokenizer
						blue = ReadFloat lineTokenizer
						specular = color (red*255) (green*255) (blue*255)
						newMaterial[curIndex].specular = specular
					)
					
					"Ka": -- Ambient reflectivity
					(
						local red = ReadFloat lineTokenizer
						local green = ReadFloat lineTokenizer
						local blue = ReadFloat lineTokenizer
						ambient = color (red*255) (green*255) (blue*255)
						newMaterial[curIndex].ambient = ambient						
					)
					
					"Ns": -- Specular power
					(
						specularPower = ReadFloat lineTokenizer
						newMaterial[curIndex].specularLevel = specularPower
					)
					
					"map_Kd": -- Diffuse texture map
					(
						diffuseMapFile = curLine
						local pos = findString diffuseMapFile "map_Kd"
						diffuseMapFile = substring diffuseMapFile (pos + 6) (diffuseMapFile.count - pos - 5)
						diffuseMapFile = trimRight diffuseMapFile
						diffuseMapFile = trimLeft diffuseMapFile 
						
						if (getFiles (diffuseMapFile)).count != 0 then
						(
							-- Texture map file exists, so set it up and make it visible in viewports
							local diffuseMap = bitmapTexture filename: (filepath + diffuseMapFile) name:(getFilenameFile diffuseMapFile)
							newMaterial[curIndex].maps[2] = diffuseMap	
							newMaterial[curIndex].mapEnables[2] = true
							showTextureMap newMaterial[curIndex] diffuseMap true
						) else
						(
							-- Can't find texture map file :(
							--format "Warning: Cannot find texture map file %\n" diffuseMapFile
							newMaterial[curIndex].mapEnables[2] = true
						)
					)
				)	
			)
		)
		catch
		(
			messageBox "Error loading material file!"
			throw
		)
			
		close mtlStream
		
		newMaterial		-- No need for return!
	)

	--------------------------
	-- Main Import Function --
	--------------------------


    function importObject objFileName boneByModel =
	(
		--- Imported Data ---
	
		local verts = #()
		local faces = #()
		local normals = #()
	
		local texCoords = #()
		local texCoords2 = #()

		local vertColors = #()
		local colorArray = #()
		local texFaces = #()
		
		local faceMaterialIDs = #()
		local faceGroupIDs = #()
		local vertGroupIDs = #()
	
		local materialNames = #()
		local groupNames = #()
		
		local pso2BoneArray = undefined
		local boneWeights = #()
		local boneIds = #()
		local bonePalGroups = #()
	
		local groupName = undefined
		local objectName = undefined
		local materialLib = undefined

		-- If user made a selection, begin importing
		if objFileName != undefined then
		(
			currentPath = getFilenamePath objFileName
			print objFileName
			--If the user wants to import PSO2 skinning, do so
			if (PSO2Bones.checked) then
		    (
				
				local boneFileName = undefined
				
				-- Open up a dialog box
				if (boneByModel == true) then
				(
					boneFileName = filterString (filenameFromPath objFileName) "."
					boneFileName = (currentPath + boneFileName[1] + ".aqn")
					print boneFileName
					--print (doesFileExist boneFileName)
					if ((doesFileExist boneFileName) == false) then
					(
						boneFileName = undefined
					)
				)
				else
				(
					boneFileName = getOpenFileName caption:"Import Phantasy Star Online 2 .aqn/.trn" \
						types:"PSO2 Skeleton AQN/TRN (*.aqn,*.trn)|*.aqn;*.trn|All Files (*.*)|*.*|"
				)
				
				if (boneFileName != undefined) then
				(
					--pso2BoneArray = (SkelImport boneFileName prsVals.checked autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked KeepBoneIds.checked)
					pso2BoneArray = (SkelImport boneFileName false autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked KeepBoneIds.checked)
				) 
			)
			
			local curMaterialID = 0
			local curGroup = 0
			local lineNum = 0
			local isValid = true
			local vtBeforeG = false
			
			-- Open up the file
			vtStream = openFile objFileName mode:"r"	
			--Test if HPP or PSO2 style vt
			try
			(
				gFound = false
				vcUsed = false
				vuUsed = false
				-- Go through the whole OBJ file
				while not (eof vtStream) do
				(
					local lineTokenizer = Tokenizer()
					
					lineTokenizer.SetString (readLine vtStream)
					
					lineNum += 1
					
					-- Read the data ID tag
					local idToken = lineTokenizer.ReadToken()
					
					if idToken != undefined do
					(
	
						case idToken of
						(					
							"g": 
							(
								gFound = true
							)
							
							"vt": -- Set vertex texcoord
							(
								if (gFound == false) then
								(
									vtBeforeG = true
								)
							)
							
							"vu": -- Set vertex texcoord
							(
								vuUsed = true
							)
							
							"vc": -- Set vertex texcoord
							(
								vcUsed = true
							)
							
							default:
							(
							)
						)
					)
				)				
			) catch
			(
				close vtStream
			)
			
			vtCount = 0
			vtPad = false
			vuPad = false
			-- Open up the file
			objStream = openFile objFileName mode:"r"	
			try
			(
				-- Go through the whole OBJ file
				while not (eof objStream) do
				(
					local lineTokenizer = Tokenizer()
					local bonePalette = #()
					
					lineTokenizer.SetString (readLine objStream)
					
					lineNum += 1
					
					-- Read the data ID tag
					local idToken = lineTokenizer.ReadToken()
					
					if idToken != undefined do
					(
	
						case idToken of
						(
							"o": -- Object name
							(
								objectName = lineTokenizer.ReadToken()
							)
							
							"bp": -- Bone palette
							(
								loopCheck = true
								while(loopCheck == true) do
								(
									
									local bonePalLoop = lineTokenizer.ReadToken()
									if (bonePalLoop != undefined) then
									(
										append bonePalette ( bonePalLoop )
									) else (
										loopCheck = false
									)
								)
								append bonePalGroups bonePalette
								bonePalette = undefined
							)
							
							"g": -- Define group
							(
								if (vtBeforeG == false) then
								(
									vtCount = 0
									vtPad = true
									vuPad = true
									vcPad = true
								)
								groupName = lineTokenizer.ReadToken()
								append groupNames groupName
								curGroup = groupNames.count
							)
							
							"mtllib": -- Set material library file
							(
								materialLib = lineTokenizer.ReadToken()
							)
							
							"usemtl": -- Use specified material
							(
								local matName = lineTokenizer.ReadToken()
								
								-- Have we seen this material name before?
								local index = findItem materialNames matName
								if index == 0 then
								(
									-- No, add it to our list
									append materialNames matName
									curMaterialID = materialNames.count
								) else
								(
									-- Yes, we already have an ID
									curMaterialID = index
								)
							)
							
							"v": -- Set vertex co-ordinate
							(
								if (vtBeforeG == false) then
								(
									append vertGroupIDs curGroup
									vtCount += 1
								)
								
								local x = ReadFloat lineTokenizer
								if YZCheckBox.checked then
								(
								    local z = (ReadFloat lineTokenizer)
								    local y = -(ReadFloat lineTokenizer)
								) else 
								(
								    local y = ReadFloat lineTokenizer
									local z = ReadFloat lineTokenizer
								)
								append verts [ x, y, z ]
							)
							
							"vt": -- Set vertex texcoord
							(
								vtPad = false
								
								local u = ReadFloat lineTokenizer
								if UVFlip.checked then
								(
								local v = -(ReadFloat lineTokenizer)
								) else
								(
								local v = (ReadFloat lineTokenizer)
								)
								local w = ReadFloat lineTokenizer
								append texCoords [ u, v, w ]
							)
							
							"vu": -- Set vertex texcoord
							(
								vuPad = false
								
								local u = ReadFloat lineTokenizer
								if UVFlip.checked then
								(
								local v = -(ReadFloat lineTokenizer)
								) else
								(
								local v = (ReadFloat lineTokenizer)
								)
								local w = ReadFloat lineTokenizer
								append texCoords2 [ u, v, w ]
							)
							"vc": -- Set vertex color
							(
								vcPad = false
								
								local r = ReadFloat lineTokenizer
								local g = ReadFloat lineTokenizer
							    local b = ReadFloat lineTokenizer
								local a = ReadFloat lineTokenizer
								/*append vertColors [ r, g, b, a ] */
								vertColor = color r g b a
								append colorArray vertColor
							)
							"vn": -- Set vertex normal
							(
								
								local nx = ReadFloat lineTokenizer
								
								if (YZCheckBox.checked) then
								(
								    local nz = (ReadFloat lineTokenizer)
								    local ny = -(ReadFloat lineTokenizer)
								) else 
								(
								    local ny = ReadFloat lineTokenizer
									local nz = ReadFloat lineTokenizer
								)
								/*
								local ny = ReadFloat lineTokenizer
								local nz = ReadFloat lineTokenizer
								*/
								append normals [ nx, ny, nz ]
							)
							
							"f": -- Define face (coord index/texcoord index/normal index)
							(
								-- Append null tex coords if they didn't exist for a group set
								if (vtBeforeG == false) then
								(
									if (vtPad == true) then
									(
										for l = 1 to vtCount do
										(
											append texCoords [ 0, 0, 0 ]
										)
									)
									
									if (vuPad == true and vuUsed == true) then
									(
										for l = 1 to vtCount do
										(
											append texCoords2 [ 0, 0, 0 ]
										)
									)
									
									if (vcPad == true and vcUsed == true) then
									(
										for l = 1 to vtCount do
										(
											append colorArray (color 255 255 255 255)
										)
									)
									vcPad = false
									vtPad = false
									vuPad = false
								)

								
								local v1 = ReadFaceVertex lineTokenizer
								local v2 = ReadFaceVertex lineTokenizer
								local v3 = ReadFaceVertex lineTokenizer
																						
								-- TODO: Add support for n-sided planar polys
								/*if YZCheckBox.checked then
								(
								    append faces [ v2[1], v1[1], v3[1] ]
								    append faceMaterialIDs curMaterialID
								    append texFaces [ v2[2], v1[2], v3[2] ]
								) else */
								(
								    append faces [ v1[1], v2[1], v3[1] ]
								    append faceMaterialIDs curMaterialID
									append faceGroupIDs curGroup
								    append texFaces [ v1[2], v2[2], v3[2] ]
								)
							)
							
							"bw":
							(
								--Add indices until 1.0 of weight or 4 weights and then stop
								local sum = 0
								local bwArr = #()
								for i = 1 to 4 do
								(
									--                                                        Account for float weirdness
									if (i == 1 and sum < 1.0) or (i > 1 and sum < 0.999999) then
									(
										bwArr[i] = ReadFloat lineTokenizer 
										sum += bwArr[i]
									)
								)
								append boneWeights bwArr
							)
							
							"bi":
							(
								--Add indices to index array, but stop 
								local biArr = #()
								local zeroUsed = false
								for i = 1 to 4 do
								(
									temp = ReadFloat lineTokenizer 
									if i == 1 or (i > 1 and (temp != 0.0)) then
									(
										biArr[i] = temp + 1
									)
								)
								append boneIds biArr
							)
							
							"#": -- Comment (ignore)
							(
							)
							
							default:
							(
							)
						)
					)
				)				
			) catch
			(
				messageBox "Error reading OBJ file!"
				isValid = false
				close objStream
				throw
			)
			
			-- Close the file stream
			close objStream
			
			if isValid then
			(
				-- Load and parse the material library (if present)
				if materialLib != undefined then
				(
					newMaterial = LoadMaterialLibrary filename:(currentPath + materialLib) filepath:(currentPath)
				) else
				(
					newMaterial = multimaterial prefix:(getFilenameFile objFileName)
					newMaterial.numsubs = 1
					newMaterial[1] = standard prefix:"Material"
				)
				
				-- Remap ad-hoc face material IDs onto gmax material IDs
				for i = 1 to faceMaterialIDs.count do
				(

					-- Make sure material IDs are valid - we can be sure there's always 1 submaterial
					if (faceMaterialIDs[i] > newMaterial.numsubs) or (faceMaterialIDs[i] < 1) then
					(
						faceMaterialIDs[i] = 1
					)
					else
					(
						local matName = materialNames[faceMaterialIDs[i]]

						-- Find corresponding gmax material
						for matID in newMaterial.materialIDList where (newMaterial[matID].name == matName) do
						(
							faceMaterialIDs[i] = matID
						)
					)
				)
				
				objNameAlone = filterString (filenameFromPath objFileName) "."
				objNameAlone = objNameAlone[1]
				fileGroupName = (objNameAlone) 
				
				
				local importList = #()
				
				--Account for bone palette 0 being ordered after a later bone for whatever reason 
				for i = 1 to boneWeights.count do
				(
					if boneWeights[i].count > boneIds[i].count then
					(
						boneIds[i][boneWeights[i].count] = 1.0
					)
					for m =1 to boneWeights[i].count do
					(
						if boneWeights[i][m] == undefined then
						(
							boneWeights[i][m] = 0.0
						)
					)
				)
				--Account for the opposite
				for i = 1 to boneIds.count do
				(
					if boneIds[i].count > boneWeights[i].count then
					(
						for m = 1 to boneIds[i].count do
						(
							if (boneWeights[i][m] == undefined) then
							(
								boneWeights[i][m] = 0.0
							)
						)
					)
					for m =1 to boneIds[i].count do
					(
						if boneIds[i][m] == undefined then
						(
							boneIds[i][m] = 1.0
						)
					)
					
					--print ("BoneIDs: " + boneIds[i] as string)
					--print ("BoneWeights(processed?): " + boneWeights[i] as string)
				)
				
				for k = 1 to groupNames.count do
				(				
					
					--Start a sub array of faces per group, store original face id as well for later use
					local faceArray = #()
				    local faceOrigID = #()
					local vertArray = #()
					local vertOrigID = #()
					
					for j = 1 to faces.count do
					(
						if(faceGroupIDs[j] == k) then 
						(
							append faceArray faces[j]
							append faceOrigID j
						)
					)
					
					--Start a sub array of vertices if they were stored in groups
					if (vtBeforeG == false) then
					(
						vertStart = -1
						vertEnd = -1
						start = true
						inGroup = false
						for j = 1 to verts.count do
						(
							if(vertGroupIDs[j] == k) then 
							(
								inGroup = true
								if(start == true) then
							    (
									start = false
									vertStart = j
								)
								append vertArray verts[j]
								append vertOrigID j
							) else 
							(
								if (inGroup == true) then
								(
									VertEnd = j - 1
									inGroup = false
								)
							)
						)
						for j = 1 to faceArray.count do
						(
							faceArray[j].x = (findItem vertOrigID faceArray[j].x) as float
							faceArray[j].y = (findItem vertOrigID faceArray[j].y) as float
							faceArray[j].z = (findItem vertOrigID faceArray[j].z) as float
						)
						-- Construct the mesh object
						local newMesh = mesh name:groupNames[k] pos:[0,0,0] \
												vertices:vertArray faces:faceArray \
												material:newMaterial
						--print ("vertArray Verts: " + vertArray.count as string + " newMesh Verts: " + newMesh.numVerts as string)
					)
					else
					(
						-- Construct the mesh object
						local newMesh = mesh name:groupNames[k] pos:[0,0,0] \
												vertices:verts faces:faceArray \
												material:newMaterial
					)
					
					append importList newMesh
					
					-- Add texCoords
					if texCoords.count > 0 then
					(
						
						-- Add UV channel 2 if it exists
						if texCoords2.count > 0 do
						(
							--Check if by group or not
							if(vtBeforeG == false) then
							(
								meshop.setNumMaps newMesh ((meshop.getNumMaps newMesh) + 1) keep:true
								meshop.setMapSupport newMesh 2 true
								meshop.setNumMapVerts newMesh 2 vertArray.count
								meshop.setNumMapFaces newMesh 2 (meshop.getNumFaces newMesh) 
								
								for i = 1 to vertArray.count do
								(
									meshop.setMapVert newMesh 2 i texCoords2[vertOrigID[i]]
								)
							)
							else
							(
								meshop.setNumMaps newMesh ((meshop.getNumMaps newMesh) + 1) keep:true
								meshop.setMapSupport newMesh 2 true
								meshop.setNumMapVerts newMesh 2 texCoords2.count
								meshop.setNumMapFaces newMesh 2 (meshop.getNumFaces newMesh) 
								
								for i = 1 to texCoords2.count do
								(
									meshop.setMapVert newMesh 2 i texCoords2[i]
								)

							)
							for i = 1 to (meshop.getNumFaces newMesh) do
							(
								meshop.setMapFace newMesh 2 i faceArray[i]
							)
						)
						meshop.setMapSupport newMesh 1 true
						meshop.setMapSupport newMesh 0 true
						meshop.setMapSupport newMesh -2 true

						--Group or not again
						if(vtBeforeG == false) then
						(
							meshop.setNumMapVerts newMesh 1 vertArray.count
							meshop.setNumMapFaces newMesh 1 (meshop.getNumFaces newMesh) 
							
							for i = 1 to vertArray.count do
							(
								meshop.setMapVert newMesh 1 i texCoords[vertOrigID[i]]
							)

						) else
						(
							meshop.setNumMapVerts newMesh 1 texCoords.count
							meshop.setNumMapFaces newMesh 1 (meshop.getNumFaces newMesh) 
							
							for i = 1 to texCoords.count do
							(
								meshop.setMapVert newMesh 1 i texCoords[i]
							)
						)
														
						for i = 1 to (meshop.getNumFaces newMesh) do
						(
							meshop.setMapFace newMesh 1 i faceArray[i]
						)
						
					)
					
					setNumCPVVerts newMesh newMesh.numverts
					
					-- Set vertex coloring -- 
					if(vtBeforeG == false) then
					(
						if colorArray.count > 0 then
						(
							for i = 1 to newMesh.numVerts do
							(
								
								if colorArray[vertOrigID[i]] == undefined then
								(
									print ("bad egg: " + vertOrigID[i] as string)
								)
								setvertcolor newMesh i colorArray[vertOrigID[i]]
								meshop.setvertalpha newMesh -2 i colorArray[vertOrigID[i]].alpha
							)
						)
					) else 
					(
						for i = 1 to colorArray.count do
						(
							setvertcolor newMesh i colorArray[i]
							meshop.setvertalpha newMesh -2 i colorArray[i].alpha
						)  
					)
					
					-- Set face material IDs
					for i = 1 to (meshop.getNumFaces newMesh) do
					(
						setFaceMatID newMesh i faceMaterialIDs[faceOrigID[i]]					
					)
					defaultVCFaces newMesh
					
					-- Convert to Editable_Poly to avoid vert color destroying nonsense
					-- Note: This messes up vertex ids by adding vertices. As a result, doing this before skinning is a problem.
					-- Unfortunately, skinned meshes also cannot be converted in post.
					--ConvertTo newMesh Editable_Poly
					
					-- Crude scaling, need to make this a bit more intelligent
					if autoSizeCheckBox.checked then
					(
						local scale = [autoSizeSpinner.value, autoSizeSpinner.value, autoSizeSpinner.value]
						
						for i = 1 to newMesh.numverts do
						(
							local v = getvert newMesh i
							v *= scale
							setvert newMesh i v
						)
					)
					meshop.removeDegenerateFaces newMesh
					update newMesh
					
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
					--EN_makeExplicit = newMesh.Edit_Normals.MakeExplicit
					EN_setExplicit = newMesh.Edit_Normals.SetNormalExplicit
					normID = #{}

					
					for v = 1 to newMesh.verts.count do(
						free normID
						EN_convertVS #{v} &normID
						for id in normID do 
						(
							EN_setSelection #{id}
							EN_setExplicit id explicit:true
							--print normals[vertOrigID[v]]
							EN_setNormal id normals[vertOrigID[v]]
						)
					)
					
					/*
					for f = 1 to newMesh.faces.count do
					(
						faceNorms = EN_getDegree f
						for d = 1 to faceNorms do
						(
							vert = EN_getVertexID f d
							norm = EN_getNormalID f d
							
							EN_setExplicit norm explicit:true
							EN_setNormal norm normals[vertOrigID[vert]]
						)
					)*/
					
					/*
					for i = 1 to nMNorms.GetNumNormals() do
					(
						-- make explicit
						nMNorms.SetNormalExplicit i explicit:true
						  
						-- set normal vector
						nMNorms.SetNormal i normals[vertOrigID[i]]
						print (nMNorms.GetNormal i)
					)*/
						
					update newMesh
					maxOps.CollapseNodeTo newMesh 1 true -- Collapse the Edit Normals modifier
					update newMesh
					
					-- Apply skin 
					if (PSO2Bones.checked and boneWeights.count > 0 and pso2BoneArray != undefined) then				
					(						
						count =  0
						Max modify mode
						Select newMesh
						skinMod = Skin()
						AddModifier newMesh skinMod
						
						--Apply Skinned Nodes 
						for i in bonePalGroups[k] do
						(
							tempB = ((i as integer) + 1)
							--SkinOps.AddBone (newMesh.modifiers[#skin]) (pso2BoneArray[tempt].MaxBone) 0
							SkinOps.AddBone skinMod (pso2BoneArray[tempB].MaxBone) 0
						)
						
						--print ("Group:" + k as string)
						-- Set the weight for each of them 
						ModPanel.SetCurrentObject skinMod
						
						--print newMesh.numverts
						for i = 1 to newMesh.numverts do 
						(
							skinOps.unNormalizeVertex skinMod i true
							skinOps.ReplaceVertexWeights skinMod i boneIds[vertOrigID[i]] boneWeights[vertOrigID[i]]
						)
							
						Max create mode
					) else (
						ConvertTo newMesh Editable_Poly
						if (PSO2Bones.checked and pso2BoneArray != undefined) then
						(
							Max modify mode
							Select newMesh
							skinMod = Skin()
							AddModifier newMesh skinMod
							if(pso2BoneArray.count >= groupNames.count) then
							(
								SkinOps.AddBone skinMod (pso2BoneArray[k].MaxBone) 0
							) else
							(
								SkinOps.AddBone skinMod (pso2BoneArray[1].MaxBone) 0
							)
							Max create mode
						)
					)
					
					--maxOps.CollapseNodeTo newMesh 1 true -- Collapse the Edit Normals modifier
					
					--polyop.deleteIsoVerts newMesh
					
					--Update mesh
					if(colorArray.count > 0) then
					(
						newMesh.showVertexColors = true 
					)
					update newMesh
					gc()
					print (groupNames[k] as string +"mesh imported!")
				)
				group importList name:fileGroupName
				print (fileGroupName as string +" file imported!")
			)
		)
	)
	
	on importButton pressed do
	(
		-- Open up a dialog box
		local objFileName = getOpenFileName caption:"Import VColor OBJ" \
					types:"Vertex Colored OBJ (*.obj)|*.obj|All Files (*.*)|*.*|"
		
		if (objFileName != undefined) then
		(
			importObject objFileName BonesByFN.checked
		)
		-- Redraw max viewports
		max views redraw
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
				GeoExport objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked playerModel.checked difWhite.checked unrmAvg.checked
			)
		)

	)

	on importPath pressed do
	(
		-- Open up a dialog box
		local objFileName = getOpenFileName caption:"Import VColor OBJ" \
					types:"Vertex Colored OBJ (*.obj)|*.obj|All Files (*.*)|*.*|"
		
		if objFileName != undefined then--if the user did not cancel
        (	
			thePath = getFilenamePath objFileName
			/*thePath = getSavePath()--get a path dialog to specify the path*/
			
          theFiles = getFiles (thePath+"\\*.obj") --collect all obj files in the dir.
		  for objFileName = theFiles do-- go through all of them
          (
			print objFileName
		    importObject objFileName true
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
			--SkelImport boneFileName prsVals.checked autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked KeepBoneIds.checked
			SkelImport boneFileName false autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked KeepBoneIds.checked
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
	
	on openAQMButton pressed do
	(
		FileIn @"PSO2AQM_IO_v1.5.ms"
	)
	
	on autoSizeCheckBox changed nowChecked do
	(
		autoSizeSpinner.enabled = nowChecked
	)
)
createDialog objImport 160 630
