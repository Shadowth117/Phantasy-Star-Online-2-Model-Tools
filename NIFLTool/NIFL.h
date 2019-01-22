//--------------------------------------------------
// NIFL.h
//--------------------------------------------------
#pragma once

class clNIFL{
public:
	clNIFL(bool display=false);
	~clNIFL();

	#pragma pack(1)
	struct stNIFL_header{
		unsigned int tag;
		unsigned int reserve1;
		unsigned int reserve2;
		unsigned int rel0_offset;
		unsigned int rel0_size;
		unsigned int nof0_offset;
		unsigned int nof0_size;
		unsigned int reserve;
	};
	struct stREL0_header{
		unsigned int tag;
		unsigned int size;
		unsigned int entry_size;
		unsigned int reserve;
	};
	struct stNOF0_header{
		unsigned int tag;
		unsigned int size;
		unsigned int count;
	};
	#pragma pack()

	FILE *fp;
	unsigned int offset_0;
	stNIFL_header nifl_h;
	stREL0_header rel0_h;
	stNOF0_header nof0_h;
	unsigned int *nof0_d;
	unsigned char *magic_d;

	bool LoadFile(const char *file);
	bool NewFile(const char *file);
	bool Truncate(void);
	bool WriteAligned(void);

	bool NIFL_WriteHeader(void);
	bool NIFL_WriteFooter(void);

	bool REL0_WriteHeader(void);
	bool REL0_Read(void *data, const unsigned int size);
	bool REL0_Write(void *data, const unsigned int size);
	unsigned int REL0_Tell(void);
	bool REL0_Seek(const unsigned int offset);
	unsigned int REL0_GetRealOffset(void);
	void REL0_SetEntry(void);
	void REL0_SetSize(void);
	bool REL0_IsUTF16(void);
	unsigned int REL0_GetEntry(void);
	unsigned int REL0_Length_UTF16(void);
	unsigned int REL0_Length(void);

	bool NOF0_WriteHeader(void);
	bool NOF0_Write(const unsigned int n);
	void NOF0_SetOffset(void);
	void NOF0_SetCount(unsigned int count);
	void NOF0_SetSize(void);
	unsigned int NOF0_GetCount(void);
	unsigned int NOF0_GetOffset(void);

private:
	bool mode_display;
	char *filename;
	void Release(void);
};
