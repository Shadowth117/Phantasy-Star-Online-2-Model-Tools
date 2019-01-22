//--------------------------------------------------
// common.cpp
//--------------------------------------------------
#include "stdafx.h"
#define _COMMON_
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "nifl.h"
#include "common.h"


//--------------------------------------------------
// printfのオーバーラップ関数
//--------------------------------------------------
void printf_d(const bool display, const char* format, ...){
	if(display == false){
		return;
	}
	va_list arg;
	va_start(arg, format);
	vprintf_s(format, arg);
	va_end(arg);
}

//--------------------------------------------------
// dump
//--------------------------------------------------
void dump(const bool display, unsigned char *buf, unsigned int size){
	if(display == false) return;
	unsigned int j = 0;
	for(unsigned int i=0;i<size;i++){
		if(!j){
			printf_d(display, "%08X: ", i);
		}
		printf_d(display, "%02X ", (unsigned char)(*(buf + i)));
		if(j++ == 15){
			printf_d(display, "\n"); j = 0;
		}
	}
	if(j){
		printf_d(display, "\n");
	}
	return;
}

//--------------------------------------------------
// strlen_fp
//--------------------------------------------------
int strlen_fp(FILE *fp, unsigned int char_size){
	int sz = 0;
	char buf[16];
	char zero[16]; memset(zero, 0x00, sizeof(zero));
	while(fread(buf, char_size, 1, fp)){
		if(!memcmp(buf, zero, char_size)){
			break;
		}
		sz += char_size;
	}
	fseek(fp, ((sz + char_size) * -1), SEEK_CUR);
	return sz;
}

//--------------------------------------------------
// 文字列置換
//--------------------------------------------------
int strchg(char *buf, size_t buf_size, const char *str1, const char *str2){
	char *tmp;
	char *p;
	int count = 0;

	while((p = strstr(buf, str1)) != NULL){
		size_t sz = buf_size + strlen(str2);
		tmp = new char[sz];
		*p = '\0';
		p += strlen(str1);
		strcpy_s(tmp, sz, p);
		strcat_s(buf, buf_size, str2);
		strcat_s(buf, buf_size, tmp);
		delete [] tmp;
		count++;
	}

	if(count){
		char *b = new char[buf_size];
		memset(b, 0x00, buf_size);
		strcpy_s(b, buf_size, buf);
		memcpy(buf, b, buf_size);
		delete [] b;
	}

	return count;
}

//--------------------------------------------------
// ファイル名のポインタ
//--------------------------------------------------
char *get_filename_ptr(char *str){
	char *p = str, *r = str;
	while(p != NULL){
		p = strchr(r, '\\');
		if(p != NULL){
			r = p + 1;
		}
	}
	return _strdup(r);
}

char *get_path(const char *buf){
	int sz = strlen(buf) + 1;
	char *result = new char[sz];
	memset(result, 0x00, sz);
	memcpy(result, buf, sz);
	int n = sz - 1;
	char *p = result + sz - 1;
	while(*p != '\\' && n >= 0){
		*p = '\0';
		p--; n--;
	}
	return result;
}
