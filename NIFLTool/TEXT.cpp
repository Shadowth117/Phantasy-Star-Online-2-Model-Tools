//--------------------------------------------------
// TEXT.cpp
//--------------------------------------------------
#include "stdafx.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <locale.h>
#include "NIFL.h"
#include "TEXT.h"
#include "common.h"

//--------------------------------------------------
// コンストラクタ/デストラクタ
//--------------------------------------------------
clTEXT::clTEXT(bool display){
	mode_display = display;
}
clTEXT::~clTEXT(){
	Release();
}

//--------------------------------------------------
// 開放
//--------------------------------------------------
void clTEXT::Release(void){
}

//--------------------------------------------------
// 読み込み
//--------------------------------------------------
bool clTEXT::LoadNIFL(clNIFL *nifl){

	setlocale(LC_CTYPE, "jpn");
	unsigned int offset_s = nifl->nof0_d[0], offset_e = 0;

	unsigned int entry_start = nifl->REL0_GetEntry() + 0x08;
	unsigned int entry_end = nifl->nifl_h.nof0_offset - sizeof(nifl->nifl_h);

	bool pair_mode = false;
	int even = -1;

	for(unsigned int i=1;i<=nifl->NOF0_GetCount();i++){
		offset_e = nifl->nof0_d[i];
		unsigned int count = (offset_e - offset_s) / 4;
		unsigned int *ary = new unsigned int[count];
		memset(ary, 0x00, sizeof(unsigned int) * count);
		nifl->REL0_Seek(offset_s);
		nifl->REL0_Read(ary, sizeof(unsigned int) * count);
		if(ary[0] == 0xffffffff){
			pair_mode = true;
			even = 0;
		}
		else{
			if(pair_mode && count != 1)
				pair_mode = false;
			if(ary[0] == 0x00000014){
				pair_mode = false;
				even = -1;
				delete [] ary;
				break;
			}
			for(unsigned int j=0;j<count;j++){
				if(ary[j] >= entry_start && ary[j] < entry_end){
					nifl->REL0_Seek(ary[j]);
					if(nifl->REL0_IsUTF16() && even){
						unsigned int len = nifl->REL0_Length_UTF16();
						wchar_t *utf16 = new wchar_t[len + 1];
						memset(utf16, 0x00, sizeof(wchar_t) * (len + 1));
						nifl->REL0_Read(utf16, sizeof(wchar_t) * len);
						char *buf = new char[len * 2 + 1];
						memset(buf, 0x00, len * 2 + 1);
						unsigned int num = 0;
						wcstombs_s(&num, buf, len * 2 + 1, utf16, _TRUNCATE);
						printf("%s", buf);
						delete [] buf;
						delete [] utf16;
					}
					else{
						unsigned int len = nifl->REL0_Length();
						char *buf = new char[len + 1];
						memset(buf, 0x00, sizeof(char) * (len + 1));
						nifl->REL0_Read(buf, sizeof(char) * len);
						printf("%s", buf);
						delete [] buf;
					}
				}
				else{
					printf("[%08X]", ary[j]);
				}
			}

			if(pair_mode){
				if(!even){
					printf(": ");
				}
				else{
					printf("\n");
				}
				even = even ^ 1;
			}
			else{
				printf("\n");
			}
		}

		delete [] ary;
		offset_s = offset_e;
	}

	return true;
}

