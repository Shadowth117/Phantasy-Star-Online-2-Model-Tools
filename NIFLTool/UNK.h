//--------------------------------------------------
// UNK.h
//--------------------------------------------------
#pragma once

class clUNK{
public:
	clUNK(bool display=false);
	~clUNK();
	bool LoadNIFL(clNIFL *nifl);
	//bool SaveNIFL(clNIFL *nifl);
	//void ReplaceString(const char *src, const char *dest);

private:
	#pragma pack(1)
	#pragma pack()

	bool mode_display;
	void Release(void);
};
