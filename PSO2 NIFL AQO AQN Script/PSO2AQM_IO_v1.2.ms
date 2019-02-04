/*
PSO2 AQM I/O Script
By Shadowth117
Credit to TGE for help on debugging the script as well as for borrowed code from his Renderware animation importer
Credit to Hextator for helping analyze the format
*/

FileIn @"Include\MaxScriptExtensions\FileStreamReader.ms"
FileIn @"Include\MaxScriptExtensions\FileUtils.ms"

rollout tagRoll "PSO2 AQM I/O" 
(
Label lab2 "Please pick a PSO2 .aqm for your model"
button animImportPSO2 "Load PSO2 Anim" across:1 width:120 align:#center
button animExportPSO2 "Export PSO2 Anim" across:1 width:120 align:#center
--Label lab3 "Note: Anim Data is not fully reset because of node positionings." align:#left
--Label lab4 "Reload model before anim each time for best results." align:#left
checkBox loadClear "Clear Anim Data on Load" checked:true align:#left
checkBox yzFlip "Y-Z Flip Anim" checked:true align:#left
checkBox ignoreTranslate "Ignore Standard Translation keys (Use for non humanoid costumes)" checked:false align:#left
checkBox matchNames "Match bone names (Use for loading anims on wrong model)"
checkBox autoSizeCheckBox "Use Base Scale" checked:true align:#center
spinner autoSizeSpinner "Base Scale" align:#center type:#float range:[0,10000,100] enabled:false
Label lab5 "If a player costume has elevated feet, select this" align:#left
Label lab6	"before loading animations:" align:#left
checkBox heelCheck "Heeled outfit?" checked:false align:#left
spinner heelSpinner "Heel Height" align:#center type:#float range:[-100,100,0] enabled:false
checkBox debug "Debug Output" checked:false align:#left
Label lab7 "Export Settings:" align:#center
checkbox plExport "Player Export" checked:false align:#left
checkbox castExport "Cast Export (PlayerExport must be checked)" checked:false align:#left	

	
--Node Structure
struct nodeStruct 
(
	nodeOffset,
	nodeName,
	nodeCounter,
	nodeType,
	transStructCount
)

--Node Anim Structure
struct nodeAnim
(
	nodeExpName,
	nodePosFrames,
	nodeRotFrames,
	nodeSclFrames,
	nodePosTimings,
	nodeRotTimings,
	nodeSclTimings
)

--Animation Clearer
fn ClearAnimations =
(
	for obj in objects do
	(
		DeleteKeys obj.controller #allkeys
		obj.assumeSkinPose()
	)
)

--Relative Position Getter
fn relativePosition obj keyTime =
(
	tfm = (at time keyTime obj.transform)
	if obj.Parent != undefined then
	(	
		print "This is used"
		--tfm *= (inverse (relativePosition obj.Parent keyTime)) 
		tfm *= (inverse (at time keyTime obj.Parent.transform)) 
	)
	
	tfm
)

--Reader for frame timings
fn frameTimeRead frameTimeAddress frameCount reader =
(
	frameTime = #()

	--Check if this exists before doing it
	if(frameCount > 1) then
	(
		reader.SeekSet(frameTimeAddress + 0x20)
		for i = 1 to (frameCount) do
		(
			iTime = reader.ReadU16()
			frameTime[i] = iTime
		)
	) else (
		free frameTime
		frameTime = undefined
	)
	frameTime
)

fn loadPSO2Anim aqmFile =
(
	
	-- Read file
	local reader = FileStreamReader()
	reader.SetFile aqmFile false
	reader.SetBigEndian false
	
	--debug
	if (debug.checked == true) then
	(
		startPath = getFilenamePath(getThisScriptFilename())
		makeDir (startPath + "\debug")
		f = createFile (startPath + "\debug" + "\PSO2AnimName.txt") 
		print (aqmFile as string) to:f-- output buffer as a string literal
		flush f
		close f
	)
		
	deiceCheck = reader.ReadFixedLengthString 0x3
	--Check if we're reading a deiced or ICE(.ice)????? (repacker) .aqn
	if (deiceCheck == "aqm" or deiceCheck == "trm") then
	(
		header = 0x60
	) else
	(
		header = 0x0
	)
	
	reader.SeekSet( 0x44 + header )
	nodeCount = reader.ReadU32() + 1
	
	local nodeDataArray = #()
	
	--Read bone data
	for i = 1 to nodeCount do
	(
		--Read differently for test node
		if ( i > 1 ) then
		(
			nodeType = reader.ReadU32()
			transStructCount = reader.ReadU32()
		)
		else
		(
			nodeType = undefined
			transStructCount = undefined
		)
		nodeOffset = reader.ReadU32() + 0x20
		nodeName = reader.ReadFixedLengthString 0x20
		nodeCounter = reader.ReadU32()
		append nodeDataArray (nodeStruct nodeOffset:nodeOffset nodeName:nodeName nodeCounter:nodeCounter nodeType:nodeType transStructCount:transStructCount )
		
		--debug output
		if (debug.checked == true) then
		(
			f = createFile (startPath + "\debug" + "\PSO2bone_node" + i as string + ".txt") 
			format "$%\n" nodeDataArray[i] to:f-- output name in a pathname form
			print ("NodeOutput") to:f-- output buffer as a string literal
			flush f
			close f
		)

	)
	print "node data read"
	
	--Handle first node
	reader.SeekCur( 0x0C )
	local nodeAnimArray = #()
	
	--Read bone anim data
	for i = 1 to nodeDataArray.count do
	(
		--Don't bother with test node
		if ( i > 1 ) then
		(
			reader.SeekSet( nodeDataArray[i].nodeOffset + header )
			reader.SeekCur( 0xC )
			posFrameTime = #()
			posFrames = #()
			rotFrameTime = #()
			rotFrames = #()
			sclFrameTime = #()
			sclFrames = #()
			
			--Read addresses and info
			posFrameCount = reader.ReadU32()
			posAddress = reader.ReadU32()
			posTimeAddress = reader.ReadU32()
			if (nodeDataArray[i].transStructCount > 1 ) then
			(
				reader.SeekCur( 0xC )
				rotFrameCount = reader.ReadU32()
				rotAddress = reader.ReadU32()
				rotTimeAddress = reader.ReadU32()
				if (nodeDataArray[i].transStructCount > 2 ) then
				(
					reader.SeekCur( 0xC )
					sclFrameCount = reader.ReadU32()
					sclAddress = reader.ReadU32()
					sclTimeAddress = reader.ReadU32()
				)
			)
			
			--Read Position frame timings if valid
			posFrameTime = frameTimeRead posTimeAddress posFrameCount reader 
			
			reader.SeekSet(posAddress + 0x20)
			--NodeTreeflag check
			if (nodeDataArray[i].nodeType == 0x10) then
			(
				for l = 1 to (posFrameCount) do
				(
					posFrame = reader.ReadU32()
					append posFrames posFrame
				)
			) else
			(
				--Read Position frames
				for l = 1 to (posFrameCount) do
				(
					posFrame = [ reader.ReadF32(), reader.ReadF32(), reader.ReadF32() ]
					reader.SeekCur( 0x4 )
					append posFrames posFrame
				)
			)
			--Check if there's rotation frames to read
			if ( nodeDataArray[i].transStructCount > 1 ) then
			(
				--Read Rotation frame timings if valid
				rotFrameTime = frameTimeRead rotTimeAddress rotFrameCount reader 

				reader.SeekSet(rotAddress + 0x20)
				--NodeTreeflag check
				if (nodeDataArray[i].nodeType == 0x10) then
				(
					for l = 1 to (rotFrameCount) do
					(
						rotFrame = reader.ReadU32()
						append rotFrames rotFrame
					)
				) else
				(
					--Read Rotation frames
					for l = 1 to (rotFrameCount) do
					(
						x = reader.ReadF32()
						y = reader.ReadF32()
						z = reader.ReadF32()
						w = reader.ReadF32()
						rotFrame = ( quat x y z w )
						append rotFrames rotFrame
					)
				)
			)
			else
			(
				rotFrameTime = undefined
				rotFrames = undefined
			)
			
			--Check if there's scale frames to read
			if ( nodeDataArray[i].transStructCount > 2 ) then
			(
				--Read Scale frame timings if valid
				sclFrameTime = frameTimeRead sclTimeAddress sclFrameCount reader 
				
				reader.SeekSet(sclAddress + 0x20)
				--NodeTreeflag check
				if (nodeDataArray[i].nodeType == 0x10) then
				(
					for l = 1 to (sclFrameCount) do
					(
						sclFrame = reader.ReadU32()
						append sclFrames sclFrame
					)
				) else
				(
					--Read Scale frames
					for l = 1 to (sclFrameCount) do
					(
						sclFrame = [ reader.ReadF32(), reader.ReadF32(), reader.ReadF32() ]
						reader.SeekCur( 0x4 )
						append sclFrames sclFrame
					)
				)
			)
			else
			(
				sclFrameTime = undefined
				sclFrames = undefined
			)
			append nodeAnimArray (nodeAnim nodePosFrames:posFrames nodeRotFrames:rotFrames nodeSclFrames:sclFrames nodePosTimings:posFrameTime nodeRotTimings:rotFrameTime nodeSclTimings:sclFrameTime)
			
			--debug output
			if (debug.checked == true) then
			(
				 f = createFile (startPath + "\debug" + "\PSO2anim_node" + i as string + ".txt") 

				format "$%\n" nodeDataArray[i] to:f-- output name in a pathname form
				format "$%\n" nodeAnimArray[i] to:f-- output name in a pathname form
				print ("NodeOutput") to:f-- output buffer as a string literal
				flush f
				close f
			)
			
		) else 
		(
			append nodeAnimArray undefined
		)
		gc()
		
	)
	
	print "anim data read"
	reader.Close()
	
	--Gather bone references
	sceneBones = #()
	if (matchNames.checked == true) then
	(
		--Set root here to avoid mismatching it later
		for o in objects do
		(
			if (findstring o.name "(0)" != undefined) then
			(
				scenebones[1] = o
			)
		)
		--Search through after test and root node data
		for i = 3 to nodeDataArray.count do
		(
			for o in objects where classOf o == Biped_Object or classOf o == BoneGeometry or (try(classOf o.transform.controller == BipSlave_Control)catch(false)) do
			(
				if (findstring o.name ")" != undefined) then
			    (
					if ((substring (filterstring o.name ")")[2] 1 nodeDataArray[i].nodeName.count) == nodeDataArray[i].nodeName) then
					(
						sceneBones[i] = o
					)
				)
			)
		)
	)
	else
	(
		for o in objects where classOf o == Biped_Object or classOf o == BoneGeometry or (try(classOf o.transform.controller == BipSlave_Control)catch(false)) do
		(
			if (findstring o.name ")" != undefined) then
			(
				id = (filterstring o.name "()")[1]
				sceneBones[( (id as integer) + 1)] = o
			)
		)
	)
	
	print "scene bones assigned"
	
			--debug output
			if (debug.checked == true) then
			(
				 f = createFile (startPath + "\debug" + "\PSO2animSceneBonesAssigned.txt") 
				print ("scene bones assigned") to:f-- output buffer as a string literal
				flush f
				close f
			)
	
	--Get time of last frame
	animTime = undefined
	j = 1
	while (animTime == undefined) do
	(
		--Catch if there's no timing for w/e reason
		if(j > nodeAnimArray.count) then
		(
			animTime = 0x10
		)
		else if(nodeAnimArray[j] != undefined) then
		(
			if (nodeAnimArray[j].nodePosTimings != undefined) then
			(
				timeCheck = nodeAnimArray[j].nodePosTimings[nodeAnimArray[j].nodePosTimings.count]
				if (timeCheck != undefined) then
				(
					animTime = timeCheck
				)
			)
			if (nodeAnimArray[j].nodeRotTimings != undefined) then
			(
				timeCheck = nodeAnimArray[j].nodeRotTimings[nodeAnimArray[j].nodeRotTimings.count]
				if (timeCheck != undefined and animTime == undefined) then
				(
					animTime = timeCheck
				)
			)
			if (nodeAnimArray[j].nodeSclTimings != undefined) then
			(
				timeCheck = nodeAnimArray[j].nodeSclTimings[nodeAnimArray[j].nodeSclTimings.count]
				if (timeCheck != undefined and animTime == undefined) then
				(
					animTime = timeCheck
				)
			)
		)
		j += 1
	)
			--debug output
			if (debug.checked == true) then
			(
				 f = createFile (startPath + "\debug" + "\PSO2animTimeFound.txt")
				print (animTime as string) to:f-- output buffer as a string literal
				flush f
				close f
			)
	
	animationRange = interval 0 (animTime / 0x10)
	
	--Value to scale anim values by
	scaleVal = 1
	if ( autoSizeCheckBox.checked == true) then
	(
		scaleVal = autoSizeSpinner.value
	) 
	
	animButtonState = true

	--Assign anims
	for i = 1 to nodeCount do
	(
		if(nodeAnimArray[i] != undefined and nodeDataArray[i].nodeType != 0x10) then
		(
			--pso2Bone = "(" + ((i - 2) as string) + ")" + nodeDataArray[i].nodeName
			--pso2BoneRef = getNodeByName pso2Bone
			pso2Bone = sceneBones[i-1]
			
			--Check to make sure this is a valid bone (mainly for Match Bone Names option)
			if(pso2Bone != undefined) then
			(
				
				baseScale = pso2Bone.scale
				heelVal = 0
				if (i == 3 and heelCheck.checked == true) then
				(
					heelVal = heelSpinner.value
				) 
				--time by frameTime/10
				--Position
				if (nodeAnimArray[i].nodePosTimings != undefined and (ignoreTranslate.checked == false or i == 2)) then
				(
					for k = 1 to nodeAnimArray[i].nodePosFrames.count do
					(
						PosFrameData = nodeAnimArray[i].nodePosFrames[k]
						at time (nodeAnimArray[i].nodePosTimings[k] / 0x10) pso2Bone.Controller.Position = ([ PosFrameData.x * scaleVal, (PosFrameData.y * scaleVal) + heelVal, PosFrameData.z * scaleVal ])
					)
				) else if (ignoreTranslate.checked == false or i == 2) then
				(
					PosFrameData = nodeAnimArray[i].nodePosFrames[1]
					at time 0 pso2Bone.Controller.Position = ([ PosFrameData.x * scaleVal, (PosFrameData.y * scaleVal) + heelVal, PosFrameData.z * scaleVal ])
				)
				--Rotation
				if (nodeAnimArray[i].nodeRotTimings != undefined) then
				(
					for k = 1 to nodeAnimArray[i].nodeRotFrames.count do
					(
						at time (nodeAnimArray[i].nodeRotTimings[k] / 0x10) pso2Bone.Controller.Rotation = (inverse nodeAnimArray[i].nodeRotFrames[k])
					)
				) else
				(
					at time 0 pso2Bone.Controller.Rotation = nodeAnimArray[i].nodeRotFrames[1]
				)
				--Scale 
				if (nodeAnimArray[i].nodeSclTimings != undefined) then
				(
					for k = 1 to nodeAnimArray[i].nodeSclFrames.count do
					(
						SclFrameData = nodeAnimArray[i].nodeSclFrames[k]
						at time (nodeAnimArray[i].nodeSclTimings[k] / 0x10) pso2Bone.Controller.Scale = ([ SclFrameData.x, SclFrameData.y, SclFrameData.z])
					)
				) else
				(
					SclFrameData = nodeAnimArray[i].nodeSclFrames[1]
					at time 0 pso2Bone.Controller.Scale = ([ SclFrameData.x, SclFrameData.y, SclFrameData.z ])
				) 
			)
		)
		
			--debug output
			if (debug.checked == true) then
			(
				 f = createFile (startPath + "\debug" + "\PSO2motionSuccess_" + i as string + ".txt") 
				print ("NodeOutput") to:f-- output buffer as a string literal
				flush f
				close f
			)
		
	)
	
	animButtonState = false
	
	print "frames assigned"
	
	--Rotate if desired (probably desired)
	if (yzFlip.checked == true) then
	(
		rotDummy = dummy pos: ( [0, 0, 0] ) name: ( "rotationDummy")
		sceneBones[1].Parent = rotDummy
		Rotate rotDummy (eulerAngles 90 0 0)
		delete rotDummy
	)
	gc()
)

fn exportPSO2Anim aqmFile =
(
	
	boneParams = #()
	byOrder = true
	nodeThree = false
	playerExport = plExport.checked
	/*
	if (nodeThree.checked == true) then
	(
		nodeThree = true
	)
	*/
	
	--Read scene data
	--Check if we're going by order or by pso2 bone order
	scenebones = #()
	for o in objects where classOf o == Biped_Object or classOf o == BoneGeometry or (try(classOf o.transform.controller == BipSlave_Control)catch(false)) do
	(
		
		boneCheck = findString (o.name) "("
		if (boneCheck == 1) then
		(
			byOrder = false
		)
		if (findstring o.name "(0)" != undefined) then
		(
			scenebones[1] = o
		)
	)
	
	--Rotate if desired (probably desired)
	if (yzFlip.checked == true) then
	(
		print "flip"
		rotDummy = dummy pos: ( [0, 0, 0] ) name: ( "rotationDummy")
		sceneBones[1].Parent = rotDummy
		Rotate rotDummy (eulerAngles -90 0 0)
		delete rotDummy
	)
	
	--Loop through objects and gather their keyframes
	for o in objects where classOf o == Biped_Object or classOf o == BoneGeometry or (try(classOf o.transform.controller == BipSlave_Control)catch(false)) do
	(
		
		boneName = o.name
		posFrames = #()
		posTimes = #()
		rotFrames = #()
		rotTimes = #()
		sclFrames = #()
		sclTimes = #()
		
		if (o.position.controller.keys.count > 0) then
		(
			for itemKey in o.position.controller.keys do 
			(
				posKeyTime = (itemKey.Time as integer)
				--posKeyValue = (at time itemKey.Time o.Controller.Position)
				posKeyValue = ((relativePosition o itemKey.Time).translationpart)
				append posTimes (posKeyTime / 160)
				append posFrames PosKeyValue
			)
		) else
		(
			posKeyValue = o.pos
			posKeyValue = ((relativePosition o 0).translationpart)
			append posFrames posKeyValue
		)
		
		
		--Only store keys if it has them
		if (o.rotation.controller.keys.count > 0) then
		(
			for itemKey in o.rotation.controller.keys do 
			(
				rotKeyTime = (itemKey.Time as integer)
				--rotKeyValue = (at time itemKey.Time (o.Controller.Rotation))
				rotKeyValue = (at time itemKey.Time (o.rotation.controller.value))
				rotKeyValue = (inverse rotKeyValue)
				append rotTimes (rotKeyTime / 160)
				append rotFrames rotKeyValue
			)
		) else
		(
			append rotFrames (inverse o.rotation)
		)
		
		--Only store keys if it has them
		if (o.scale.controller.keys.count > 0) then
		(
			for itemKey in o.scale.controller.keys do 
			(
				sclKeyTime = (itemKey.Time as integer)
				sclKeyValue = (at time itemKey.Time o.Controller.Scale)
				append sclTimes (sclKeyTime / 160)
				append sclFrames sclKeyValue
			)
		) else
		(
			append sclFrames o.scale
		)
		
		--Check how nodes should be added
		if (byOrder == true) then
		(
			append boneParams (nodeAnim nodeExpName:boneName nodePosFrames:posFrames nodeRotFrames:rotFrames nodeSclFrames:sclFrames nodePosTimings:posTimes nodeRotTimings:rotTimes nodeSclTimings:sclTimes)
		)
		else
		(
			id = (filterstring o.name "()")[1]
			boneParams[((id as integer) + 1)] = (nodeAnim nodeExpName:boneName nodePosFrames:posFrames nodeRotFrames:rotFrames nodeSclFrames:sclFrames nodePosTimings:posTimes nodeRotTimings:rotTimes nodeSclTimings:sclTimes)
		)
	)
	
	-- If this is a player animation, export with the __NodeTreeFlag__ "bone"
	extraBone = 0
	if (playerExport == true) then
	(
		extraBone = 1
	)
	pso2Anim = fopen aqmFile "wb"
	
	--NIFL Header
	--should be populated later with a few values once the final is finished writing almost
	WriteString pso2Anim "NIFL"
	fseek pso2Anim (-1) #seek_cur
	WriteLong  pso2Anim 0x18 -- offset to a u32 that is some length of something? Always seems to be 0x18
	WriteLong  pso2Anim 1 -- Just 1
	WriteLong  pso2Anim 0x20 -- REL0 offset
	nofMinus20Add = (ftell pso2Anim)
	WriteLong  pso2Anim 0 --NOF0 offset - 0x20?
	nofAdd = (ftell pso2Anim)
	WriteLong  pso2Anim 0 --NOF0 offset
	nofSizeAdd = (ftell pso2Anim)
	WriteLong  pso2Anim 0 --Size of NOF0 block
	WriteLong  pso2Anim 0 --Padding
	-----------------------------------------------------------------
	
	--REL0 Struct
	WriteString pso2Anim "REL0"
	fseek pso2Anim (-1) #seek_cur
	relSizeAdd = (ftell pso2Anim)
	WriteLong pso2Anim 0 --Size of REL0 
	WriteLong pso2Anim 0x10 --Just 0x10
	WriteLong pso2Anim 0 -- Just 0
	if (playerExport == true) then
	(
		WriteShort pso2Anim 0x12 -- u16 Usuually 0x12 for players, 0x2 for everything else
	) else
	(
		WriteShort pso2Anim 0x2 -- u16 Usuually 0x12 for players, 0x2 for everything else
	)
	WriteShort pso2Anim 0x1 -- u16 Usually 1
	WriteLong pso2Anim 0 -- Loop point? Only seen different in Persona live dance aqms and lower than the anim range. 0 otherwise
	WriteLong pso2Anim animationRange.end -- animation range (0 based)
	WriteFloat pso2Anim 30.0 -- f32 (usually 30.0f) FPS?
	WriteLong pso2Anim 2 -- Just 2
	WriteLong pso2Anim (boneParams.count + extraBone) -- BoneCount, minus test
	testAddress = (ftell pso2Anim)
	WriteLong pso2Anim 0x50 -- usually 0x50
	WriteString pso2Anim "test"
	fseek pso2Anim (-1) #seek_cur
	WriteLongLong pso2Anim 0 -- 0
	WriteLongLong pso2Anim 0 -- 0
	WriteLongLong pso2Anim 0 -- 0
	WriteLongLong pso2Anim 0 -- 0
	-----------------------------------------------------------------
	--BoneData
	boneOffAddress = #()
	for i = 1 to boneParams.count do
	(
		WriteLong pso2Anim 2 -- NodeType Bone: Just 2
		WriteLong pso2Anim 3 -- NodeDataSet count: Just 3
		append boneOffAddress (ftell pso2Anim) -- record address to come back to later
		WriteLong pso2Anim 0 -- Offset for anim data
		--Handle name string
		boneName = substring boneParams[i].nodeExpName 1 21 -- avoid going over
		if ((filterstring boneName ")").count > 1) then
		(
			boneName = (filterstring boneName ")")[2]
		)
		extraSpace = 0x20 - (boneName.count) --calculate space left to 20 (if any)
		WriteString pso2Anim boneName -- name
		fseek pso2Anim (-1) #seek_cur
		for e = 1 to extraSpace do -- add padding to reach 0x20 if needed
		(
			writeByte pso2Anim 0x0
		)
		WriteLong pso2Anim (i - 1) -- Bone id
	)
	
	--NodeTreeFlag
	if (playerExport == true) then
	(
		WriteLong pso2Anim 0x10 -- NodeType NodeTree: Just 0x10
		dataCount = 2
		if (nodeThree == true) then -- Datacount for nodetree (find a way to automate?)
		(
			dataCount += 1
		)
		WriteLong pso2Anim dataCount -- NodeDataSet count: 2 or 3
		append boneOffAddress (ftell pso2Anim) -- record address to come back to later
		WriteLong pso2Anim 0 -- Offset for anim data
		WriteString pso2Anim "__NodeTreeFlag__"
		fseek pso2Anim (-1) #seek_cur
		WriteLong pso2Anim 0 -- 0
		WriteLongLong pso2Anim 0 -- 0
		WriteLongLong pso2Anim 0 -- 0
	)
	
	--Arrays to store addresses we'll go back to
	animParamAddresses = #()
	animKeyTimeAddress = #()
	
	bookMark = undefined
	--BoneAnims
	for i = 1 to boneParams.count do
	(
		--Write bone address and continue
		bookMark = (ftell pso2Anim)
		fseek pso2Anim boneOffAddress[i] #seek_set
		WriteLong pso2Anim (bookMark - 0x20)
		fseek pso2Anim bookMark #seek_set
		
		--Position area
		WriteLong pso2Anim 0x01 -- NodeType NodeTree: Just 0x10
		WriteLong pso2Anim 0x01 -- Struct Type NodeBitFlag: 0x05
		WriteLong pso2Anim 0 --  0
		WriteLong pso2Anim boneParams[i].nodePosFrames.count -- Number of frames for struct (all frames are used for nodetreeflag)
		posAdd = (ftell pso2Anim)
		append animKeyTimeAddress posAdd
		WriteLong pso2Anim 0 -- position frame address, change later
		posTimeAdd = (ftell pso2Anim)
		if (boneParams[i].nodePosFrames.count > 1) then
		(
			append animKeyTimeAddress posTimeAdd -- Only add if more than 1 frame
		)
		WriteLong pso2Anim 0 -- position time address, change later if more than 1 frame
		--Rotation area
		WriteLong pso2Anim 0x02 -- NodeType NodeTree part 2: Just 0x11
		WriteLong pso2Anim 0x03 -- Struct Type NodeBitFlag: 0x05
		WriteLong pso2Anim 0 -- 0
		WriteLong pso2Anim boneParams[i].nodeRotFrames.count -- Number of frames for struct (all frames are used for nodetreeflag)
		rotAdd = (ftell pso2Anim)
		append animKeyTimeAddress rotAdd
		WriteLong pso2Anim 0 -- rotation frame address, change later
		rotTimeAdd = (ftell pso2Anim)
		if (boneParams[i].nodeRotFrames.count > 1) then
		(
			append animKeyTimeAddress rotTimeAdd -- Only add if more than 1 frame
		)
		WriteLong pso2Anim 0 -- rotation time address, change later if more than 1 frame
		--Scale area, sometimes not used. Usually only unused entirely for nodetreeflag
		WriteLong pso2Anim 0x03 -- NodeType Nodetree part 3: Just 0x12
		WriteLong pso2Anim 0x01 -- Struct Type NodeBitFlag: 0x05
		WriteLong pso2Anim 0 -- 0
		WriteLong pso2Anim boneParams[i].nodeSclFrames.count -- Number of frames for struct (all frames are used for nodetreeflag)
		sclAdd = (ftell pso2Anim)
		append animKeyTimeAddress sclAdd
		WriteLong pso2Anim 0 -- scale frame address, change later
		sclTimeAdd = (ftell pso2Anim)
		if (boneParams[i].nodeSclFrames.count > 1) then
		(
			append animKeyTimeAddress sclTimeAdd -- Only add if more than 1 frame
		)
		WriteLong pso2Anim 0 -- scale time address, change later if more than 1 frame
		WriteLongLong pso2Anim 0 -- 0 padding
		
		append animParamAddresses (nodeAnim nodeExpName:i nodePosFrames:posAdd nodeRotFrames:rotAdd nodeSclFrames:sclAdd nodePosTimings:posTimeAdd nodeRotTimings:rotTimeAdd nodeSclTimings:sclTimeAdd)
		
		--Value to scale anim values by
		scaleVal = 1
		if ( autoSizeCheckBox.checked == true) then
		(
			scaleVal = autoSizeSpinner.value
		) 
			
		
		--Write Pos Timings (if > 1)
		if (boneParams[i].nodePosFrames.count > 1) then
		(
			--Write pos timing address and continue
			bookMark = (ftell pso2Anim)
			fseek pso2Anim animParamAddresses[i].nodePosTimings #seek_set
			WriteLong pso2Anim (bookMark - 0x20)
			fseek pso2Anim bookMark #seek_set
			
			for j = 1 to boneParams[i].nodePosTimings.count do
			(	
				if(j == 1) then
				(
					WriteShort pso2Anim 0x01
				) else if (j == boneParams[i].nodePosTimings.count) then
				(
					WriteShort pso2Anim ((boneParams[i].nodePosTimings[j] * 0x10) + 0x02)
				)
				else
				(
					WriteShort pso2Anim (boneParams[i].nodePosTimings[j] * 0x10)
				)
			)
			--Pad to end of line
			while ( (mod (ftell pso2Anim) 0x10) != 0) do
			(
				WriteByte pso2Anim 0 --Write padding
			)
		)
		--Write Pos Data
		
		--Write pos address and continue
		bookMark = (ftell pso2Anim)
		fseek pso2Anim animParamAddresses[i].nodePosFrames #seek_set
		WriteLong pso2Anim (bookMark - 0x20)
		fseek pso2Anim bookMark #seek_set
		
		for j = 1 to boneParams[i].nodePosFrames.count do
		(
			WriteFloat pso2Anim (boneParams[i].nodePosFrames[j].x / scaleVal)
			WriteFloat pso2Anim (boneParams[i].nodePosFrames[j].y / scaleVal)
			WriteFloat pso2Anim (boneParams[i].nodePosFrames[j].z / scaleVal)
			WriteLong pso2Anim 0 
		)
		--Write Rot Timing (if > 1)
		if (boneParams[i].nodeRotFrames.count > 1) then
		(
			
			--Write rot timing address and continue
			bookMark = (ftell pso2Anim)
			fseek pso2Anim animParamAddresses[i].nodeRotTimings #seek_set
			WriteLong pso2Anim (bookMark - 0x20)
			fseek pso2Anim bookMark #seek_set
			
			for j = 1 to boneParams[i].nodeRotTimings.count do
			(	
				if(j == 1) then
				(
					WriteShort pso2Anim 0x01
				) else if (j == boneParams[i].nodeRotTimings.count) then
				(
					WriteShort pso2Anim ((boneParams[i].nodeRotTimings[j] * 0x10) + 0x02)
				)
				else
				(
					WriteShort pso2Anim (boneParams[i].nodeRotTimings[j] * 0x10)
				)
			)
			--Pad to end of line
			while ( (mod (ftell pso2Anim) 0x10) != 0) do
			(
				WriteByte pso2Anim 0 --Write padding
			)
		)
		--Write Rot Data
		
		--Write rot address and continue
		bookMark = (ftell pso2Anim)
		fseek pso2Anim animParamAddresses[i].nodeRotFrames #seek_set
		WriteLong pso2Anim (bookMark - 0x20)
		fseek pso2Anim bookMark #seek_set
		
		for j = 1 to boneParams[i].nodeRotFrames.count do
		(
			WriteFloat pso2Anim boneParams[i].nodeRotFrames[j].x
			WriteFloat pso2Anim boneParams[i].nodeRotFrames[j].y
			WriteFloat pso2Anim boneParams[i].nodeRotFrames[j].z
			WriteFloat pso2Anim boneParams[i].nodeRotFrames[j].w
		)
		--Write Scale Timing (if > 1)
		if (boneParams[i].nodeSclFrames.count > 1) then
		(
			
			--Write scl timing address and continue
			bookMark = (ftell pso2Anim)
			fseek pso2Anim animParamAddresses[i].nodeSclTimings #seek_set
			WriteLong pso2Anim (bookMark - 0x20)
			fseek pso2Anim bookMark #seek_set
			
			for j = 1 to boneParams[i].nodeSclTimings.count do
			(	
				if(j == 1) then
				(
					WriteShort pso2Anim 0x01
				) else if (j == boneParams[i].nodeSclTimings.count) then
				(
					WriteShort pso2Anim ((boneParams[i].nodeSclTimings[j] * 0x10) + 0x02)
				)
				else
				(
					WriteShort pso2Anim (boneParams[i].nodeSclTimings[j] * 0x10)
				)
			)
			--Pad to end of line
			while ( (mod (ftell pso2Anim) 0x10) != 0) do
			(
				WriteByte pso2Anim 0 --Write padding
			)
		)
		
		--Write Scale Data
		
		--Write scl address and continue
		bookMark = (ftell pso2Anim)
		fseek pso2Anim animParamAddresses[i].nodeSclFrames #seek_set
		WriteLong pso2Anim (bookMark - 0x20)
		fseek pso2Anim bookMark #seek_set
		
		for j = 1 to boneParams[i].nodeSclFrames.count do
		(
			WriteFloat pso2Anim boneParams[i].nodeSclFrames[j].x
			WriteFloat pso2Anim boneParams[i].nodeSclFrames[j].y
			WriteFloat pso2Anim boneParams[i].nodeSclFrames[j].z
			WriteLong pso2Anim 0 
		)
	)
	
	--NodeTreeFlag "anim"
	if (playerExport == true) then
	(
		--Write bone address and continue
		bookMark = (ftell pso2Anim)
		fseek pso2Anim boneOffAddress[boneOffAddress.count] #seek_set
		WriteLong pso2Anim (bookMark - 0x20)
		fseek pso2Anim bookMark #seek_set
		
		--Position area
		WriteLong pso2Anim 0x10 -- NodeType NodeTree: Just 0x10
		WriteLong pso2Anim 0x05 -- Struct Type NodeBitFlag: 0x05
		WriteLong pso2Anim 0 --  0
		WriteLong pso2Anim (animationRange.end + 1) -- Number of frames for struct (all frames are used for nodetreeflag)
		posAdd = (ftell pso2Anim)
		append animKeyTimeAddress posAdd
		WriteLong pso2Anim 0 -- position frame address, change later
		posTimeAdd = (ftell pso2Anim)
		if (animationRange.end > 1) then
		(
			append animKeyTimeAddress posTimeAdd -- Only add if more than 1 frame
		)
		WriteLong pso2Anim 0 -- position time address, change later if more than 1 frame
		--Rotation area
		WriteLong pso2Anim 0x11 -- NodeType NodeTree part 2: Just 0x11
		WriteLong pso2Anim 0x05 -- Struct Type NodeBitFlag: 0x05
		WriteLong pso2Anim 0 -- 0
		WriteLong pso2Anim (animationRange.end + 1) -- Number of frames for struct (all frames are used for nodetreeflag)
		rotAdd = (ftell pso2Anim)
		append animKeyTimeAddress rotAdd
		WriteLong pso2Anim 0 -- rotation frame address, change later
		rotTimeAdd = (ftell pso2Anim)
		if (animationRange.end > 1) then
		(
			append animKeyTimeAddress rotTimeAdd -- Only add if more than 1 frame
		)
		WriteLong pso2Anim 0 -- rotation time address, change later if more than 1 frame
		
		sclAdd = undefined
		sclTimeAdd = undefined
		--Scale area, sometimes not used. Usually only unused entirely for nodetreeflag
		if (dataCount > 2) then
		(
			WriteLong pso2Anim 0x12 -- NodeType Nodetree part 3: Just 0x12
			WriteLong pso2Anim 0x05 -- Struct Type NodeBitFlag: 0x05
			WriteLong pso2Anim 0 -- 0
			WriteLong pso2Anim (animationRange.end + 1) -- Number of frames for struct (all frames are used for nodetreeflag)
			sclAdd = (ftell pso2Anim)
			append animKeyTimeAddress sclAdd
			WriteLong pso2Anim 0 -- scale frame address, change later
			sclTimeAdd = (ftell pso2Anim)
			if (animationRange.end > 1) then
			(
				append animKeyTimeAddress sclTimeAdd -- Only add if more than 1 frame
			)
			WriteLong pso2Anim 0 -- scale time address, change later if more than 1 frame
			WriteLongLong pso2Anim 0 -- 0 padding
		)
		
		append  animParamAddresses (nodeAnim nodeExpName:"NodeTreeFlag" nodePosFrames:posAdd nodeRotFrames:rotAdd nodeSclFrames:sclAdd nodePosTimings:posTimeAdd nodeRotTimings:rotTimeAdd nodeSclTimings:sclTimeAdd )
		
		parCount = animParamAddresses.count
		
		--Write Pos Timings (if > 1)
		if (animationRange.end > 1) then
		(
			--Write pos timing address and continue
			bookMark = (ftell pso2Anim)
			fseek pso2Anim animParamAddresses[parCount].nodePosTimings #seek_set
			WriteLong pso2Anim (bookMark - 0x20)
			fseek pso2Anim bookMark #seek_set
			
			for j = 1 to (animationRange.end + 1) do -- All NodeTreeFlag timings have 0x08 added onto what they would normally be
			(	
				if(j == 1) then
				(
					WriteShort pso2Anim 0x09
				) else if (j == (animationRange.end + 1)) then
				(
					WriteShort pso2Anim (((j - 1) * 0x10) + 0x0A)
				)
				else
				(
					WriteShort pso2Anim (((j - 1) * 0x10) + 0x08)
				)
			)
			--Pad to end of line
			while ( (mod (ftell pso2Anim) 0x10) != 0) do
			(
				WriteByte pso2Anim 0 --Write padding
			)
		)
		--Write Pos Data
		
		--Write pos address and continue
		bookMark = (ftell pso2Anim)
		fseek pso2Anim animParamAddresses[parCount].nodePosFrames #seek_set
		WriteLong pso2Anim (bookMark - 0x20)
		fseek pso2Anim bookMark #seek_set
		
		nodeTreeFirst = 0x31 -- Fleshy nodetreeflag
		if (castExport.checked == true) then
		(
			nodeTreeFirst = 0x2F
		)
		if (animationRange.end > 1) then
		(
			for j = 1 to (animationRange.end + 1) do 
			(	
				WriteLong pso2Anim nodeTreeFirst
			)
			--Pad to end of line
			while ( (mod (ftell pso2Anim) 0x10) != 0) do
			(
				WriteByte pso2Anim 0 --Write padding
			)
		)
		--Write Rot Timing (if > 1)
		if (animationRange.end > 1) then
		(
			--Write rot timing address and continue
			bookMark = (ftell pso2Anim)
			fseek pso2Anim animParamAddresses[parCount].nodeRotTimings #seek_set
			WriteLong pso2Anim (bookMark - 0x20)
			fseek pso2Anim bookMark #seek_set
			
			for j = 1 to (animationRange.end + 1) do -- All NodeTreeFlag timings have 0x08 added onto what they would normally be
			(	
				if(j == 1) then
				(
					WriteShort pso2Anim 0x09
				) else if (j == (animationRange.end + 1)) then
				(
					WriteShort pso2Anim (((j - 1) * 0x10) + 0x0A)
				)
				else
				(
					WriteShort pso2Anim (((j - 1) * 0x10) + 0x08)
				)
			)
			--Pad to end of line
			while ( (mod (ftell pso2Anim) 0x10) != 0) do
			(
				WriteByte pso2Anim 0 --Write padding
			)
		)
		--Write Rot Data 
		
		--Write rot address and continue
		bookMark = (ftell pso2Anim)
		fseek pso2Anim animParamAddresses[parCount].nodeRotFrames #seek_set
		WriteLong pso2Anim (bookMark - 0x20)
		fseek pso2Anim bookMark #seek_set
		
		nodeTreeSecond = 0x31 -- Fleshy nodetreeflag
		if (castExport.checked == true) then
		(
			nodeTreeSecond = 0x2F
		)
		if (animationRange.end > 1) then
		(
			for j = 1 to (animationRange.end + 1) do 
			(	
				WriteLong pso2Anim nodeTreeSecond
			)
			--Pad to end of line
			while ( (mod (ftell pso2Anim) 0x10) != 0) do
			(
				WriteByte pso2Anim 0 --Write padding
			)
		)
		
		if (dataCount > 2) then
		(
			--Write Scale Timing (if > 1)
			if (animationRange.end > 1) then
			(
				--Write scl timing address and continue
				bookMark = (ftell pso2Anim)
				fseek pso2Anim animParamAddresses[parCount].nodeSclTimings #seek_set
				WriteLong pso2Anim (bookMark - 0x20)
				fseek pso2Anim bookMark #seek_set
				
				for j = 1 to (animationRange.end + 1) do -- All NodeTreeFlag timings have 0x08 added onto what they would normally be
				(	
					if(j == 1) then
					(
						WriteShort pso2Anim 0x09
					) else if (j == (animationRange.end + 1)) then
					(
						WriteShort pso2Anim (((j - 1) * 0x10) + 0x0A)
					)
					else
					(
						WriteShort pso2Anim (((j - 1) * 0x10) + 0x08)
					)
				)
				--Pad to end of line
				while ( (mod (ftell pso2Anim) 0x10) != 0) do
				(
					WriteByte pso2Anim 0 --Write padding
				)
			)
			--Write Scale Data
			
			--Write scl address and continue
			bookMark = (ftell pso2Anim)
			fseek pso2Anim animParamAddresses[parCount].nodeSclFrames #seek_set
			WriteLong pso2Anim (bookMark - 0x20)
			fseek pso2Anim bookMark #seek_set
				
			nodeTreeThird = 0x31 -- Fleshy nodetreeflag
			if (castExport.checked == true) then
			(
				nodeTreeThird = 0x2F
			)
			if (animationRange.end > 1) then
			(
				for j = 1 to (animationRange.end + 1) do 
				(	
					WriteLong pso2Anim nodeTreeThird
				)
				--Pad to end of line
				while ( (mod (ftell pso2Anim) 0x10) != 0) do
				(
					WriteByte pso2Anim 0 --Write padding
				)
			)
		)
	)
	
	--Fill in addresses
	
	--NOF0
	nofBegin = (ftell pso2Anim) 
	WriteString pso2Anim "NOF0" -- NOF0
	fseek pso2Anim (-1) #seek_cur
	nofSizeNof = (ftell pso2Anim) 
	WriteLong pso2Anim 0 -- Size of NOF0, come back later
	WriteLong pso2Anim (1 + boneOffAddress.count + animKeyTimeAddress.count) --Number of addresses to list including test address
	WriteLong pso2Anim 0 -- 0
	WriteLong pso2Anim (testAddress - 0x20) -- Test Address

	for i = 1 to boneOffAddress.count do
	(
		WriteLong pso2Anim (boneOffAddress[i] - 0x20) -- Write bone offset addresses
	)
	for i = 1 to animKeyTimeAddress.count do
	(
		WriteLong pso2Anim (animKeyTimeAddress[i] - 0x20) -- Write bone offset addresses
	)
	nofDataSize = ((ftell pso2Anim) + 0x08) - nofBegin - 0x10
	
	while (mod (ftell pso2Anim) 0x10 != 0) do
	(
		WriteByte pso2Anim 0 --Write padding
	)
	nofTotalSize = (ftell pso2Anim) - nofBegin
	--NEND
	WriteString pso2Anim "NEND" -- NEND
	fseek pso2Anim (-1) #seek_cur
	WriteLong pso2Anim 8 -- Always 8
	WriteLongLong pso2Anim 0 -- 0
	
	-- Fill remaining addresses
	--    NIFL null addresses
	fseek pso2Anim nofMinus20Add #seek_set
	WriteLong pso2Anim (nofBegin - 0x20)
	WriteLong pso2Anim nofBegin
	WriteLong pso2Anim nofTotalSize
	--    REL0 null addresses
	fseek pso2Anim relSizeAdd #seek_set
	WriteLong pso2Anim (nofBegin - (relSizeAdd + 0x04))
	--    NOF0 null addresses
	fseek pso2Anim nofSizeNof #seek_set
	WriteLong pso2Anim nofDataSize
	
	fflush pso2Anim
	fclose pso2Anim
		
	--Rotate if desired (probably desired)
	if (yzFlip.checked == true) then
	(
		rotDummy = dummy pos: ( [0, 0, 0] ) name: ( "rotationDummy")
		sceneBones[1].Parent = rotDummy
		Rotate rotDummy (eulerAngles 90 0 0)
		delete rotDummy
	)	
	
)

on animImportPSO2 pressed do
(
	try
	(
	if loadClear.checked then
	(
		ClearAnimations()
	)
	-- Script start dir
	startPath = getFilenamePath(getThisScriptFilename())
	-- Open up a dialog box
	local animFileName = getOpenFileName caption:"Import Phantasy Star Online 2 .aqm/.trm" \
				types:"PSO2 Motion AQM/TRM (*.aqm,*.trm)|*.aqm;*.trm|All Files (*.*)|*.*|"

	--Load the Animation in
	loadPSO2Anim animFileName
	)
	catch
	(
	)
)

on animExportPSO2 pressed do
(
	try
	(
		-- Open up a dialog box
		local animFileName = getSaveFileName caption:"Export pso2 .aqm/.trm" \
				types:"pso2 .aqm (*.aqm)|*.aqm|pso2 .trm (*.trm)|*.trm|All Files (*.*)|*.*|"

		exportPSO2Anim animFileName
	)
	catch
	(
	)
)

on autoSizeCheckBox changed nowChecked do
(
	autoSizeSpinner.enabled = nowChecked
)

on heelCheck changed nowChecked do
(
	
	heelSpinner.enabled = nowChecked
	if (heelSpinner.enabled == true) then
	(
		for o in objects do
		(
			if (o.name == "(1)body_root") then
			(
				if (yzFlip.checked == true) then
			    (
					tagRoll.heelSpinner.value = o.pos.z
				)
				else
				(
					tagRoll.heelSpinner.value = o.pos.y
				)
			)
		)
	)
)

)
createDialog tagRoll 360 360




