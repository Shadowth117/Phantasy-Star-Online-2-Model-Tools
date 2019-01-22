//--------------------------------------------------
// AQN.cpp
//--------------------------------------------------
#include "stdafx.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include "NIFL.h"
#include "AQN.h"
#include "common.h"

//--------------------------------------------------
// コンストラクタ/デストラクタ
//--------------------------------------------------
clAQN::clAQN(bool display): node(NULL)
{
	mode_display = display;
	memset(&aqn, 0x00, sizeof(aqn));
}
clAQN::~clAQN(){
	Release();
}

//--------------------------------------------------
// 開放
//--------------------------------------------------
void clAQN::Release(void){
	if(node != NULL) delete [] node;
}

//--------------------------------------------------
// 読み込み
//--------------------------------------------------
bool clAQN::LoadNIFL(clNIFL *nifl){

	printf_d(mode_display, "\n***** AQN *****\n");

	unsigned int offset;

	offset = nifl->REL0_GetEntry();
	nifl->REL0_Seek(offset);
	nifl->REL0_Read(&aqn, sizeof(aqn));

	printf_d(mode_display, "count  = [%08X] (%d)\n", aqn.count, aqn.count);
	printf_d(mode_display, "offset = [%08X]\n", aqn.offset);

	node = new stNODE[aqn.count];

	for(unsigned int i=0;i<aqn.count;i++){

		offset = aqn.offset + sizeof(stNODE) * i;
		nifl->REL0_Seek(offset);
		memset(&node[i], 0x00, sizeof(stNODE));
		nifl->REL0_Read(&node[i], sizeof(stNODE));

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** %04X(%d): %08X *****\n", i, i, offset);
		printf_d(mode_display, "_03         = [%08X] (%d)\n", node[i]._03, node[i]._03);
		printf_d(mode_display, "_unk_01     = [%08X] (%d)\n", node[i].unk_01, node[i].unk_01);
		printf_d(mode_display, "Bone Parent = [%08X] (%d)\n", node[i].bone_parent, node[i].bone_parent);
		printf_d(mode_display, "_0f         = [%08X] (%d)\n", node[i]._0f, node[i]._0f);
		printf_d(mode_display, "_05         = [%08X] (%d)\n", node[i]._05, node[i]._05);
		printf_d(mode_display, "_06         = [%08X] (%d)\n", node[i]._06, node[i]._06);
		printf_d(mode_display, "unk_02      = [%08X] (%d)\n", node[i].unk_02, node[i].unk_02);
		printf_d(mode_display, "unk_03      = [%08X] (%d)\n", node[i].unk_03, node[i].unk_03);
		printf_d(mode_display, "_07         = \n"); dump(mode_display, node[i]._07, sizeof(node[i]._07));
		printf_d(mode_display, "_08         = \n"); dump(mode_display, node[i]._08, sizeof(node[i]._08));
		printf_d(mode_display, "_09         = \n"); dump(mode_display, node[i]._09, sizeof(node[i]._09));
		printf_d(mode_display, "Bone Matrix = \n"); dump(mode_display, node[i].bone_matrix, sizeof(node[i].bone_matrix));
		printf_d(mode_display, "Bone Name   = [%s]\n", node[i].bone_name);
	}

	return true;
}

//--------------------------------------------------
// 保存
//--------------------------------------------------
bool clAQN::SaveNIFL(clNIFL *nifl){

	// ファイルを空にする
	nifl->Truncate();

	// ヘッダ
	nifl->NIFL_WriteHeader();
	nifl->REL0_WriteHeader();

	// 開始オフセット設定
	nifl->REL0_SetEntry();

	nifl->REL0_Write(&aqn, sizeof(stAQN));
	nifl->WriteAligned();
	aqn.offset = nifl->REL0_Tell();

	for(unsigned int i=0;i<aqn.count;i++){
		nifl->REL0_Write(&node[i], sizeof(stNODE));
	}
	nifl->WriteAligned();

	// REL0のサイズ情報更新
	nifl->REL0_SetSize();

	// NOF0生成
	nifl->NOF0_SetOffset();
	nifl->NOF0_SetCount(0);
	nifl->NOF0_WriteHeader();

	nifl->NOF0_Write(nifl->REL0_GetEntry() + 0x04);

	nifl->WriteAligned();
	nifl->NOF0_SetSize();
	nifl->NIFL_WriteFooter();
	nifl->WriteAligned();

	// ヘッダ情報更新
	nifl->NIFL_WriteHeader();
	nifl->REL0_WriteHeader();
	nifl->NOF0_WriteHeader();

	// 変更になったオフセッット情報を更新
	nifl->REL0_Seek(nifl->REL0_GetEntry());
	nifl->REL0_Write(&aqn, sizeof(stAQN));

	return true;
}

//--------------------------------------------------
// 文字列置換
//--------------------------------------------------
void clAQN::ReplaceString(const char *src, const char *dest){
	for(unsigned int i=0;i<aqn.count;i++){
		strchg(node[i].bone_name, sizeof(node[i].bone_name), src, dest);
	}
}
