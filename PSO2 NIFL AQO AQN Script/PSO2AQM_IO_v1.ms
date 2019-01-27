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
	nodeCount = reader.ReadU32()
	
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
	)
	
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
					reader.SeekCur( 0x4 )
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
						reader.SeekCur( 0x4 )
						append rotFrames rotFrame
					)
				)
				else
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
						reader.SeekCur( 0x4 )
						append sclFrames sclFrame
					)
				)
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
		) else 
		(
			append nodeAnimArray undefined
		)
		
	)
	
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
			id = (filterstring o.name "()")[1]
			sceneBones[( (id as integer) + 1)] = o
		)
	)
	--Get time of last frame
	animTime = undefined
	j = 1
	while (animTime == undefined) do
	(
		if(nodeAnimArray[j] != undefined) then
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
	)
	
	animButtonState = false
	
	--Rotate if desired (probably desired)
	if (yzFlip.checked == true) then
	(
		rotDummy = dummy pos: ( [0, 0, 0] ) name: ( "rotationDummy")
		sceneBones[1] .Parent = rotDummy
		Rotate rotDummy (eulerAngles 90 0 0)
		delete rotDummy
	)
	gc()
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
createDialog tagRoll 340 280




