/*
	PSO2 .aqn Armature import

	-Huge Thanks to TGE For help with explaining this and for function(s) from other scripts
	
	--Todo 
	---Add file selectors for obj 
*/
ClearListener()
FileIn @"MaxScriptExtensions\FileStreamReader.ms"
FileIn @"MaxScriptExtensions\FileUtils.ms"


struct BoneStruct 
(
	BoneParent,
	BoneName,
	BoneTFM,
	MaxBone,
	BonePRSPosition,
	BonePRSRotation,
	BonePRSScale
)

fn SkelImport aqnFile PRSChecked ResizeChecked ResizeValue YZRot =
(
	-- Read file
	local reader = FileStreamReader()
	reader.SetFile aqnFile false
	reader.SetBigEndian true
	--aqnStm = fopen aqnFile "rb"
	
	deiceCheck = reader.ReadFixedLengthString 0x3
	--Check if we're reading a deiced or ICE(.ice)????? (repacker) .aqn
	if (deiceCheck == "aqn" or deiceCheck == "trn") then
	(
		header = 0x60
	) else
	(
		header = 0x0
	)
	
	tfmMatrices = #()
	nodeParents = #()
	nodeNames = #()
	BoneDataArray = #()
	ExtraDataArray = #()
	
	reader.SeekSet( 0x2D + header )
	nodeCount = reader.ReadU32()
	reader.SeekSet( 0x50 + header )
	reader.SetBigEndian false
	--Read bones
	for i = 1 to nodeCount do
	(
		reader.SeekCur( 0x08 )
		nodeParent = reader.ReadU32()
		reader.SeekCur( 0x14 )
		PosVec = reader.ReadVec3F32(); reader.ReadF32()
		RotVec = reader.ReadVec3F32(); reader.ReadF32()
		ScaleVec = reader.ReadVec3F32(); reader.ReadF32()
		--reader.SeekCur( 0x31 )
		m11 = reader.ReadF32(); m12 = reader.ReadF32(); m13 = reader.ReadF32(); reader.ReadF32()
		m21 = reader.ReadF32(); m22 = reader.ReadF32(); m23 = reader.ReadF32(); reader.ReadF32()
		m31 = reader.ReadF32(); m32 = reader.ReadF32(); m33 = reader.ReadF32(); reader.ReadF32()
		m41 = reader.ReadF32(); m42 = reader.ReadF32(); m43 = reader.ReadF32(); reader.ReadF32()
		boneName = reader.ReadFixedLengthString 0x20
		
		tfm = matrix3 [m11,m12,m13] [m21,m22,m23] [m31,m32,m33] [m41,m42,m43]
		append BoneDataArray (BoneStruct BoneParent:nodeParent BoneName:boneName BoneTFM:tfm MaxBone:undefined BonePRSPosition:PosVec BonePRSRotation:RotVec BonePRSScale:ScaleVec)
	)
	
	--Read other nodes, if they exist
	while ( ( reader.GetPosition() + 0x50 ) < reader.GetFileStreamLength() ) do
	(
		reader.ReadF32(); reader.ReadF32(); BoneParent = reader.ReadU32(); reader.ReadF32()
		PosVec = reader.ReadVec3F32(); reader.ReadF32()
		RotVec = reader.ReadVec3F32(); reader.ReadF32()
		boneName = reader.ReadFixedLengthString 0x20
		append ExtraDataArray (BoneStruct BoneParent:BoneParent BoneName:boneName BoneTFM:undefined MaxBone:undefined BonePRSPosition:PosVec BonePRSRotation:RotVec BonePRSScale:undefined)
	)
	
	--Create bones in max
	nodeCounter = 0
	for node in BoneDataArray do
    (
        local parentBone = undefined;
        if ( node.BoneParent != -1 ) do
            parentBone = BoneDataArray[node.BoneParent+1].MaxBone;
		
		if (PRSChecked) then
		(
			tfm = (eulerangles node.BonePRSRotation.x -node.BonePRSRotation.y node.BonePRSRotation.z) as matrix3
			tfm *= ScaleMatrix node.BonePRSScale
			tfm.row4 = node.BonePRSPosition
		) else (
			 tfm = (inverse node.BoneTFM);
		)
		
		--local tfm = (inverse node.BoneTFM);
        if ( parentBone != undefined and PRSChecked) do
            tfm *= parentBone.Transform;
		
		if(PRSChecked) then
		(
	        local newBone = bonesys.createbone \
                  tfm.row4 \
                  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
                  (normalize tfm.row3);		
		) else (
	        local newBone = bonesys.createbone \
                  tfm.row4 \
                  (tfm.row4 + 0.01 * (normalize tfm.row3)) \
                  (normalize tfm.row1);		
		)

                          
        newBone.name = ("(" + nodeCounter as string + ")" + node.BoneName);
        newBone.width  = 0.001;
        newBone.height = 0.001;
        newBone.transform = tfm;
        newBone.setBoneEnable false 0;
        newBone.wirecolor = ([0,196,196] as color);
        newBone.showlinks = true;
        newBone.pos.controller      = TCB_position ();
        newBone.rotation.controller = TCB_rotation ();
		if (ResizeChecked == true) then 
		(
			newBone.pos = [newBone.pos.x * ResizeValue, newBone.pos.y * ResizeValue, newBone.pos.z * ResizeValue]
		)
        newBone.Parent = parentBone;
        nodeCounter += 1;
        node.MaxBone = newBone; 
    )
	
	--Create extra nodes in max
	for node in ExtraDataArray do
	(
		tfm = (eulerangles node.BonePRSRotation.x node.BonePRSRotation.y node.BonePRSRotation.z) as matrix3
		--tfm *= ScaleMatrix node.BonePRSScale
		tfm.row4 = node.BonePRSPosition
		
		
		if ( node.BoneParent != -1) do
		(
			maxParent = BoneDataArray[node.BoneParent+1].MaxBone
			if (ResizeChecked == true) then 
			(
				tfm *= ScaleMatrix [ ResizeValue, ResizeValue, ResizeValue ]
			)
            tfm *= maxParent.Transform
		)
		
        local newBone = bonesys.createbone \
                  tfm.row4 \
                  (tfm.row4 + 0.01 * (normalize tfm.row3)) \
                  (normalize tfm.row1);
                          
        newBone.name = node.BoneName;
        newBone.width  = 0.05;
        newBone.height = 0.05;
        newBone.transform = tfm;
        newBone.setBoneEnable false 0;
        newBone.wirecolor = ([0,196,0] as color);
        newBone.showlinks = true;
        newBone.pos.controller      = TCB_position ();
        newBone.rotation.controller = TCB_rotation ();
		/*
		if (ResizeChecked == true) then 
		(
			newBone.pos = [newBone.pos.x * ResizeValue, newBone.pos.y * ResizeValue, newBone.pos.z * ResizeValue]
		)*/
		newBone.Parent = maxParent;
	)
	
	if(YZRot == true) then
    (
		rotDummy = dummy pos: ( [0, 0, 0] ) name: ( "rotationDummy")
		BoneDataArray[1].maxBone.Parent = rotDummy
		Rotate rotDummy (eulerAngles 90 0 0)
		delete rotDummy
	)
	
	BoneDataArray
)
/*
rollout aqnImport "PSO2 .aqn Bone Importer"
(
		--------------------
	-- User Interface --
	--------------------
	group "About"
	(
		label lab1 "PSO2 .aqn Bone Importer"
		Label lab2 "By Shadowth117"
	)
	group "Settings"
	(
		checkBox autoSizeCheckBox "Rescale" checked:false align:#center
		spinner autoSizeSpinner "Scale by:" align:#center type:#float range:[0,10000,100] enabled:false
		checkBox YZCheckBox "Y-Z Axis Flip" checked: true align:#center
		checkBox PRSImport "Use PRS Data" checked: false align:#center
	)	
	group "Import"
	(
		button importButton "Import..."
	)

	on autoSizeCheckBox changed nowChecked do
	(
		autoSizeSpinner.enabled = nowChecked
	)
	
	on importButton pressed do
	(
		local objFileName = undefined
		-- Open up a dialog box
		objFileName = getOpenFileName caption:"Import Phantasy Star Online 2 .aqn" \
					types:"PSO2 Skeleton AQN (*.aqn)|*.aqn|All Files (*.*)|*.*|"
        if (objFileName != undefined) then
		(
			SkelImport objFileName (PRSChecked = PRSImport.checked)
		)
		
		-- Redraw max viewports
		max views redraw
		-- Ta-daa! You should now see a lovely new imported model in all its glory.
		--print "Import completed."
	)
)
createDialog aqnImport 160 320*/