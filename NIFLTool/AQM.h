//--------------------------------------------------
// AQM.h
//--------------------------------------------------
#pragma once

class clAQM{
public:
	clAQM(bool display=false);
	~clAQM();
	bool LoadNIFL(clNIFL *nifl);

private:
	#pragma pack(1)
	struct stAQM {
		unsigned int _reserve;			// 
	};
	#pragma pack()

	bool mode_display;
};
