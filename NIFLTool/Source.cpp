//--------------------------------------------------
// Source.cpp
//--------------------------------------------------
#include "stdafx.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <math.h>
#include <float.h>
#include "common.h"
#include "NIFL.h"
#include "VTBF.h"
#include "AQN.h"
#include "AQO.h"
#include "AQM.h"
#include "TEXT.h"
#include "UNK.h"

//--------------------------------------------------
// メイン
//--------------------------------------------------
int main(int argc,char *argv[]){

	bool mode_help = false;
	bool mode_display = false;
	bool mode_suke = false;
	bool mode_alpha = false;
	bool mode_removegroup = false;
	bool mode_vtbf = false;
	bool mode_meshonly = false;
	bool mode_test = false;
	bool mode_unrm = false;
	unsigned int removegroup_index = 0;
	unsigned int sukeref = 128;
	char *obj = NULL;
	char *fbx = NULL;
	char *import_obj = NULL;
	char *import_aqo = NULL;
	char *import_vtbf = NULL;
	char *replace_src = NULL, *replace_dest = NULL;
	char *replace_texf = NULL;
	struct _position {
		bool flag;
		float x, y, z;
	} move, rotate, scale;
	memset(&move, 0x00, sizeof(move));
	memset(&rotate, 0x00, sizeof(rotate));
	memset(&scale, 0x00, sizeof(scale));

	// コマンドライン解析
	unsigned int count=0;
	for(int i=1;i<argc;i++){
		if(argv[i][0] == '-' || argv[i][0] == '/'){
			if(!_stricmp(&argv[i][1], "help")){
				mode_help = true;
			}
			if(!_stricmp(&argv[i][1], "display")){
				mode_display = true;
			}
			if(!_stricmp(&argv[i][1], "alpha")){
				mode_alpha = true;
			}
			if(!_stricmp(&argv[i][1], "suke")){
				mode_suke = true;
			}
			if(!_stricmp(&argv[i][1], "sukeref")){
				if(i + 1 < argc) sukeref = (unsigned int)atoi(argv[++i]);
			}
			if(!_stricmp(&argv[i][1], "obj")){
				if(i + 1 < argc) obj = argv[++i];;
			}

			if(!_stricmp(&argv[i][1], "fbx")){
				if(i + 1 < argc) fbx = argv[++i];;
			}

			if(!_stricmp(&argv[i][1], "unrm")){
				mode_unrm = true;
			}
			if(!_stricmp(&argv[i][1], "removegroup")){
				if(i + 1 < argc){
					mode_removegroup = true;
					removegroup_index = atoi(argv[++i]);
				}
			}
			if(!_stricmp(&argv[i][1], "importobj")){
				if(i + 1 < argc) import_obj = argv[++i];;
			}
			if(!_stricmp(&argv[i][1], "importaqo")){
				if(i + 1 < argc) import_aqo = argv[++i];;
			}
			if(!_stricmp(&argv[i][1], "importvtbf")){
				if(i + 1 < argc) import_vtbf = argv[++i];;
			}
			if(!_stricmp(&argv[i][1], "meshonly")){
				mode_meshonly = true;
			}
			if(!_stricmp(&argv[i][1], "texf")){
				if(i + 1 < argc) replace_texf = argv[++i];;
			}
			if(!_stricmp(&argv[i][1], "test")){
				mode_test = true;
			}
			if(!_stricmp(&argv[i][1], "rotate")){
				if(i + 1 < argc){ i++; rotate.x = (float)(atof(argv[i])); rotate.flag = true; }
				if(i + 1 < argc){ i++; rotate.y = (float)(atof(argv[i])); rotate.flag = true; }
				if(i + 1 < argc){ i++; rotate.z = (float)(atof(argv[i])); rotate.flag = true; }
			}
			if(!_stricmp(&argv[i][1], "scale")){
				if(i + 1 < argc){ i++; scale.x = (float)(atof(argv[i])); scale.flag = true; }
				if(i + 1 < argc){ i++; scale.y = (float)(atof(argv[i])); scale.flag = true; }
				if(i + 1 < argc){ i++; scale.z = (float)(atof(argv[i])); scale.flag = true; }
			}
			if(!_stricmp(&argv[i][1], "move")){
				if(i + 1 < argc){ i++; move.x = (float)atof(argv[i]); }
				if(i + 1 < argc){ i++; move.y = (float)atof(argv[i]); }
				if(i + 1 < argc){ i++; move.z = (float)atof(argv[i]); move.flag = true; }
			}
			if(!_stricmp(&argv[i][1], "replace") || !_stricmp(&argv[i][1], "r")){
				if(i + 1 < argc){ i++; replace_src = argv[i]; }
				if(i + 1 < argc){ i++; replace_dest = argv[i]; }
			}
		}
		else if(*argv[i]){
			argv[++count] = argv[i];
		}
	}

	if(count < 1 || mode_help){
		printf("NIFL ver.0.11 Build: %s %s\n", __DATE__, __TIME__);
		printf("rats_online\n");
		printf("\n");
		printf("nifl.exe [options] [input] ([output])\n");
		printf("options\n");
	//	printf("	-display 解析情報を表示する\n");
		printf("	-display model info \n");
		printf("	-replace [src] [dest] 文字列の置換(部分一致)\n");
		printf("	-move [x] [y] [z] 全ての頂点座標を移動させる(AQO用)\n");
		printf("	-scale [x] [y] [z] 拡大・縮小させる(AQO用)\n");
		printf("	-rotate [x] [y] [z] n度回転させる(AQO用)\n");
		printf("	-suke 全てのグループで透過できるようにする(AQO用)\n");
		printf("	-sukeref [n] 透過する閾値を設定する。小さくすればより透明にできます。デフォルト=128(AQO用)\n");
		printf("	-alpha 全てのグループでalphaチャンネルを使用する(AQO用)\n");
		printf("	-removegroup [index] グループを削除する(AQO用)\n");
		printf("	-importaqo [file(.aqo)] AQO(NIFL形式)を追加インポートする(AQO用)\n");
		printf("	-importvtbf [file(.aqo)] AQO(VTBF形式)を追加インポートする(AQO用)\n");
		printf("	-importobj [file(.aqo)] OBJ形式を読み込み近似する頂点座標を書き換える(AQO用)\n");
		printf("	-meshonly AQOインポート時にメッシュ情報のみインポートする(AQO用)\n");
		printf("	-texf [str] テクスチャファイル名(pl_body_～)をstr_xxのフォーマットで置換する(AQO用)\n");
		printf("	-unrm UNRM情報を再作成する(AQO用)\n");
		printf("	-obj [file(.obj)] WaveFront OBJ形式でエクスポートする(AQO用)\n");
		printf("	-help ヘルプ\n");
		return 0;
	}

	clNIFL nifl(mode_display);
	clVTBF vtbf(mode_display);

	if(vtbf.LoadFile(argv[1])) mode_vtbf = true;
	if(mode_vtbf == false){
		if(nifl.LoadFile(argv[1]) == false) return -1;
	}

	int sz = strlen(argv[1]);
	char *ext = argv[1] + sz;
	while(*ext != '.' && sz >= 0){
		if(*ext == '\\') break;
		ext--; sz--;
	}
	if(ext == NULL){
		clUNK unk(mode_display);
		unk.LoadNIFL(&nifl);
	}
	else{
		if(!_stricmp(ext, ".aqn")){
			clAQN aqn(mode_display);
			aqn.LoadNIFL(&nifl);
			if(replace_src != NULL) aqn.ReplaceString(replace_src, replace_dest);
			if(count > 1) nifl.NewFile(argv[2]);
			aqn.SaveNIFL(&nifl);
		}
		else if(!_stricmp(ext, ".aqm")){
			//clAQM aqm(mode_display);
			//aqm.LoadNIFL(&nifl);
		}
		else if(!_stricmp(ext, ".aqo")){
			clAQO aqo(mode_display);
			if(mode_vtbf){ aqo.LoadVTBF(&vtbf); }else{ aqo.LoadNIFL(&nifl); }
			if(mode_removegroup) aqo.RemoveGroup(removegroup_index);
			if(import_aqo != NULL){
				clNIFL imp_nifl(false);
				imp_nifl.LoadFile(import_aqo);
				clAQO imp_aqo(false);
				imp_aqo.LoadNIFL(&imp_nifl);
				aqo.ImportAQO(&imp_aqo, mode_meshonly);
			}
			if(import_vtbf != NULL){
				clVTBF imp_vtbf(false);
				imp_vtbf.LoadFile(import_vtbf);
				clAQO imp_aqo(false);
				imp_aqo.LoadVTBF(&imp_vtbf);
				aqo.ImportAQO(&imp_aqo, mode_meshonly);
			}
			if(replace_src != NULL) aqo.ReplaceString(replace_src, replace_dest);
			if(mode_alpha) aqo.SetAlpha();
			if(mode_suke) aqo.SetSukeSuke(sukeref);
			if(move.flag) aqo.MovePosition(move.x, move.y, move.z);
			if(scale.flag){
				if(scale.x) aqo.Scale(scale.x, 'x');
				if(scale.y) aqo.Scale(scale.y, 'y');
				if(scale.z) aqo.Scale(scale.z, 'z');
			}
			if(rotate.flag){
				if(rotate.x) aqo.Rotate(rotate.x, 'x');
				if(rotate.y) aqo.Rotate(rotate.y, 'y');
				if(rotate.z) aqo.Rotate(rotate.z, 'z');
			}
			if(import_obj != NULL) aqo.ImportVertexFromObj(import_obj);

			if(mode_unrm) aqo.RemakeUNRM();
			if(replace_texf) aqo.ReplaceTexfilename(replace_texf);

			if(mode_test) aqo.Test();
			if(obj != NULL) aqo.ExportObj(obj);

			if (fbx != NULL) 
			{
				aqo.ExportFbx(fbx);
			}
			if(count > 1) nifl.NewFile(argv[2]);
			aqo.SaveNIFL(&nifl);
		}
		else if(!_stricmp(ext, ".text") || !_stricmp(ext, ".crc")){
			clTEXT text(mode_display);
			text.LoadNIFL(&nifl);
		}
		else{
			clUNK unk(mode_display);
			unk.LoadNIFL(&nifl);
		}
	}

	return 0;
}
