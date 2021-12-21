/*
    PSO2 .set tool
	by Shadowth117
*/

FileIn @"Include\MaxScriptExtensions\FileStreamReader.ms"
FileIn @"Include\MaxScriptExtensions\FileUtils.ms"

fn SetPacketImport fileName autoSize sizeVal yZflip =
(
	-- Read file
	local reader = FileStreamReader()
	reader.SetFile fileName false
	reader.SetBigEndian false
	
	while (eof reader) == false do
	(
		objLen = reader.ReadF16()
		reader.SeekSet( 0x14 )
		objPos = reader.ReadVec3F32()
		objRot = reader.ReadVec3F32()
		reader.SeekSet( 0x2 )
		reader.ReadFixedLengthString (0x30)
	)
	
	reader.Close
)

fn SetImport fileName autoSize sizeVal yZflip =
(
	-- Read file
	local reader = FileStreamReader()
	reader.SetFile fileName false
	reader.SetBigEndian false
	
	entities = #()
	eStarts = #()
	eStrings = #()
	
	reader.SeekCur( 0x4 )
	entityCount = reader.ReadU32()
	eStringCount = reader.ReadU32()
	reader.SeekCur( 0x4 )
	
	--print entityCount
	--print eStringCount
	for i = 1 to eStringCount do
	(
		--print i
		len = reader.ReadU32()
		append eStrings (reader.ReadFixedLengthString (len - 0x4))
	)
	--print "entity acquisition loop"
	aDummy = dummy pos: ( [0, 0, 0] ) boxsize:[1,1,1] name: ( "entityParent" + "_" + (filenameFromPath fileName))
	dec = 
	for i = 1 to entityCount do
	(
		
		--print i
		entLength = reader.ReadU32() - 4
		address = reader.GetPosition()
		--print (bit.intashex address)
		reader.SeekCur( 0x24 )
		entTypeLen = reader.ReadU32()
		entType = (reader.ReadFixedLengthString entTypeLen)
		entThingLen = reader.ReadU32()
		objName = #()
		for i = 1 to entThingLen do
		(
			num = reader.ReadU8()
			append objName num
		)
		objNameConverted = (dotNetObject "System.Text.UnicodeEncoding").GetString objName
		
		--entThing = (reader.ReadFixedLengthString entThingLen)
		reader.SeekCur( 0x8 )
		
		--Read Pos/Rot data? Assumes it's always here though...
		posX = reader.ReadF32()
		temp = reader.ReadU32()
		posXText = reader.ReadFixedLengthString temp
		reader.SeekCur( 0x4 )
		posY = reader.ReadF32()
		temp = reader.ReadU32()
		posYText = reader.ReadFixedLengthString temp
		reader.SeekCur( 0x4 )
		posZ = reader.ReadF32()
		temp = reader.ReadU32()
		posZText = reader.ReadFixedLengthString temp
		reader.SeekCur( 0x4 )
		
		rotX = reader.ReadF32()
		temp = reader.ReadU32()
		rotXText = reader.ReadFixedLengthString temp
		reader.SeekCur( 0x4 )
		rotY = reader.ReadF32()
		temp = reader.ReadU32()
		rotYText = reader.ReadFixedLengthString temp
		reader.SeekCur( 0x4 )
		rotZ = reader.ReadF32()
		temp = reader.ReadU32()
		rotZText = reader.ReadFixedLengthString temp
		reader.SeekCur( 0x4 )
		instanceId = reader.ReadU32()
		temp = reader.ReadU32()
		iIdText = reader.ReadFixedLengthString temp
		reader.SeekCur( 0x4 )
		temp = reader.ReadU32()
		iComment = #()
		for i = 1 to temp do
		(
			num = reader.ReadU8()
			append iComment num
		)
		iCommentConverted = (dotNetObject "System.Text.UnicodeEncoding").GetString iComment
		objNameConverted = (instanceId as string) + "_" + objNameConverted + "_" + iCommentConverted
		
		nDummy = dummy pos: ( [0,0,0] ) boxsize:[5,5,5] name: ( objNameConverted )
		nDummy.rotation = (eulertoquat (eulerangles rotX rotY rotZ))
		--Resize if desired (probably desired)
		if (autoSize == true) then
		(
			nDummy.pos = [posX * sizeVal, posY * sizeVal, posZ * sizeVal]
		) else
		(
			nDummy.pos = [posX, posY, posZ]
		)
		nDummy.parent = aDummy
			
		reader.SeekSet( address + entLength )
	)
	reader.Close
	
	--Rotate if desired (probably desired)
	if (yZFlip == true) then
	(
		Rotate aDummy (eulerAngles 90 0 0)
	)
)

rollout SetWindow "PSO2 .set Tool" width:155 height:150
(
	button 'FileButton' "Load .set" align:#center
	button 'BatchSetImport' "Load .set group" align:#center
	button 'FileButtonPacket' "Load object packet" align:#center
	checkBox autoSizeCheckBox "Rescale" checked:true align:#center
	spinner autoSizeSpinner "Scale by:" align:#center type:#float range:[0,10000,100] enabled:false
	checkBox YZCheckBox "Y-Z Axis Flip" checked: true align:#center
	
	on FileButton pressed do
	(
		
		local objFileName = undefined
		-- Open up a dialog box
		objFileName = getOpenFileName caption:"PSO2 .set" \
					types:"PSO2 set (*.set)|*.set|All Files (*.*)|*.*|"
		if (objFileName != undefined) then
		(
			ClearListener()
			--print (filenameFromPath objFileName)
			SetImport objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked
		)
		max views redraw
	)
	
	on BatchSetImport pressed do
	(
		-- Open up a dialog box
		local objFileName = getOpenFileName caption:"PSO2 .set" \
					types:"PSO2 set (*.set)|*.set|All Files (*.*)|*.*|"
		
		if objFileName != undefined then--if the user did not cancel
        (	
			thePath = getFilenamePath objFileName
			
          theFiles = (getFiles (thePath+"\\*.set"))
		  for objFileName = theFiles do-- go through all of them
          (
			print objFileName
			SetImport objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked
		  )
	    )
		
	    -- Redraw max viewports
		max views redraw
	)
	
	on FileButtonPacket pressed do
	(
		
		local objFileName = undefined
		-- Open up a dialog box
		objFileName = getOpenFileName caption:"PSO2 .set" \
					types:"PSO2 set (*.set)|*.set|All Files (*.*)|*.*|"
		if (objFileName != undefined) then
		(
			ClearListener()
			--print (filenameFromPath objFileName)
			SetPacketImport objFileName autoSizeCheckBox.checked autoSizeSpinner.value YZCheckBox.checked
		)
		max views redraw
	)
)

(
	startup = CreateDialog SetWindow
)