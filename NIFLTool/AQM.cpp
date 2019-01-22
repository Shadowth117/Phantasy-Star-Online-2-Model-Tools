//--------------------------------------------------
// AQM.cpp
//--------------------------------------------------
#include "stdafx.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include "NIFL.h"
#include "AQM.h"
#include "common.h"

//--------------------------------------------------
// コンストラクタ/デストラクタ
//--------------------------------------------------
clAQM::clAQM(bool display){
	mode_display = display;
}
clAQM::~clAQM(){}

//--------------------------------------------------
// AQM
//--------------------------------------------------
bool clAQM::LoadNIFL(clNIFL *nifl){

	printf_d(mode_display, "\n***** AQM *****\n");

	return true;
}
