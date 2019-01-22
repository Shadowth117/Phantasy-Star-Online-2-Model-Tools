//--------------------------------------------------
// VTBF.cpp
//--------------------------------------------------
#include "stdafx.h"
#define _VTBF_
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <math.h>
#include <locale.h>
#include <float.h>
#include "common.h"
#include "VTBF.h"

//--------------------------------------------------
// コンストラクタ/デストラクタ
//--------------------------------------------------
clVTBF::clVTBF(bool display): fp(NULL), offset_0(0), magic_d(NULL), filename(NULL)
{
	mode_display = display;
}

clVTBF::~clVTBF(){
	Release();
}

//--------------------------------------------------
// 開放
//--------------------------------------------------
void clVTBF::Release(void){
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
bool clVTBF::LoadFile(const char *file){

	filename = new char[strlen(file) + 1];
	memset(filename, 0x00, strlen(file) + 1);
	strcpy_s(filename, strlen(file) + 1, file);

	if(fopen_s(&fp, filename, "r+b")){
		printf("Error: (VTBF) File can't open. input=[%s]\n", filename);
		Release();
		return false;
	}

	// magic判定
	unsigned int magic = 0;
	fread(&magic, sizeof(magic), 1, fp);
	if(magic == 0x46425456){
		offset_0 = 0x0000;
	}
	else{
		fread(&magic, sizeof(magic), 1, fp);
		if(magic == 0x46425456){
			offset_0 = 0x04;
		}
		else{
			offset_0 = 0x60;
		}
	}

	if(offset_0){
		magic_d = new unsigned char [offset_0];
		memset(magic_d, 0x00, offset_0);
		fseek(fp, 0, SEEK_SET);
		fread(magic_d, offset_0, 1, fp);
	}

	fseek(fp, offset_0, SEEK_SET);
	unsigned int sig = 0;
	fread(&sig, sizeof(sig), 1, fp);
	if(sig != 0x46425456){ // VTBF
		Release();
		return false;
	}

	fseek(fp, offset_0, SEEK_SET);
	stVTBF_header h;
	memset(&h, 0x00, sizeof(h));
	fread(&h, sizeof(h), 1, fp);
	if(h.subChunkType == 0x46475141){ // AQGF
		fseek(fp, 0x04, SEEK_CUR);
	}

	return true;
}

//--------------------------------------------------
// ヘッダ読み込み
//--------------------------------------------------
unsigned int clVTBF::ReadHeader(stVTBF_header *h){

	memset(h, 0x00, sizeof(stVTBF_header));
	fread(h, sizeof(stVTBF_header), 1, fp);

	if(feof(fp) || ferror(fp)) return 0;

	return h->subChunkType;
}

//--------------------------------------------------
// データ読み込み
//--------------------------------------------------
unsigned char *clVTBF::ReadData(stVTBF_header *h, unsigned short *h1, unsigned short *h2){
	fread(h1, sizeof(unsigned short), 1, fp);
	fread(h2, sizeof(unsigned short), 1, fp);
	unsigned int buf_size = h->chunkSize - 4 - sizeof(unsigned short) * 2;
	unsigned char *buf = new unsigned char[buf_size];
	memset(buf, 0x00, buf_size);
	fread(buf, buf_size, 1, fp);
	return buf;
}

//--------------------------------------------------
// スキップ
//--------------------------------------------------
bool clVTBF::Skip(stVTBF_header *h){
	fseek(fp, -4, SEEK_CUR);
	fseek(fp, h->chunkSize, SEEK_CUR);
	return true;
}

void clVTBF::GetUINT(unsigned char *buf, unsigned int *pos, unsigned int *result){
	memcpy(result, buf + *pos + 2, sizeof(unsigned int));
	*pos = *pos + 2 + sizeof(unsigned int);
}
void clVTBF::GetUINT_Array(unsigned char *buf, unsigned int *pos, unsigned int *result){
	unsigned int count = 0;
	if(*(buf + *pos + 2) == 0x08){
		count = *(buf + *pos + 3);
		*pos += 2 + 1 + 1;
	}
	else if(*(buf + *pos + 2) == 0x10){
		count = *(buf + *pos + 3) + (*(buf + *pos + 4)<<8);
		*pos += 2 + 1 + 2;
	}
	else{
		count = *(buf + *pos + 3) + (*(buf + *pos + 4)<<8) + (*(buf + *pos + 5)<<16) + (*(buf + *pos + 6)<<24);
		*pos += 2 + 1 + 4;
	}
	memcpy(result, buf + *pos, sizeof(unsigned int) * (count + 1));
	*pos = *pos + sizeof(unsigned int) * (count + 1);
}
void clVTBF::GetUCHAR(unsigned char *buf, unsigned int *pos, unsigned char *result){
	unsigned int sz = *(buf + *pos + 2);
	memcpy(result, buf + *pos + 3, sz);
	*pos = *pos + 3 + sz;
}
void clVTBF::GetCHAR(unsigned char *buf, unsigned int *pos, char *result){
	unsigned int sz = *(buf + *pos + 2);
	memcpy(result, buf + *pos + 3, sz);
	*pos = *pos + 3 + sz;
}
void clVTBF::GetUSHORT_Array(unsigned char *buf, unsigned int *pos, unsigned short *result){
	unsigned int count = 0;
	if(*(buf + *pos + 2) == 0x08){
		count = *(buf + *pos + 3);
		*pos += 2 + 1 + 1;
	}
	else if(*(buf + *pos + 2) == 0x10){
		count = *(buf + *pos + 3) + (*(buf + *pos + 4)<<8);
		*pos += 2 + 1 + 2;
	}
	else{
		count = *(buf + *pos + 3) + (*(buf + *pos + 4)<<8) + (*(buf + *pos + 5)<<16) + (*(buf + *pos + 6)<<24);
		*pos += 2 + 1 + 4;
	}
	memcpy(result, buf + *pos, sizeof(unsigned short) * (count + 1));
	*pos = *pos + sizeof(unsigned short) * (count + 1);
}
