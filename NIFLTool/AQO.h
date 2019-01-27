//--------------------------------------------------
// AQO.h
//--------------------------------------------------
#pragma once

class clAQO{
public:
	clAQO(bool display=false);
	~clAQO();
	bool LoadNIFL(clNIFL *nifl);
	bool SaveNIFL(clNIFL *nifl);
	void WriteMTL(FILE * fpw_mtl);
	bool LoadVTBF(clVTBF *vtbf);
	bool ExportObj(const char *filename);

	bool ExportFbx(const char *filename);

	void MovePosition(const float x, const float y, const float z);
	void Rotate(const float r, const char xyz);
	void Scale(const float s, const char xyz);
	void ReplaceString(const char *src, const char *dest);
	void SetSukeSuke(unsigned int sukeref);
	void SetAlpha(void);
	bool ImportVertexFromObj(const char *filename);
	bool ImportAQO(clAQO *aqo, const bool meshonly=false);
	void RemoveGroup(const unsigned int delete_index);
	void HalfUV(const float u);
	void Test(void);
	void RemakeUNRM(void);
	void ReplaceTexfilename(const char *dest);

	#pragma pack(1)

	struct stPosition {
		float x;
		float y;
		float z;
	};

	struct stBone {
		float x;
		float y;
		float z;
		float w;
	};

	struct stUV {
		float u;
		float v;
	};

	struct stColor {
		unsigned char b;
		unsigned char g;
		unsigned char r;
		unsigned char a;
	};

	struct stOBJC {
		unsigned int _10;				// 10-08
		unsigned int _11;				// 11-08
		unsigned int _12;				// 12-09
		unsigned int _13;				// 13-08

		unsigned int face_count_total;	// 14-09
		unsigned int _unk_01;			// ??
		unsigned int vtxl_count_total;	// 15-08
		unsigned int _unk_02;			// ??

		unsigned int _16;				// 16-08
		unsigned int vset_count;		// 24-09
		unsigned int vset_offset;		// ??
		unsigned int pset_count;		// 25-09

		unsigned int pset_offset;		// ??
		unsigned int mesh_count;		// 17-09
		unsigned int mesh_offset;		// ??
		unsigned int mate_count;		// 18-08

		unsigned int mate_offset;		// ??
		unsigned int rend_count;		// 19-08
		unsigned int rend_offset;		// ??
		unsigned int shad_count;		// 1A-08

		unsigned int shad_offset;		// ??
		unsigned int tsta_count;		// 1B-08
		unsigned int tsta_offset;		// ??
		unsigned int tset_count;		// 1C-08

		unsigned int tset_offset;		// ??
		unsigned int texf_count;		// 1D-08
		unsigned int texf_offset;		// ??

		unsigned char _1e[48];			// 1E-4A-xx
		unsigned int reserve;			// 00 00 00 00

		unsigned int unrm_offset;		// ??
	};

	struct stVSET {
		unsigned int vert_size;			// B6-09
		unsigned int vtxe_count;		// BF-09
		unsigned int vtxe_offset;		// ok
		unsigned int vtxl_count;		// B9-09

		unsigned int vtxl_offset;		// ok
		unsigned int _unk_02;			// 
		unsigned int bonepalette_count;	// 
		unsigned int bonepalette_offset;// ok

		unsigned int _unk_04;			// 
		unsigned int _unk_05;			// 
		unsigned int _unk_06;			// 
		unsigned int bonepalette2_count;	// count?

		unsigned int bonepalette2_offset;	// Å©32bytesÇÃâΩÇ©ÇÃÉfÅ[É^Ç÷ÇÃoffset
	};

	struct stVTXE {
		unsigned int type;
		unsigned int type2;
		unsigned int pos;
		unsigned int reserve;
	};

	struct stMESH {
		unsigned int _b0;				// B0-09
		unsigned int _c7;				// C7-09
		unsigned int mate_index;		// B1-08 MATE index
		unsigned int rend_index;		// B2-08

		unsigned int shad_index;		// B3-08
		unsigned int tset_index;		// B4-08
		unsigned int _b5;				// B5-08 Rigid Rig Bone and ? on weighted meshes
		unsigned int _c0;				// C0-08

		unsigned int _c1;				// C1-08
		unsigned int _cd;				// CD-08
		unsigned int _c2;				// C2-09
		unsigned int reserve;			// 00 00 00 00
	};

	struct stMATE {
		unsigned char _30[16];			// 30-4A-02
		unsigned char _31[16];			// 31-4A-02
		unsigned char _32[16];			// 32-4A-02
		unsigned char _33[16];			// 33-4A-02

		unsigned int _34;				// 34-09
		unsigned int _35;				// 35-0A
		unsigned int _36;				// 36-0A
		unsigned int _37;				// 37-09

		unsigned int _38;				// 38-09
		char _3a[32];					// 3A-02
		char _39[32];					// 39-02
	};

	struct stREND {
		unsigned int _40;				// 40-09
		unsigned int _41;				// 41-09
		unsigned int _42;				// 42-09
		unsigned int _43;				// 43-09

		unsigned int _44;				// 44-09
		unsigned int _45;				// 45-09
		unsigned int _46;				// 46-09
		unsigned int _47;				// 47-09

		unsigned int _48;				// 48-09
		unsigned int _49;				// 49-09
		unsigned int _4a;				// 4A-09
		unsigned int _4b;				// 4B-09

		unsigned int _4c;				// 4C-09
		unsigned int _4d;				// 4D-09
		unsigned int _4e;				// 4E-09
		unsigned int _4f;				// 4F-09

		unsigned int _50;				// 50-09
	};

	struct stSHAD {
		unsigned int _90;				// 90-09
		char _91[32];					// 91-02
		char _92[32];					// 92-02
		unsigned int _93;				// 93-09
	};

	struct stTSTA {
		unsigned int _60;				// 60-09
		unsigned int _61;				// 61-09
		unsigned int _62;				// 62-09
		unsigned char _63[12];			// 63-4A-01
		unsigned int _64;				// 64-09
		unsigned int _65;				// 65-09
		unsigned int _66;				// 66-09
		unsigned int _67;				// 67-09
		unsigned int _68;				// 68-09
		unsigned int _69;				// 69-09
		unsigned int _6a;				// 6A-0A
		unsigned int _6b;				// 6B-0A
		char _6c[32];					// 6C-02
	};

	struct stTSET {
		unsigned int _70;				// 70-09
		unsigned int _71;				// 71-08
		unsigned int _72;				// 72-09
		unsigned int _73;				// 73-09

		unsigned int _74;				// 74-09
		//unsigned char _75[16];			// 75-88-08-03?
		unsigned int _75[4];			// 75-88-08-03?
	};

	struct stTEXF {
		char _80[32];					// 80-02
	};

	struct stPSET {
		unsigned int _c6;				// C6-09
		unsigned int _bb;				// BB-09
		unsigned int face_count_offset;	// offset
		unsigned int face_count;		// BC-09

		unsigned int face_data_offset;	// 
		unsigned int reserve;			// 00 00 00 00?
	};

	struct stUNRM {
		unsigned int _u_data1_count;	// DA-09
		unsigned int _u_data1_offset;	// DB-89-xx-yy-yy data
		unsigned int _u_data2_count;	// DC-09
		unsigned int _u_data2a_offset;	// DD-89-10-18-04 data

		unsigned int _u_data2b_offset;	// DE-89-10-18-04 data
	};

	#pragma pack()

	stOBJC *objc;
	stMESH *mesh;
	stMATE *mate;
	stREND *rend;
	stSHAD *shad;
	stTSTA *tsta;
	stTSET *tset;
	stTEXF *texf;
	stUNRM *unrm;
	stPSET *pset;
	unsigned short **face;
	stVSET *vset;
	stVTXE **vtxe;
	unsigned char ***vtxl_buff;
	unsigned short **bonepalette;
	unsigned short **bonepalette2;
	unsigned int **_u_data1;
	unsigned int **_u_data2a;
	unsigned int **_u_data2b;

private:

	bool mode_display;

	stPosition max, min;

	void Release(void);
	void GetPosition_max_min(void);
	void dump_hex(unsigned char **buf, unsigned int pos, unsigned int count, unsigned int size);
	void dump_pos(unsigned char **buf, unsigned int pos, unsigned int count);
	void dump_uv(unsigned char **buf, unsigned int pos, unsigned int count);
	void dump_float(unsigned char **buf, unsigned int pos, unsigned int count, unsigned int ary_size);
	void dump_ubyte(unsigned char **buf, unsigned int pos, unsigned int count, unsigned int ary_size);
	void show_vtxe_header(const char *str, unsigned int index, stVTXE vtxe);
};
