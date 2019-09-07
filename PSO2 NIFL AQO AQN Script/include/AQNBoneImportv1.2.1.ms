/*
	PSO2 .aqn Armature import

	-Huge Thanks to TGE For help with explaining this and for function(s) from other scripts
 
*/
ClearListener()
FileIn @"MaxScriptExtensions\FileStreamReader.ms"
FileIn @"MaxScriptExtensions\FileUtils.ms"

struct BoneStruct 
(
	BoneParent,
	BoneName,
	BoneTFM,
	BoneRelTFM,
	BoneCurRot,
	MaxBone,
	BonePRSPosition,
	BonePRSRotation,
	BonePRSScale,
	BoneFirstChild,
	BoneNextSibling,
	BoneShort1,
	BoneShort2
)

--Relative Transform Getter
fn relativeTransform obj keyTime =
(
	tfm = (obj.transform)
	if obj.Parent != undefined then
	(
		--tfm *= (inverse (relativePosition obj.Parent keyTime)) 
		tfm *= (inverse (obj.Parent.transform)) 
	)
	
	tfm
)

--Relative Transform Getter
/*
fn relativeTransformExtra obj keyTime tfm =
(
	if obj.Parent != undefined then
	(
		--tfm *= (inverse (relativePosition obj.Parent keyTime)) 
		tfm *=  (at time keyTime obj.Parent.transform)
	)
	
	tfm
)
*/

/*
fn ToEulerAngles q =
(
    angles = (eulerangles 0 0 0);

    -- roll (x-axis rotation)
    sinr_cosp = 2.0 * (q.w * q.x + q.y * q.z);
    cosr_cosp = 1.0 - 2.0 * (q.x * q.x + q.y * q.y);
    angles.x = atan2 sinr_cosp cosr_cosp;

    -- pitch (y-axis rotation)
    sinp = 2.0 * (q.w * q.y - q.z * q.x);
    if (abs(sinp) >= 1) then
	(
        angles.y = (copySign (pi / 2) sinp); -- use 90 degrees if out of range
	)
    else
	(
        angles.y = asin(sinp);
	)
	
    -- yaw (z-axis rotation)
    siny_cosp = 2.0 * (q.w * q.z + q.x * q.y);
    cosy_cosp = 1.0 - 2.0 * (q.y * q.y + q.z * q.z);  
    angles.z = atan2 siny_cosp cosy_cosp;

    angles
)

-- yaw (Z), pitch (Y), roll (X) - according to wikipedia. Order seems to be different here?
fn ToQuaternion yaw pitch roll = 
(
    -- Abbreviations for the various angular functions
    cy = cos(yaw * 0.5);
    sy = sin(yaw * 0.5);
    cp = cos(pitch * 0.5);
    sp = sin(pitch * 0.5);
    cr = cos(roll * 0.5);
    sr = sin(roll * 0.5);

    q = quat 0 0 0 0
    q.w = cy * cp * cr + sy * sp * sr
    q.x = cy * cp * sr - sy * sp * cr
    q.y = sy * cp * sr + cy * sp * cr
    q.z = sy * cp * cr - cy * sp * sr

    q
)
*/

fn SkelImport aqnFile PRSChecked ResizeChecked ResizeValue YZRot BoneIDCheck =
(
	-- Read file
	local reader = FileStreamReader()
	reader.SetFile aqnFile false
	reader.SetBigEndian false
	--aqnStm = fopen aqnFile "rb"
	
	deiceCheck = reader.ReadFixedLengthString 0x3
	--Check if we're reading a deicer or ice.exe/ice_ext.exe (repacker) .aqn
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
	
	reader.SeekSet( 0x30 + header )
	nodeCount = reader.ReadU32()
	reader.SeekSet( 0x50 + header )
	--Read bones
	for i = 1 to nodeCount do
	(
		bShort1 = reader.ReadU16(); bShort2 = reader.ReadU16(); 
		reader.SeekCur( 0x04 )
		nodeParent = reader.ReadU32()
		reader.SeekCur( 0x04 )
		nodefirstChild = reader.ReadU32()
		nodeNextSibling = reader.ReadU32()
		reader.SeekCur( 0x08 )
		PosVec = reader.ReadVec3F32(); reader.ReadF32()
		RotVec = reader.ReadVec3F32(); reader.ReadF32()
		ScaleVec = reader.ReadVec3F32(); reader.ReadF32()
		--reader.SeekCur( 0x31 )
		m11 = reader.ReadF32(); m12 = reader.ReadF32(); m13 = reader.ReadF32(); reader.ReadF32()
		m21 = reader.ReadF32(); m22 = reader.ReadF32(); m23 = reader.ReadF32(); reader.ReadF32()
		m31 = reader.ReadF32(); m32 = reader.ReadF32(); m33 = reader.ReadF32(); reader.ReadF32()
		m41 = reader.ReadF32(); m42 = reader.ReadF32(); m43 = reader.ReadF32(); reader.ReadF32()
		boneName = reader.ReadFixedLengthString 0x20
		
		--debug stuff
		/*
		nameBuffer = ""
		posBuffer = ""
		rotBuffer = ""
		sclBuffer = ""
		for j = 1 to (0x20 - boneName.count) do
		(
			nameBuffer = nameBuffer + " "
		)
		for j = 1 to (40 - (PosVec as string).count) do
		(
			posBuffer = posBuffer + " "
		)
		for j = 1 to (40 - (RotVec as string).count) do
		(
			rotBuffer = rotBuffer + " "
		)
		for j = 1 to (40 - (ScaleVec as string).count) do
		(
			sclBuffer = sclBuffer + " "
		)
		print (boneName + ": " + nameBuffer + PosVec as string + posBuffer + RotVec as string + rotBuffer + ScaleVec as string + sclBuffer + " BoneShort1: " + (bit.intAsHex bShort1) + " BoneShort2: " + (bit.intAsHex bShort2))
		*/
		
		tfm = matrix3 [m11,m12,m13] [m21,m22,m23] [m31,m32,m33] [m41,m42,m43]
		append BoneDataArray (BoneStruct BoneParent:nodeParent BoneName:boneName BoneTFM:tfm BoneFirstChild:nodeFirstChild BoneNextSibling:nodeNextSibling MaxBone:undefined BonePRSPosition:PosVec BonePRSRotation:RotVec BonePRSScale:ScaleVec BoneShort1:bShort1 BoneShort2:bShort2)
	)
	
	--Read other nodes, if they exist
	while ( ( reader.GetPosition() + 0x50 ) < reader.GetFileStreamLength() ) do
	(
		bShort1 = reader.ReadU16(); bShort2 = reader.ReadU16(); reader.ReadF32(); BoneParent = reader.ReadU32(); reader.ReadF32()
		PosVec = reader.ReadVec3F32(); reader.ReadF32()
		RotVec = reader.ReadVec3F32(); reader.ReadF32()
		boneName = reader.ReadFixedLengthString 0x20
		append ExtraDataArray (BoneStruct BoneParent:BoneParent BoneName:boneName BoneTFM:undefined MaxBone:undefined BonePRSPosition:PosVec BonePRSRotation:RotVec BonePRSScale:undefined BoneShort1:bShort1 BoneShort2:bShort2)
	)

	reader.Close()
	
	--Create bones in max
	nodeCounter = 0
	for node in BoneDataArray do
    (
        local parentBone = undefined;
        if ( node.BoneParent != -1 ) then
		(
            parentBone = BoneDataArray[node.BoneParent+1].MaxBone;
		)
		
		if (PRSChecked) then
		(
			prsAngles = eulerangles node.BonePRSRotation.x node.BonePRSRotation.y node.BonePRSRotation.z
			BoneDataArray[nodeCounter+1].BoneCurRot = [prsAngles.x, prsAngles.y, prsAngles.z]

			tfm = (eulerangles (node.BonePRSRotation.x) (node.BonePRSRotation.y) (node.BonePRSRotation.z) ) as matrix3
			tfm.row4 = [ node.BonePRSPosition.x, node.BonePRSPosition.y, node.BonePRSPosition.z ]
			--tfm *= ScaleMatrix node.BonePRSScale --(Data in animation doesn't seem to match up if used? Research more for things that use this, such as ui_title_cm_back.aqn)
		) else (
			 tfm = (inverse node.BoneTFM);
		)
		
		
		if ( parentBone != undefined and PRSChecked) then
		(
			parentTFM = copy parentBone.Transform
			tfm = tfm * parentTFM
		)
		
		newBone = bonesys.createbone \
			tfm.row4 \
			(tfm.row4 + 0.01 * (normalize tfm.row3)) \
			(normalize tfm.row1);
		
		--debug
		/*
		sclX = 0; sclY = 0; sclZ = 0;
		if(abs(node.BonePRSRotation.x) >= 90) then ( print ("testx: " + node.BoneName); sclX = -90 )
		if(abs(node.BonePRSRotation.y) >= 90) then ( print ("testy: " + node.BoneName); sclY = -90 )
		if(abs(node.BonePRSRotation.z) >= 90) then ( print ("testz: " + node.BoneName); sclZ = -90 )
		*/
				
		if (BoneIDCheck == true) then
		(
			newBone.name = ("(" + nodeCounter as string + ")" + node.BoneName);
		)
		else
		(
			newBone.name = node.BoneName;
		)
        newBone.width  = 0.001;
        newBone.height = 0.001;
        newBone.transform = tfm;
        newBone.setBoneEnable false 0;
        newBone.wirecolor = ([0,196,196] as color);
        newBone.showlinks = true;
        newBone.pos.controller      = TCB_position ();
        newBone.rotation.controller = TCB_rotation ();
		--Handle Bone Shorts
		boneShort1Fix = (bit.intAsHex node.BoneShort1)
		boneShort2Fix = (bit.intAsHex node.BoneShort2)
		while( boneShort1Fix.count < 4 ) do
		(
			boneShort1Fix = ("0" + boneShort1Fix)
		)
		while( boneShort2Fix.count < 4 ) do
		(
			boneShort2Fix = ("0" + boneShort2Fix)
		)
		setUserProp newBone "BoneShort1" boneShort1Fix
		setUserProp newBone "BoneShort2" boneShort2Fix
		setUserProp newBone "EffectNode" false
		setUserProp newBone "NodeID" nodeCounter
		
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
					  
		--Handle Bone Shorts
		boneShort1Fix = (bit.intAsHex node.BoneShort1)
		boneShort2Fix = (bit.intAsHex node.BoneShort2)
		while( boneShort1Fix.count < 4 ) do
		(
			boneShort1Fix = ("0" + boneShort1Fix)
		)
		while( boneShort2Fix.count < 4 ) do
		(
			boneShort2Fix = ("0" + boneShort2Fix)
		)
		setUserProp newBone "BoneShort1" boneShort1Fix
		setUserProp newBone "BoneShort2" boneShort2Fix
		setUserProp newBone "EffectNode" true
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

fn SkelExport aqnFile ResizeChecked ResizeValue YZRot =
(
	ClearListener()
	
	--Round Constants for first set of PRS values
	rndConst = 1.5117269e-9 --Our main epsilon for comparing floats (true value may be lower, dunno)   ---  abs(a - b) < float.epsilon ---
	rndConstX = 1.5117269e-9 --For some reason, X translation values seem to cut off lower???
	rotConst = 1.5117269e-9 --Rotation epsilon
	
	rootBackup = undefined
	byOrder = true
	boneParams = #()
	effParams = #() -- Effect nodes should always be written at the end and so stored separately
	
	--Check how bone export order will be done
	scenebones = #()
	for o in objects where isGroupHead o == false and isGroupMember o == false and (superclassof o == helper or classOf o == Biped_Object or classOf o == BoneGeometry or (try(classOf o.transform.controller == BipSlave_Control)catch(false))) do
	(
		boneCheck = findString (o.name) "("
		if (boneCheck == 1 or GetUserProp o "NodeID" != undefined) then
		(
			byOrder = false
		)
		if (findstring o.name "(0)" != undefined) then -- Get the pso2 bone parent
		(
			scenebones[1] = o
		)
		if (o.parent == undefined and scenebones[1] == undefined) then --Try to assign the first root node looking node as the root if unmarked. Leave it to user to make the root bone in this case.
		(
			scenebones[1] = o
		)
	)
	
		--Rotate if desired (probably desired)
	if (YZRot == true) then
	(
		rotDummy = dummy pos: ( [0, 0, 0] ) name: ( "rotationDummy")
		sceneBones[1].Parent = rotDummy
		Rotate rotDummy (eulerAngles -90 0 0)
		delete rotDummy
	)
	
	--Loop through bones and gather info
	for o in objects where isGroupHead o == false and isGroupMember o == false and (superclassof o == helper or classOf o == Biped_Object or classOf o == BoneGeometry or (try(classOf o.transform.controller == BipSlave_Control)catch(false))) do
	(
		
		--Write user properties to allow for animation export after if desired
		if getUserProp o "BoneShort1" == undefined then
		(
			setUserProp o "BoneShort1" 0x1C0
		)
		if getUserProp o "BoneShort2" == undefined then
		(
			setUserProp o "BoneShort2" 0x0
		)
		if getUserProp o "EffectNode" == undefined then
		(
			setUserProp o "EffectNode" false
		)
		if getUserProp o "NodeID" == undefined then
		(
			setUserProp o "NodeID" boneParams.Count
		)
		
		--print o
		boneName = o.name
		boneParent = o.parent
		boneMatrix = (inverse o.transform)
		relBoneMatrix = (relativeTransform o 0) --Get local transform for object based on parent transform
		
		--debug stuff
		/*
		RotVec = (quatToEuler2 o.transform.rotationpart)
		RotVecRel = (quatToEuler2 relBoneMatrix.rotationpart)
		nameBuffer = ""
		rotBuffer = ""
		for j = 1 to (0x20 - boneName.count) do
		(
			nameBuffer = nameBuffer + " "
		)
		for j = 1 to (40 - (RotVec as string).count) do
		(
			rotBuffer = rotBuffer + " "
		)*/
		
		
		
		boneFirstChild = undefined
		boneNextSibling = undefined
				
		if (ResizeChecked == true) then 
		(
			boneMatrix.translation *= ( 1 / ResizeValue )
			relBoneMatrix.translation *= ( 1 / ResizeValue )
		)
		
		--Get Bone bitflag shorts if they exist
		if((getUserProp o "BoneShort1") != undefined) then
		(
			boneShort1 = (substring ((getUserProp o "BoneShort1") as string) 1 4) 
			boneShort2 = (substring ((getUserProp o "BoneShort2") as string) 1 4) 
		)
		else
		(
			boneShort1 = undefined
			boneShort2 = undefined
		)
		
		--Get first child if there's children
		if (o.children.count != 0 ) then
		( 
			if(((getUserProp o.children[1] "EffectNode") == false)) then --Don't write effect nodes here
			(
				if ((findString (o.children[1].name) "(") == 1) then
				(
					boneFirstChild = ((filterstring o.children[1].name "()")[1] as integer) --extract the number
				)
				else
				(
					boneFirstChild = o.children[1].name
				)
			)
			else
			(
				boneFirstChild = -1
			)
		)
		else
		(
			boneFirstChild = -1
		)
		
		--Find  the node's next sibling by order
		if(o.parent != undefined) then
		(
			rootBackup = o
			parentChildren = o.parent.children
			if (parentChildren.count > 1 and parentChildren[parentChildren.count] != o) then
			(
				nextChild = false
				for i = 1 to parentChildren.count do
				(
					if(nextChild == true) then
					(
						if((getUserProp parentChildren[i] "EffectNode") == false) then --Don't write effect nodes here
						(
							if ((findString (parentChildren[i].name) "(") == 1) then
							(
								boneNextSibling = ((filterstring parentChildren[i].name "()")[1] as integer) 
							) else
							(
								boneNextSibling = parentChildren[i].name
							)
							nextChild = false
						)
					) else if parentChildren[i] == o then
					(
						nextChild = true
					)
				)
			)
			if(boneNextSibling == undefined) then
			(
				boneNextSibling = -1
			)
		)	
		else 
		(
			boneNextSibling = -1
		)
		
		
		--Check how nodes should be added
		if ((getUserProp o "EffectNode") == false or (getUserProp o "EffectNode") == undefined ) then
		(
			if (byOrder == true) then
			(
				append boneParams (boneStruct BoneParent:boneParent BoneName:boneName BoneTFM:boneMatrix BoneRelTFM:relBoneMatrix BoneFirstChild:boneFirstChild BoneNextSibling:boneNextSibling BoneShort1:boneShort1 BoneShort2:boneShort2)
			)
			else
			(
				if ((findString (o.name) "(") == 1) then
				(
					id = (filterstring o.name "()")[1]
					boneParams[((id as integer) + 1)] = (boneStruct BoneParent:boneParent BoneName:boneName BoneTFM:boneMatrix BoneRelTFM:relBoneMatrix BoneFirstChild:boneFirstChild BoneNextSibling:boneNextSibling BoneShort1:boneShort1 BoneShort2:boneShort2)
				) else 
				(
					id = getUserProp o "NodeID"
					boneParams[((id as integer) + 1)] = (boneStruct BoneParent:boneParent BoneName:boneName BoneTFM:boneMatrix BoneRelTFM:relBoneMatrix BoneFirstChild:boneFirstChild BoneNextSibling:boneNextSibling BoneShort1:boneShort1 BoneShort2:boneShort2)
				)
			)
		) 
		else
		(
			append effParams (boneStruct BoneParent:boneParent BoneName:boneName BoneTFM:boneMatrix BoneRelTFM:relBoneMatrix BoneFirstChild:boneFirstChild BoneNextSibling:boneNextSibling BoneShort1:boneShort1 BoneShort2:boneShort2)
		)
	)

	sanityCheckCount = -1
	
	--Sanity check; All node slots SHOULD be filled by the user, but if not....
	for i = 1 to boneParams.count do
	(
		if (boneParams[i] == undefined) then
		(
			print boneParams[i]
			sanityCheckCount += 1
			sanityName = "badNode" + sanityCheckCount as string
			boneParams[i] = (boneStruct BoneParent:rootBackup BoneName:sanityName BoneTFM:(matrix3 1) BoneRelTFM:(matrix3 1) BoneFirstChild:(-1) BoneNextSibling:(-1) BoneShort1:undefined BoneShort2:undefined)
			print boneParams[i].BoneName
		)
	)
	
	for i = 1 to effParams.count do
	(
		if (effParams[i] == undefined) then
		(
			print effParams[i]
			sanityCheckCount += 1
			sanityName = "badNode" + sanityCheckCount as string
			effParams[i] = (boneStruct BoneParent:rootBackup BoneName:sanityName BoneTFM:(matrix3 1) BoneRelTFM:(matrix3 1) BoneFirstChild:(-1) BoneNextSibling:(-1) BoneShort1:undefined BoneShort2:undefined)
			print effParams[i].BoneName
		)
	)
	
	-- Check for Parents, First Children, and Next Siblings that are strings instead of ids
	for bp in boneParams do
	(
		bParentDone = false
		bFChildDone = false
		bNSiblingDone = false
		if (bp.BoneParent != undefined) then
		(
			if ((findString (bp.BoneParent.name) "(") == 1) then
			(
				bp.BoneParent = ((filterstring bp.BoneParent.name "()")[1] as integer)
			)	else 
			(
				for q = 1 to boneParams.count do
				(
					if (bParentDone == false) then
					(
						if (bp.BoneParent.name == boneParams[q].BoneName) then
						(
							bp.BoneParent = (q - 1)
							bParentDone = true
						)
					)
				)
			)
		)
		if (classof bp.BoneFirstChild == string) then
		(	
			for q = 1 to boneParams.count do
			(
				if (bFChildDone == false) then
				(
					if (bp.BoneFirstChild == boneParams[q].BoneName) then
					(
						bp.BoneFirstChild = (q - 1)
						bPFChildDone = true
					)
				)
			)
		)
		if (classof bp.BoneNextSibling == string) then
		(
			for q = 1 to boneParams.count do
			(
				if (bNSiblingDone == false) then
				(
					if (bp.BoneNextSibling == boneParams[q].BoneName) then
					(
						bp.BoneNextSibling = (q - 1)
						bNSiblingDone = true
					)
				)
			)
		)
	)
	
	-- Check for Parents that are strings instead of ids (Children and siblings are unused for these) Remember effect nodes CANNOT be parented to effect nodes
	for ep in effParams do
	(
		if (ep == undefined) then
		(
			sanityCheckCount += 1
			sanityName = "badNode" + sanityCheckCount as string
			bp = (boneStruct BoneParent:rootBackup BoneName:sanityName BoneTFM:(matrix3 1) BoneRelTFM:(matrix3 1) BoneFirstChild:(-1) BoneNextSibling:(-1) BoneShort1:undefined BoneShort2:undefined)
		)
		eParentDone = false
		
		if (ep.BoneParent != undefined) then
		(
			if ((findString (ep.BoneParent.name) "(") == 1) then
			(
				ep.BoneParent = ((filterstring ep.BoneParent.name "()")[1] as integer)
			)	else 
			(
				for q = 1 to boneParams.count do
				(
					if (eParentDone == false) then
					(
						if (ep.BoneParent.name == boneParams[q].BoneName) then
						(
							ep.BoneParent = (q - 1)
							eParentDone = true
						)
					)
				)
			)
		)
	)
	
	pso2Bones = fopen aqnFile "wb"
	
	--NIFL Header
	--should be populated later with a few values once the final is finished writing almost
	WriteString pso2Bones "NIFL"
	fseek pso2Bones (-1) #seek_cur
	WriteLong  pso2Bones 0x18 -- offset to a u32 that is some length of something? Always seems to be 0x18
	WriteLong  pso2Bones 1 -- Just 1
	WriteLong  pso2Bones 0x20 -- REL0 offset
	nofMinus20Add = (ftell pso2Bones)
	WriteLong  pso2Bones 0 --NOF0 offset - 0x20?
	nofAdd = (ftell pso2Bones)
	WriteLong  pso2Bones 0 --NOF0 offset
	nofSizeAdd = (ftell pso2Bones)
	WriteLong  pso2Bones 0x20 --Size of NOF0 block - For aqn, always appears to be 0x20
	WriteLong  pso2Bones 0 --Padding
	-----------------------------------------------------------------
	
	--REL0 Struct
	WriteString pso2Bones "REL0"
	fseek pso2Bones (-1) #seek_cur
	relSizeAdd = (ftell pso2Bones)
	WriteLong pso2Bones 0 --Size of REL0 
	WriteLong pso2Bones 0x10 --Just 0x10
	WriteLong pso2Bones 0 -- Just 0
	
	--NodeTree
	WriteLong pso2Bones boneParams.count -- bonecount
	WriteLong pso2Bones 0x30 -- Always 0x30?
	WriteLongLong pso2Bones 0 -- Always 0
	WriteLong pso2Bones effParams.count
	effNodeAdd = (ftell pso2Bones)
	WriteLong pso2Bones 0 -- Effect node address
	WriteLongLong pso2Bones 0 -- Always 0
	
	--Bone structs
	for i = 1 to boneParams.count do
	(
		if(boneParams[i].BoneShort1 != undefined) then -- Check if there's custom data to use
		(
			WriteShort pso2Bones (("0x" + boneParams[i].BoneShort1) as integer) -- Some kind of bitflag? For players at least, 1C0 will work for almost everything, although others are used
			WriteShort pso2Bones (("0x" + boneParams[i].BoneShort2) as integer) -- Another bitflag?
		)
		else
		(
			WriteShort pso2Bones 0x1C0
			WriteShort pso2Bones 0x0
		)
		WriteLong pso2Bones 0x1 -- Always 0x1?
		if (boneParams[i].BoneParent != undefined) then
		(
			WriteLong pso2Bones boneParams[i].BoneParent-- Parent bone as int
		) else
		(
			WriteLong pso2Bones -1 -- null if no parent
		)
		WriteLong pso2Bones -1-- Always this
		
		if(boneParams[i].BoneFirstChild != undefined) then
		(
			WriteLong pso2Bones boneParams[i].BoneFirstChild -- First child 
		) else
		(
			WriteLong pso2Bones -1 -- Always this
		)
		
		if(boneParams[i].BoneNextSibling != undefined) then
		(
			if(boneParams[i].BoneNextSibling != -1) then
			(
				WriteLong pso2Bones boneParams[i].BoneNextSibling -- Next sibling id by order
			) else
			(
				WriteLong pso2Bones -1 -- Can't write 8 Fs with WriteLong because reasons
			)
		) else
		(
			WriteLong pso2Bones -1 -- Always this
		)
		WriteLongLong pso2Bones 0 -- Always 0?
		
		WriteFloat pso2Bones boneParams[i].BoneRelTFM.translationpart.x -- Bone PosX
		WriteFloat pso2Bones boneParams[i].BoneRelTFM.translationpart.y -- Bone PosY
		WriteFloat pso2Bones boneParams[i].BoneRelTFM.translationpart.z -- Bone PosZ 
		WriteFloat pso2Bones 0 -- Always 0?
		eulerRot = (quattoeuler2 boneParams[i].BoneRelTFM.rotationpart)
		--print (boneParams[i].BoneName + eulerRot as string)
		WriteFloat pso2Bones eulerRot.x -- Bone RotX Euler
		WriteFloat pso2Bones eulerRot.y -- Bone RotY Euler
		WriteFloat pso2Bones eulerRot.z -- Bone RotZ Euler
		WriteFloat pso2Bones 0 -- Always 0?
		
		/*
		WriteFloat pso2Bones boneParams[i].BoneRelTFM.scalepart.x -- Bone ScaleX
		WriteFloat pso2Bones boneParams[i].BoneRelTFM.scalepart.y -- Bone ScaleY
		WriteFloat pso2Bones boneParams[i].BoneRelTFM.scalepart.z -- Bone ScaleZ 
		*/
		
		--Check if scale should be inverted
		if abs(eulerRot.y) > 120 then
		(
			WriteFloat pso2Bones -1
			WriteFloat pso2Bones -1
			WriteFloat pso2Bones -1
			WriteFloat pso2Bones 0 -- Always 0?
		) else
		(
			WriteFloat pso2Bones 1
			WriteFloat pso2Bones 1
			WriteFloat pso2Bones 1
			WriteFloat pso2Bones 0 -- Always 0?
		)
		
		WriteFloat pso2Bones (boneParams[i].BoneTFM.row1.x); WriteFloat pso2Bones (boneParams[i].BoneTFM.row1.y); WriteFloat pso2Bones (boneParams[i].BoneTFM.row1.z); WriteLong pso2Bones 0
		WriteFloat pso2Bones (boneParams[i].BoneTFM.row2.x); WriteFloat pso2Bones (boneParams[i].BoneTFM.row2.y); WriteFloat pso2Bones (boneParams[i].BoneTFM.row2.z); WriteLong pso2Bones 0
		WriteFloat pso2Bones (boneParams[i].BoneTFM.row3.x); WriteFloat pso2Bones (boneParams[i].BoneTFM.row3.y); WriteFloat pso2Bones (boneParams[i].BoneTFM.row3.z); WriteLong pso2Bones 0
		WriteFloat pso2Bones (boneParams[i].BoneTFM.row4.x); WriteFloat pso2Bones (boneParams[i].BoneTFM.row4.y); WriteFloat pso2Bones (boneParams[i].BoneTFM.row4.z); WriteFloat pso2Bones 1

		--Handle name string
		boneName = boneParams[i].BoneName
		if ((filterstring boneName ")").count > 1) then
		(
			boneName = (filterstring boneName ")")[2]
		)
		boneName = substring boneName 1 0x20 -- avoid going over
		extraSpace = 0x20 - (boneName.count) --calculate space left to 20 (if any)
		WriteString pso2Bones boneName -- name
		fseek pso2Bones (-1) #seek_cur
		for e = 1 to extraSpace do -- add padding to reach 0x20 if needed
		(
			WriteByte pso2Bones 0x0
		)
	)
	
	effBegin = (ftell pso2Bones)
	--Effect structs
	for i = 1 to effParams.count do
	(
		if(effParams[i].BoneShort1 != undefined) then -- Check if there's custom data to use
		(
			WriteShort pso2Bones (("0x" + effParams[i].BoneShort1) as integer) -- Some kind of bitflag? For players at least, 1C0 will work for almost everything, although others are used
			WriteShort pso2Bones (("0x" + effParams[i].BoneShort2) as integer) -- Another bitflag?
		)
		else
		(
			WriteShort pso2Bones 0x0
			WriteShort pso2Bones 0x0
		)
		WriteLong pso2Bones 0x1 -- Always 0x1?
		if (effParams[i].BoneParent != undefined) then
		(
			WriteLong pso2Bones effParams[i].BoneParent-- Parent bone as int
		) else
		(
			WriteLong pso2Bones -1 -- null if no parent
		)
		WriteLong pso2Bones 0x0 -- Always this
		
		WriteFloat pso2Bones effParams[i].BoneRelTFM.translationpart.x -- Bone PosX
		WriteFloat pso2Bones effParams[i].BoneRelTFM.translationpart.y -- Bone PosY
		WriteFloat pso2Bones effParams[i].BoneRelTFM.translationpart.z -- Bone PosZ 
		WriteFloat pso2Bones 0 -- Always 0?
		eulerRot = (quatToEuler2 effParams[i].BoneRelTFM.rotationpart)
		WriteFloat pso2Bones eulerRot.x -- Bone RotX Euler
		WriteFloat pso2Bones eulerRot.y -- Bone RotY Euler
		WriteFloat pso2Bones eulerRot.z -- Bone RotZ Euler
		WriteFloat pso2Bones 0 -- Always 0?

		--Handle name string
		boneName = effParams[i].BoneName
		if ((filterstring boneName ")").count > 1) then
		(
			boneName = (filterstring boneName ")")[2]
		)
		boneName = substring boneName 1 0x20 -- avoid going over
		extraSpace = 0x20 - (boneName.count) --calculate space left to 20 (if any)
		WriteString pso2Bones boneName -- name
		fseek pso2Bones (-1) #seek_cur
		for e = 1 to extraSpace do -- add padding to reach 0x20 if needed
		(
			WriteByte pso2Bones 0x0
		)
	)
	
	--NOF0
	nofBegin = (ftell pso2Bones) 
	WriteString pso2Bones "NOF0"
	fseek pso2Bones (-1) #seek_cur
	nofSizeNof = (ftell pso2Bones) 
	if (effParams.count > 0) then --Proceeding values are ALWAYS the same if there's effects
	(
		WriteLong pso2Bones 0x10
		WriteLong pso2Bones 0x2
		WriteLong pso2Bones 0x0
		WriteLong pso2Bones 0x14
		WriteLong pso2Bones 0x24
		nofDataSize = ((ftell pso2Bones) + 0x08) - nofBegin - 0x10
		WriteLongLong pso2Bones 0x0
	) else --If no effects, values are always these
	(
		WriteLong pso2Bones 0xC
		WriteLong pso2Bones 0x1
		WriteLong pso2Bones 0x0
		WriteLong pso2Bones 0x14
		nofDataSize = ((ftell pso2Bones) + 0x08) - nofBegin - 0x10
		WriteLong pso2Bones 0x0
		WriteLongLong pso2Bones 0x0
	)
	nofTotalSize = (ftell pso2Bones) - nofBegin
	
	--NEND
	WriteString pso2Bones "NEND"
	fseek pso2Bones (-1) #seek_cur
	WriteLong pso2Bones 0x8
	WriteLongLong pso2Bones 0x0
	
	--Fix up addresses
	--    NIFL null addresses
	fseek pso2Bones nofMinus20Add #seek_set
	WriteLong pso2Bones (nofBegin - 0x20)
	WriteLong pso2Bones nofBegin
	WriteLong pso2Bones nofTotalSize
	--    REL0 null addresses
	fseek pso2Bones relSizeAdd #seek_set
	WriteLong pso2Bones (nofBegin - (relSizeAdd + 0x04))
	if(effParams.count > 0) then
	(
		fseek pso2Bones effNodeAdd #seek_set
		WriteLong pso2Bones (effBegin)
	)
	--    NOF0 null addresses
	fseek pso2Bones nofSizeNof #seek_set
	WriteLong pso2Bones nofDataSize
	
	fflush pso2Bones
	fclose pso2Bones
	
	--Rotate if desired (probably desired)
	if (YZRot == true) then
	(
		rotDummy = dummy pos: ( [0, 0, 0] ) name: ( "rotationDummy")
		sceneBones[1].Parent = rotDummy
		Rotate rotDummy (eulerAngles 90 0 0)
		delete rotDummy
	)	
	gc()
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