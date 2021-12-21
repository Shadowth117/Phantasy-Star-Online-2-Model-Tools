/*
RemoveUnusedBones maxscript
sourced from:
https://forums.cgsociety.org/t/remove-unused-bones-from-a-skin-mod/1805378/2

This script was modified slightly to allow for input and detection of boneless meshes.

Input:
objs - An array of mesh(es).

*/

fn RemoveUnusedBones objs =
(
	max modify mode
	local weightThresh = 0.0001
		
	for obj in objs do (
		--Make sure there's actually skin to remove bones from
		if (for m in obj.modifiers where isKindOf m skin collect m).count > 0 then
		(
			select obj
			
			for m in obj.modifiers where classof m == Skin do (
				modPanel.setCurrentObject m
				
				local vertCount = skinOps.GetNumberVertices m
				local bonesCount = skinOps.GetNumberBones m
				local unusedBones = #{1..bonesCount}
				
				for v = 1 to vertCount do (
					local vertWeightCount = skinOps.GetVertexWeightCount m v
					
					for i = 1 to vertWeightCount do (
						local weight = skinOps.GetVertexWeight m v i
						if weight >= weightThresh then (
							local boneID = skinOps.GetVertexWeightBoneID m v i
							unusedBones[boneID] = false
						)
					)
				)
				
				for i = bonesCount to 1 by -1 where unusedBones[i] do (
					skinOps.SelectBone m i
					skinOps.RemoveBone m
				)
				
			--	format "% Bones where removed from %.%
			--     " unusedBones.numberSet obj.name m.name
			)
		)
	)
)