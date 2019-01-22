//--------------------------------------------------
// AQN.h
//--------------------------------------------------
#pragma once

class clAQN{
public:
	clAQN(bool display=false);
	~clAQN();
	bool LoadNIFL(clNIFL *nifl);
	bool SaveNIFL(clNIFL *nifl);
	void ReplaceString(const char *src, const char *dest);

private:
	#pragma pack(1)
	struct stAQN {
		unsigned int count;
		unsigned int offset;
		unsigned char reserve1[sizeof(unsigned int)*2];
		unsigned char reserve2[0x10];
	};
	struct stNODE {
		unsigned int _03;				// 03-09
		unsigned int unk_01;			// ??
		unsigned int bone_parent;		// 04-08
		unsigned int _0f;				// 0f-08

		unsigned int _05;				// 05-08
		unsigned int _06;				// 06-08
		unsigned int unk_02;			// ??
		unsigned int unk_03;			// ??

		unsigned char _07[16];			// 07-4a-xx

		unsigned char _08[16];			// 08-4a-xx

		unsigned char _09[16];			// 09-4a-xx

		unsigned char bone_matrix[64];	// 0a-ca-xx-xx
		char bone_name[32];				// 0d-02
	};
	#pragma pack()

	bool mode_display;
	stAQN aqn;
	stNODE *node;

	void Release(void);
};
