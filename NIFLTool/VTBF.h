//--------------------------------------------------
// VTBF.h
//--------------------------------------------------
#pragma once

class clVTBF{
public:
	clVTBF(bool display=false);
	~clVTBF();

	#pragma pack(1)
	struct stVTBF_header{
		unsigned int chunkType;
		unsigned int chunkSize;
		unsigned int subChunkType;
	};
	#pragma pack()

	FILE *fp;
	unsigned int offset_0;
	unsigned char *magic_d;

	bool LoadFile(const char *file);
	unsigned int ReadHeader(stVTBF_header *h);
	unsigned char *ReadData(stVTBF_header *h, unsigned short *h1, unsigned short *h2);
	bool Skip(stVTBF_header *h);
	void GetUINT(unsigned char *buf, unsigned int *pos, unsigned int *result);
	void GetUINT_Array(unsigned char *buf, unsigned int *pos, unsigned int *result);
	void GetUCHAR(unsigned char *buf, unsigned int *pos, unsigned char *result);
	void GetCHAR(unsigned char *buf, unsigned int *pos, char *result);
	void GetUSHORT_Array(unsigned char *buf, unsigned int *pos, unsigned short *result);

private:
	bool mode_display;
	char *filename;
	void Release(void);
};
