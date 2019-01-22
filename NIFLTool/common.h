//--------------------------------------------------
// common.h
//--------------------------------------------------
#if defined(_COMMON_)
	#define _COMMON_EXT
#else
	#define _COMMON_EXT extern
#endif

#ifndef _countof
#define _countof(_array) (sizeof(_array)/sizeof(_array[0]))
#endif

#pragma pack(1)
struct stPosition {
	float x;
	float y;
	float z;
};

struct stUV {
	float u;
	float v;
};
#pragma pack()

inline unsigned int Aligned(unsigned int v,unsigned int align){return (v+(align-1))&(-1^(align-1));}

_COMMON_EXT void printf_d(const bool display, const char* format, ...);
_COMMON_EXT void dump(const bool display, unsigned char *buf, unsigned int size);
_COMMON_EXT int strlen_fp(FILE *fp, unsigned int char_size);
_COMMON_EXT int strchg(char *buf, size_t buf_size, const char *str1, const char *str2);
_COMMON_EXT char *get_filename_ptr(char *str);
_COMMON_EXT char *get_path(const char *buf);
