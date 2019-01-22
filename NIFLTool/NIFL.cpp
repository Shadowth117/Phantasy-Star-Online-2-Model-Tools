//--------------------------------------------------
// NIFL.cpp
//--------------------------------------------------
#include "stdafx.h"
#define _NIFL_
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <math.h>
#include <locale.h>
#include <float.h>
#include "common.h"
#include "NIFL.h"

//--------------------------------------------------
// コンストラクタ/デストラクタ
//--------------------------------------------------
clNIFL::clNIFL(bool display): fp(NULL), offset_0(0), magic_d(NULL), nof0_d(NULL), filename(NULL)
{
	mode_display = display;
	memset(&nifl_h, 0x00, sizeof(nifl_h));
	memset(&rel0_h, 0x00, sizeof(rel0_h));
	memset(&nof0_h, 0x00, sizeof(nof0_h));
}

clNIFL::~clNIFL(){
	Release();
}

//--------------------------------------------------
// 開放
//--------------------------------------------------
void clNIFL::Release(void){
	if(nof0_d != NULL){
		delete [] nof0_d;
		nof0_d = NULL;
	}
	if(magic_d != NULL){
		delete [] magic_d;
		magic_d = NULL;
	}
	if(fp != NULL){
		fclose(fp);
		fp = NULL;
	}
	if(filename != NULL){
		delete [] filename;
		filename = NULL;
	}
}

//--------------------------------------------------
// 読み込み
//--------------------------------------------------
bool clNIFL::LoadFile(const char *file){

	filename = new char[strlen(file) + 1];
	memset(filename, 0x00, strlen(file) + 1);
	strcpy_s(filename, strlen(file) + 1, file);

	if(fopen_s(&fp, filename, "r+b")){
		printf("Error: (NIFL) File can't open. input=[%s]\n", filename);
		Release();
		return false;
	}

	// magic判定
	unsigned int magic = 0;
	fread(&magic, sizeof(magic), 1, fp);
	if(magic == 0x4c46494e){
		offset_0 = 0x0000;
	}
	else{
		fread(&magic, sizeof(magic), 1, fp);
		if(magic == 0x4c46494e){
			offset_0 = 0x04;
		}
		else{
			offset_0 = 0x60;
		}
	}

	unsigned int offset;

	// NIFL
	offset = offset_0;
	fseek(fp, offset, SEEK_SET);
	fread(&nifl_h, sizeof(nifl_h), 1, fp);
	printf_d(mode_display, "***** NIFL *****\n");
	printf_d(mode_display, "offset      = [%08X]\n", offset);
	printf_d(mode_display, "size        = [%08X] (%d)\n", sizeof(nifl_h), sizeof(nifl_h));
	printf_d(mode_display, "\n");
	printf_d(mode_display, "tag         = [%08X]\n", nifl_h.tag);
	printf_d(mode_display, "reserve1    = [%08X]\n", nifl_h.reserve1);
	printf_d(mode_display, "reserve2    = [%08X]\n", nifl_h.reserve2);
	printf_d(mode_display, "REL0 offset = [%08X]\n", nifl_h.rel0_offset);
	printf_d(mode_display, "REL0 size   = [%08X]\n", nifl_h.rel0_size);
	printf_d(mode_display, "NOF0 offset = [%08X]\n", nifl_h.nof0_offset);
	printf_d(mode_display, "NOF0 size   = [%08X]\n", nifl_h.nof0_size);
	printf_d(mode_display, "reserve3    = [%08X]\n", nifl_h.reserve);
	printf_d(mode_display, "\n");

	if(nifl_h.tag != 0x4c46494e){
		printf("Error: NIFL tag expected.\n");
		return false;
	}

	if(offset_0){
		magic_d = new unsigned char [offset_0];
		memset(magic_d, 0x00, offset_0);
		fseek(fp, 0, SEEK_SET);
		fread(magic_d, offset_0, 1, fp);
	}

	// REL0
	offset = offset_0 + nifl_h.rel0_offset;
	fseek(fp, offset, SEEK_SET);
	fread(&rel0_h, sizeof(rel0_h), 1, fp);
	printf_d(mode_display, "***** REL0 *****\n");
	printf_d(mode_display, "offset      = [%08X]\n", offset);
	printf_d(mode_display, "size        = [%08X] (%d)\n", sizeof(rel0_h), sizeof(rel0_h));
	printf_d(mode_display, "\n");
	printf_d(mode_display, "tag         = [%08X]\n", rel0_h.tag);
	printf_d(mode_display, "size        = [%08X]\n", rel0_h.size);
	printf_d(mode_display, "entry       = [%08X]\n", rel0_h.entry_size);
	printf_d(mode_display, "reserve     = [%08X]\n", rel0_h.reserve);
	printf_d(mode_display, "\n");
	if(rel0_h.tag != 0x304c4552){
		printf("Error: REL0 tag expected.\n");
		return false;
	}

	// NOF0
	offset = offset_0 + nifl_h.nof0_offset;
	fseek(fp, offset, SEEK_SET);
	fread(&nof0_h, sizeof(nof0_h), 1, fp);
	printf_d(mode_display, "***** NOF0 *****\n");
	printf_d(mode_display, "offset      = [%08X]\n", offset);
	printf_d(mode_display, "size        = [%08X] (%d)\n", sizeof(nof0_h), sizeof(nof0_h));
	printf_d(mode_display, "\n");
	printf_d(mode_display, "<header>\n");
	printf_d(mode_display, "tag         = [%08X]\n", nof0_h.tag);
	printf_d(mode_display, "size        = [%08X]\n", nof0_h.size);
	printf_d(mode_display, "count       = [%08X]\n", nof0_h.count);
	printf_d(mode_display, "\n");
	if(nof0_h.tag != 0x30464f4e){
		printf("Error: NOF0 tag expected.\n");
		return false;
	}

	nof0_d = new unsigned int [nof0_h.count + 1];
	memset(nof0_d, 0x00, sizeof(unsigned int) * (nof0_h.count + 1));
	fread(nof0_d, sizeof(unsigned int) * (nof0_h.count + 1), 1, fp);
	printf_d(mode_display, "<data>\n");
	printf_d(mode_display, "index   data     +20h        value\n");
	for(unsigned int i=0;i<=nof0_h.count;i++){
		printf_d(mode_display, "%02X(%02d): ", i, i);
		//unsigned int n = (unsigned int)(*(nof0_d + i * 4) + (*(nof0_d + i * 4 + 1) << 8) + (*(nof0_d + i * 4 + 2) << 16) + (*(nof0_d + i * 4 + 3) << 24));
		offset = offset_0 + nifl_h.rel0_offset + nof0_d[i];
		fseek(fp, offset, SEEK_SET);
		unsigned int r;
		fread(&r, sizeof(r), 1, fp);
		printf_d(mode_display, "%08X ", nof0_d[i]);
		if(nof0_d[i] > 0x10)
			printf_d(mode_display, "%08X -> %08X", offset, r);
		printf_d(mode_display, "\n");
	}

	return true;
}

unsigned int clNIFL::REL0_GetRealOffset(void){
	return offset_0 + nifl_h.rel0_offset;
}

void clNIFL::REL0_SetEntry(void){
	rel0_h.entry_size = ftell(fp) - offset_0 - nifl_h.rel0_offset;
}

unsigned int clNIFL::REL0_GetEntry(void){
	return rel0_h.entry_size;
}

unsigned int clNIFL::REL0_Tell(void){
	return ftell(fp) - offset_0 - nifl_h.rel0_offset;
}

bool clNIFL::REL0_Seek(const unsigned int offset){
	fseek(fp, offset_0 + nifl_h.rel0_offset + offset, SEEK_SET);
	return true;
}

void clNIFL::NOF0_SetCount(unsigned int count){
	nof0_h.count = count;
}

void clNIFL::NOF0_SetOffset(void){
	nifl_h.nof0_offset = ftell(fp) - offset_0;
}

void clNIFL::NOF0_SetSize(void){
	nifl_h.nof0_size = ftell(fp) - offset_0 - nifl_h.nof0_offset;
	nof0_h.size = nifl_h.nof0_size - sizeof(stNOF0_header);
}

void clNIFL::REL0_SetSize(void){
	nifl_h.rel0_size = ftell(fp) - offset_0 - nifl_h.rel0_offset;
	rel0_h.size = nifl_h.rel0_size - sizeof(stREL0_header) + 0x08;
}

bool clNIFL::NOF0_Write(const unsigned int n){
	fwrite(&n, sizeof(n), 1, fp);
	nof0_h.count++;
	return true;
}

bool clNIFL::NIFL_WriteFooter(void){
	const char *nend = "NEND\x08";
	fwrite(nend, 5, 1, fp);
	return true;
}

bool clNIFL::NIFL_WriteHeader(void){
	fseek(fp, 0, SEEK_SET);
	if(offset_0) fwrite(magic_d, offset_0, 1, fp);
	nifl_h.tag = 0x4c46494e;
	nifl_h.reserve1 = 0x00000018;
	nifl_h.reserve2 = 0x00000001;
	nifl_h.rel0_offset = sizeof(nifl_h);
	fwrite(&nifl_h, sizeof(nifl_h), 1, fp);
	return true;
}

bool clNIFL::REL0_WriteHeader(void){
	unsigned int offset = nifl_h.rel0_offset + offset_0;
	fseek(fp, offset, SEEK_SET);
	rel0_h.tag = 0x304c4552;
	rel0_h.entry_size = sizeof(rel0_h);
	fwrite(&rel0_h, sizeof(rel0_h), 1, fp);
	return true;
}

bool clNIFL::NOF0_WriteHeader(void){
	unsigned int offset = nifl_h.nof0_offset + offset_0;
	fseek(fp, offset, SEEK_SET);
	nof0_h.tag = 0x30464f4e;
	fwrite(&nof0_h, sizeof(nof0_h), 1, fp);
	return true;
}

bool clNIFL::REL0_Read(void *data, const unsigned int size){
	fread(data, size, 1, fp);
	return true;
}

bool clNIFL::REL0_IsUTF16(void){
	setlocale(LC_CTYPE, "jpn");
	unsigned int t = ftell(fp);
	wchar_t wc[0x10]; memset(&wc, 0x00, sizeof(wc));
	bool utf16_flag = true;
	while(fread(&wc, sizeof(wchar_t), 1, fp) > 0){
		if(wc[0] == 0x0000){
			break;
		}
		char mc[0x10]; memset(mc, 0x00, sizeof(mc));
		unsigned int num = 0;
		if(wcstombs_s(&num, mc, sizeof(mc), wc, sizeof(wchar_t)) == -1){
			utf16_flag = false;
			break;
		}
		wchar_t wc2[0x10]; memset(wc2, 0x00, sizeof(wc2));
		if(mbstowcs_s(&num, wc2, 0x10, mc, _TRUNCATE) == -1){
			utf16_flag = false;
			break;
		}
		if(memcmp(wc, wc2, sizeof(wchar_t))){
			utf16_flag = false;
			break;
		}
		if(wcslen(wc2) != 1){
			utf16_flag = false;
			break;
		}
	}
	fseek(fp, t, SEEK_SET);
	return utf16_flag;
}

unsigned int clNIFL::REL0_Length_UTF16(void){
	unsigned int len = 0;
	unsigned int t = ftell(fp);
	wchar_t wc; memset(&wc, 0x00, sizeof(wc));
	while(fread(&wc, sizeof(wchar_t), 1, fp) > 0){
		if(wc == 0x0000){
			break;
		}
		len++;
	}
	fseek(fp, t, SEEK_SET);
	return len;
}

unsigned int clNIFL::REL0_Length(void){
	unsigned int len = 0;
	unsigned int t = ftell(fp);
	char c = 0;
	while(fread(&c, sizeof(char), 1, fp) > 0){
		if(c == 0x00){
			break;
		}
		len++;
	}
	fseek(fp, t, SEEK_SET);
	return len;
}

bool clNIFL::REL0_Write(void *data, const unsigned int size){
	fwrite(data, size, 1, fp);
	return true;
}

bool clNIFL::WriteAligned(void){
	unsigned int pos = ftell(fp) - offset_0;
	unsigned int a = Aligned(pos, 0x10) - pos;
	if(a > 0){
		for(unsigned int i=0;i<a;i++) putc(0x00, fp);
	}
	return true;
}

bool clNIFL::Truncate(void){

	if(fp != NULL){
		fclose(fp);
		fp = NULL;
	}

	if(filename == NULL) return false;

	if(fopen_s(&fp, filename, "w+b")){
		printf("Error: (NIFL) File can't open. input=[%s]\n", filename);
		Release();
		return false;
	}
	return true;
}

bool clNIFL::NewFile(const char *file){
	if(fp != NULL){
		fclose(fp);
		fp = NULL;
	}
	
	if(filename != NULL) delete [] filename;

	filename = new char[strlen(file) + 1];
	memset(filename, 0x00, strlen(file) + 1);
	strcpy_s(filename, strlen(file) + 1, file);

	if(fopen_s(&fp, filename, "w+b")){
		printf("Error: (NIFL) File can't open. input=[%s]\n", filename);
		Release();
		return false;
	}
	return true;
}

unsigned int clNIFL::NOF0_GetCount(void){
	return nof0_h.count;
}
