//--------------------------------------------------
// AQO.cpp
//--------------------------------------------------
#include "stdafx.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <windows.h>
#include <io.h>
#include <fbxsdk.h>
#include "NIFL.h"
#include "VTBF.h"
#include "AQO.h"
#include "common.h"

//--------------------------------------------------
// コンストラクタ/デストラクタ
//--------------------------------------------------
clAQO::clAQO(bool display):
	objc(NULL), mesh(NULL), mate(NULL), rend(NULL), shad(NULL), tsta(NULL), tset(NULL), 
	texf(NULL), unrm(NULL), pset(NULL), face(NULL), vset(NULL), vtxe(NULL), vtxl_buff(NULL),
	bonepalette(NULL), bonepalette2(NULL), _u_data1(NULL), _u_data2a(NULL), _u_data2b(NULL)
{
	mode_display = display;
	memset(&max, 0x00, sizeof(max));
	memset(&min, 0x00, sizeof(min));
}

clAQO::~clAQO(){
	Release();
}

//--------------------------------------------------
// 開放
//--------------------------------------------------
void clAQO::Release(void){

	if(_u_data2b != NULL){
		for(unsigned int i=0;i<1;i++)
			delete [] _u_data2b[i];
		delete [] _u_data2b;
	}

	if(_u_data2a != NULL){
		for(unsigned int i=0;i<1;i++)
			delete [] _u_data2a[i];
		delete [] _u_data2a;
	}

	if(_u_data1 != NULL){
		for(unsigned int i=0;i<1;i++)
			delete [] _u_data1[i];
		delete [] _u_data1;
	}

	if(bonepalette2 != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++)
			delete [] bonepalette2[i];
		delete [] bonepalette2;
	}

	if(bonepalette != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++)
			delete [] bonepalette[i];
		delete [] bonepalette;
	}

	if(vtxl_buff != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++){
			for(unsigned int j=0;j<vset[i].vtxl_count;j++){
				delete [] vtxl_buff[i][j];
			}
			delete [] vtxl_buff[i];
		}
		delete [] vtxl_buff;
	}

	if(vtxe != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++)
			delete [] vtxe[i];
		delete [] vtxe;
	}

	if(vset != NULL) delete [] vset;

	if(face != NULL){
		for(unsigned int i=0;i<objc[0].pset_count;i++)
			delete [] face[i];
		delete [] face;
	}

	if(pset != NULL) delete [] pset;
	if(unrm != NULL) delete [] unrm;
	if(texf != NULL) delete [] texf;
	if(tset != NULL) delete [] tset;
	if(tsta != NULL) delete [] tsta;
	if(shad != NULL) delete [] shad;
	if(rend != NULL) delete [] rend;
	if(mate != NULL) delete [] mate;
	if(mesh != NULL) delete [] mesh;
	if(objc != NULL) delete [] objc;
}

//--------------------------------------------------
// エクスポート(FBX) 作りかけ for FBX SDK 2017.0.1
//--------------------------------------------------

bool clAQO::ExportFbx(const char *filename){

	FbxManager *fbx = NULL;
    FbxScene *scene = NULL;
	FbxIOSettings *ios = NULL;
    bool result;

	fbx = FbxManager::Create();
	ios = FbxIOSettings::Create(fbx, IOSROOT);
	fbx->SetIOSettings(ios);

	(*(fbx->GetIOSettings())).SetBoolProp(EXP_FBX_MATERIAL,        true);
	(*(fbx->GetIOSettings())).SetBoolProp(EXP_FBX_TEXTURE,         true);
	(*(fbx->GetIOSettings())).SetBoolProp(EXP_FBX_EMBEDDED,        false);
	(*(fbx->GetIOSettings())).SetBoolProp(EXP_FBX_SHAPE,           false);
	(*(fbx->GetIOSettings())).SetBoolProp(EXP_FBX_GOBO,            true);
	(*(fbx->GetIOSettings())).SetBoolProp(EXP_FBX_ANIMATION,       false);
	(*(fbx->GetIOSettings())).SetBoolProp(EXP_FBX_GLOBAL_SETTINGS, true);

	scene = FbxScene::Create(fbx, "My Scene");

	for(unsigned int i=0;i<objc[0].vset_count;i++){
		FbxNode *mesh_node = FbxNode::Create(scene, "meshNode");
		FbxMesh *m = FbxMesh::Create(scene, "mesh");

		FbxGeometryElementMaterial *material = m->CreateElementMaterial();
		material->SetMappingMode(FbxGeometryElement::eAllSame);
		material->SetReferenceMode(FbxGeometryElement::eIndexToDirect);
		material->GetIndexArray().Add(0);

		FbxGeometryElementNormal *normal = m->CreateElementNormal();
		normal->SetMappingMode(FbxGeometryElement::eByControlPoint);
		normal->SetReferenceMode(FbxGeometryElement::eIndexToDirect);

		FbxGeometryElementUV *uv1 = m->CreateElementUV("DiffuseUV");
		uv1->SetMappingMode(FbxGeometryElement::eByControlPoint);
		uv1->SetReferenceMode(FbxGeometryElement::eIndexToDirect);

		for(unsigned int vtxe_index=0;vtxe_index<vset[i].vtxe_count;vtxe_index++){
			switch(vtxe[i][vtxe_index].type){
				case 0x00000000: // Bind Position Buffer
				{
					m->InitControlPoints(vset[i].vtxl_count);
					for(unsigned int j=0;j<vset[i].vtxl_count;j++){
						stPosition p;
						memset(&p, 0x00, sizeof(p));
						memcpy(&p, vtxl_buff[i][j] + vtxe[i][vtxe_index].pos, sizeof(p));
						FbxVector4 vect4(p.x, p.y, p.z);
						m->SetControlPointAt(vect4, j);
					}
					break;
				}
				case 0x00000002: // Bind Normal Buffer
				{
					for(unsigned int j=0;j<vset[i].vtxl_count;j++){
						stPosition p;
						memset(&p, 0x00, sizeof(p));
						memcpy(&p, vtxl_buff[i][j] + vtxe[i][vtxe_index].pos, sizeof(p));
						FbxVector4 vect4(p.x, p.y, p.z);
						normal->GetDirectArray().Add(vect4);
					}
					break;
				}
				case 0x00000010: // Bind UV1 Buffer
				{
					for(unsigned int j=0;j<vset[i].vtxl_count;j++){
						stUV p;
						memset(&p, 0x00, sizeof(p));
						memcpy(&p, vtxl_buff[i][j] + vtxe[i][vtxe_index].pos, sizeof(p));
						FbxVector2 vect2(p.u, p.v);
						uv1->GetDirectArray().Add(vect2);
					}
					break;
				}
			}
		}

		// Face
		for(unsigned int j=0;j<pset[i].face_count-2;j++){
			//m->BeginPolygon(-1, -1, -1, false);
			m->BeginPolygon(0);
			if(j & 1){
				m->AddPolygon(face[i][j+0]);
				m->AddPolygon(face[i][j+2]);
				m->AddPolygon(face[i][j+1]);
			}
			else{
				m->AddPolygon(face[i][j+0]);
				m->AddPolygon(face[i][j+1]);
				m->AddPolygon(face[i][j+2]);
			}
			m->EndPolygon();
		}

		mesh_node->SetNodeAttribute(m);
		scene->GetRootNode()->AddChild(mesh_node);
	}

	// Export
	FbxExporter *exp = FbxExporter::Create(fbx, "");
	result = exp->Initialize(filename, -1, fbx->GetIOSettings());
	exp->Export(scene);
	exp->Destroy();

	// Destroy
	fbx->Destroy();

	return true;
}


//--------------------------------------------------
// テスト
//--------------------------------------------------
void clAQO::Test(void){
/*
	for(unsigned int i=0;i<objc[0].vset_count;i++){
		for(unsigned int j=0;j<vset[i].vtxe_count;j++){
			if(vtxe[i][j].type == 0x00000010){
				for(unsigned int k=0;k<vset[i].vtxl_count;k++){
					stUV uv;
					memset(&uv, 0x00, sizeof(uv));
					memcpy(&uv, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(uv));
					if(uv.u >= (float)(440.0f/1024.0f) && uv.u <= (float)(490.0f/1024.0f) && uv.v >= float(730.0f/1024.0f) && uv.v<=(float)(734.0f/1024.0f)){
						stPosition p;
						memset(&p, 0x00, sizeof(p));
						memcpy(&p, vtxl_buff[i][k] + 0, sizeof(p));
						p.y += 0.01f;
						memcpy(vtxl_buff[i][k] + 0, &p, sizeof(p));
					}
				}
			}
		}
	}
*/
}

//--------------------------------------------------
// AQOのインポート
//--------------------------------------------------
bool clAQO::ImportAQO(clAQO *aqo, const bool meshonly){

	unsigned int tmp_count = objc[0]._16 + aqo->objc[0]._16;
	unsigned int tmp_face_count_total = 0;
	unsigned int tmp_vtxl_count_total = 0;

	unsigned int tmp_mate_count = objc[0].mate_count + aqo->objc[0].mate_count;
	unsigned int tmp_rend_count = objc[0].rend_count + aqo->objc[0].rend_count;
	unsigned int tmp_shad_count = objc[0].shad_count + aqo->objc[0].shad_count;
	unsigned int tmp_tsta_count = objc[0].tsta_count + aqo->objc[0].tsta_count;
	unsigned int tmp_tset_count = objc[0].tset_count + aqo->objc[0].tset_count;
	unsigned int tmp_texf_count = objc[0].texf_count + aqo->objc[0].texf_count;

	stMESH *tmp_mesh;
	stMATE *tmp_mate;
	stREND *tmp_rend;
	stSHAD *tmp_shad;
	stTSTA *tmp_tsta;
	stTSET *tmp_tset;
	stTEXF *tmp_texf;
	stVSET *tmp_vset;
	stVTXE **tmp_vtxe;
	unsigned char ***tmp_vtxl_buff;
	unsigned short **tmp_bonepalette;
	unsigned short **tmp_bonepalette2;
	stPSET *tmp_pset;
	unsigned short **tmp_face;

	tmp_mesh = new stMESH[tmp_count];
	tmp_mate = new stMATE[tmp_mate_count];
	tmp_rend = new stREND[tmp_rend_count];
	tmp_shad = new stSHAD[tmp_shad_count];
	tmp_tsta = new stTSTA[tmp_tsta_count];
	tmp_tset = new stTSET[tmp_tset_count];
	tmp_texf = new stTEXF[tmp_texf_count];
	tmp_vset = new stVSET[tmp_count];
	tmp_vtxe = new stVTXE *[tmp_count];
	tmp_vtxl_buff = new unsigned char **[tmp_count];
	tmp_bonepalette = new unsigned short *[tmp_count];
	tmp_bonepalette2 = new unsigned short *[tmp_count];
	tmp_pset = new stPSET[tmp_count];
	tmp_face = new unsigned short *[tmp_count];

	unsigned int tmp_index = 0;
	for(unsigned int i=0;i<objc[0].mate_count;i++){
		tmp_mate[i] = mate[i];
	}
	for(unsigned int i=0;i<aqo->objc[0].mate_count;i++){
		tmp_mate[objc[0].mate_count + i] = aqo->mate[i];
	}
	for(unsigned int i=0;i<objc[0].rend_count;i++){
		tmp_rend[i] = rend[i];
	}
	for(unsigned int i=0;i<aqo->objc[0].rend_count;i++){
		tmp_rend[objc[0].rend_count + i] = aqo->rend[i];
	}
	for(unsigned int i=0;i<objc[0].shad_count;i++){
		tmp_shad[i] = shad[i];
	}
	for(unsigned int i=0;i<aqo->objc[0].shad_count;i++){
		tmp_shad[objc[0].shad_count + i] = aqo->shad[i];
		tmp_shad[objc[0].shad_count + i]._90 = objc[0].shad_count + i;
	}
	for(unsigned int i=0;i<objc[0].tsta_count;i++){
		tmp_tsta[i] = tsta[i];
	}
	for(unsigned int i=0;i<aqo->objc[0].tsta_count;i++){
		tmp_tsta[objc[0].tsta_count + i] = aqo->tsta[i];
		tmp_tsta[objc[0].tsta_count + i]._61 = objc[0].tsta_count + i;
	}
	for(unsigned int i=0;i<objc[0].tset_count;i++){
		tmp_tset[i] = tset[i];
	}
	for(unsigned int i=0;i<aqo->objc[0].tset_count;i++){
		tmp_tset[objc[0].tset_count + i] = aqo->tset[i];
		tmp_tset[objc[0].tset_count + i]._70 = objc[0].tset_count + i;
		for(unsigned int j=0;j<tmp_tset[objc[0].tset_count + i]._71;j++){
			tmp_tset[objc[0].tset_count + i]._75[j] += objc[0].texf_count;
		}
	}
	for(unsigned int i=0;i<objc[0].texf_count;i++){
		tmp_texf[i] = texf[i];
	}
	for(unsigned int i=0;i<aqo->objc[0].texf_count;i++){
		tmp_texf[objc[0].texf_count + i] = aqo->texf[i];
	}
	for(unsigned int i=0;i<objc[0]._16;i++){
		tmp_mesh[tmp_index] = mesh[i];
		tmp_mesh[tmp_index]._c0 = tmp_index;
		tmp_mesh[tmp_index]._c1 = tmp_index;
		tmp_vset[tmp_index] = vset[i];
		tmp_vtxe[tmp_index] = new stVTXE [tmp_vset[tmp_index].vtxe_count];
		for(unsigned int j=0;j<tmp_vset[tmp_index].vtxe_count;j++){
			tmp_vtxe[tmp_index][j] = vtxe[i][j];
		}
		tmp_vtxl_buff[tmp_index] = new unsigned char *[tmp_vset[tmp_index].vtxl_count];
		for(unsigned int j=0;j<tmp_vset[tmp_index].vtxl_count;j++){
			tmp_vtxl_buff[tmp_index][j] = new unsigned char[tmp_vset[tmp_index].vert_size];
			memcpy(tmp_vtxl_buff[tmp_index][j], vtxl_buff[i][j], tmp_vset[tmp_index].vert_size);
		}
		tmp_vtxl_count_total += tmp_vset[tmp_index].vtxl_count;
		
		tmp_bonepalette[tmp_index] = new unsigned short[tmp_vset[tmp_index].bonepalette_count];
		memcpy(tmp_bonepalette[tmp_index], bonepalette[i], tmp_vset[tmp_index].bonepalette_count * sizeof(unsigned short));
		tmp_bonepalette2[tmp_index] = new unsigned short[tmp_vset[tmp_index].bonepalette2_count];
		memcpy(tmp_bonepalette2[tmp_index], bonepalette2[i], tmp_vset[tmp_index].bonepalette2_count * sizeof(unsigned short));
		tmp_pset[tmp_index] = pset[i];
		tmp_face[tmp_index] = new unsigned short[tmp_pset[tmp_index].face_count];
		memcpy(tmp_face[tmp_index], face[i], sizeof(unsigned short) * tmp_pset[tmp_index].face_count);
		tmp_face_count_total += tmp_pset[tmp_index].face_count;
		tmp_index++;
	}

	for(unsigned int i=0;i<aqo->objc[0]._16;i++){
		tmp_mesh[tmp_index] = aqo->mesh[i];
		if(meshonly == false){
			tmp_mesh[tmp_index].mate_index = objc[0].mate_count + aqo->mesh[i].mate_index;
			// tmp_mesh[tmp_index].shad_index = objc[0].shad_count + aqo->mesh[i].shad_index;
			tmp_mesh[tmp_index].rend_index = objc[0].rend_count + aqo->mesh[i].rend_index;
			tmp_mesh[tmp_index].tset_index = objc[0].tset_count + aqo->mesh[i].tset_index;;
		}
		tmp_mesh[tmp_index]._c0 = tmp_index;
		tmp_mesh[tmp_index]._c1 = tmp_index;
		tmp_vset[tmp_index] = aqo->vset[i];
		tmp_vtxe[tmp_index] = new stVTXE [tmp_vset[tmp_index].vtxe_count];
		for(unsigned int j=0;j<tmp_vset[tmp_index].vtxe_count;j++){
			tmp_vtxe[tmp_index][j] = aqo->vtxe[i][j];
		}
		tmp_vtxl_buff[tmp_index] = new unsigned char *[tmp_vset[tmp_index].vtxl_count];
		for(unsigned int j=0;j<tmp_vset[tmp_index].vtxl_count;j++){
			tmp_vtxl_buff[tmp_index][j] = new unsigned char[tmp_vset[tmp_index].vert_size];
			memcpy(tmp_vtxl_buff[tmp_index][j], aqo->vtxl_buff[i][j], tmp_vset[tmp_index].vert_size);
		}
		tmp_vtxl_count_total += tmp_vset[tmp_index].vtxl_count;
		tmp_bonepalette[tmp_index] = new unsigned short[tmp_vset[tmp_index].bonepalette_count];
		memcpy(tmp_bonepalette[tmp_index], aqo->bonepalette[i], tmp_vset[tmp_index].bonepalette_count * sizeof(unsigned short));
		tmp_bonepalette2[tmp_index] = new unsigned short[tmp_vset[tmp_index].bonepalette2_count];
		memcpy(tmp_bonepalette2[tmp_index], aqo->bonepalette2[i], tmp_vset[tmp_index].bonepalette2_count * sizeof(unsigned short));
		tmp_pset[tmp_index] = aqo->pset[i];
		tmp_face[tmp_index] = new unsigned short[tmp_pset[tmp_index].face_count];
		memcpy(tmp_face[tmp_index], aqo->face[i], sizeof(unsigned short) * tmp_pset[tmp_index].face_count);
		tmp_face_count_total += tmp_pset[tmp_index].face_count;
		tmp_index++;
	}

	// UNRM
	if(aqo->unrm != NULL && meshonly == false){
		if(unrm == NULL){
			unrm = new stUNRM[1];
			memset(&unrm[0], 0x00, sizeof(stUNRM));
		}
		unsigned int tmp_data1_count = 0;
		unsigned int tmp_data2_count = 0;
		unsigned int tmp_index = 0;
		unsigned int **tmp_u_data1 = new unsigned int *[1];
		unsigned int **tmp_u_data2a = new unsigned int *[1];
		unsigned int **tmp_u_data2b = new unsigned int *[1];
		tmp_u_data1[0] = new unsigned int [unrm[0]._u_data1_count + aqo->unrm[0]._u_data1_count];
		tmp_u_data2a[0] = new unsigned int [unrm[0]._u_data2_count + aqo->unrm[0]._u_data2_count];
		tmp_u_data2b[0] = new unsigned int [unrm[0]._u_data2_count + aqo->unrm[0]._u_data2_count];
		if(unrm[0]._u_data1_count > 0){
			unsigned int _data2_count = 0;
			for(unsigned int i=0;i<unrm[0]._u_data1_count;i++){
				tmp_u_data1[0][tmp_data1_count] = _u_data1[0][i];
				for(unsigned int j=0;j<_u_data1[0][i];j++){
					tmp_u_data2a[0][tmp_data2_count] = _u_data2a[0][_data2_count];
					tmp_u_data2b[0][tmp_data2_count] = _u_data2b[0][_data2_count];
					_data2_count++;
					tmp_data2_count++;
				}
				tmp_data1_count++;
			}
		}
		if(aqo->unrm[0]._u_data1_count > 0){
			unsigned int _data2_count = 0;
			for(unsigned int i=0;i<aqo->unrm[0]._u_data1_count;i++){
				tmp_u_data1[0][tmp_data1_count] = aqo->_u_data1[0][i];
				for(unsigned int j=0;j<aqo->_u_data1[0][i];j++){
					tmp_u_data2a[0][tmp_data2_count] = objc[0]._16 + aqo->_u_data2a[0][_data2_count];
					tmp_u_data2b[0][tmp_data2_count] = aqo->_u_data2b[0][_data2_count];
					_data2_count++;
					tmp_data2_count++;
				}
				tmp_data1_count++;
			}
		}

		unrm[0]._u_data1_count = tmp_data1_count;
		unrm[0]._u_data2_count = tmp_data2_count;
		delete [] _u_data1[0];
		delete [] _u_data1;
		delete [] _u_data2a[0];
		delete [] _u_data2a;
		delete [] _u_data2b[0];
		delete [] _u_data2b;
		_u_data1 = tmp_u_data1;
		_u_data2a = tmp_u_data2a;
		_u_data2b = tmp_u_data2b;
	}

	if(bonepalette2 != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++)
			delete [] bonepalette2[i];
		delete [] bonepalette2;
	}

	if(bonepalette != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++)
			delete [] bonepalette[i];
		delete [] bonepalette;
	}

	if(vtxl_buff != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++){
			for(unsigned int j=0;j<vset[i].vtxl_count;j++){
				delete [] vtxl_buff[i][j];
			}
			delete [] vtxl_buff[i];
		}
		delete [] vtxl_buff;
	}

	if(vtxe != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++)
			delete [] vtxe[i];
		delete [] vtxe;
	}

	if(vset != NULL) delete [] vset;

	if(face != NULL){
		for(unsigned int i=0;i<objc[0].pset_count;i++)
			delete [] face[i];
		delete [] face;
	}

	if(pset != NULL) delete [] pset;
	if(mesh != NULL) delete [] mesh;

	if(meshonly == false){
		if(texf != NULL) delete [] texf;
		if(tset != NULL) delete [] tset;
		if(tsta != NULL) delete [] tsta;
		if(shad != NULL) delete [] shad;
		if(rend != NULL) delete [] rend;
		if(mate != NULL) delete [] mate;
	}
	else{
		if(tmp_texf != NULL) delete [] tmp_texf;
		if(tmp_tset != NULL) delete [] tmp_tset;
		if(tmp_tsta != NULL) delete [] tmp_tsta;
		if(tmp_shad != NULL) delete [] tmp_shad;
		if(tmp_rend != NULL) delete [] tmp_rend;
		if(tmp_mate != NULL) delete [] tmp_mate;
	}

	objc[0]._16 = tmp_count;
	objc[0].mesh_count = tmp_count;
	objc[0].vset_count = tmp_count;
	objc[0].pset_count = tmp_count;
	objc[0].face_count_total = tmp_face_count_total;
	objc[0].vtxl_count_total = tmp_vtxl_count_total;

	if(meshonly == false){
		objc[0].mate_count = tmp_mate_count;
		objc[0].rend_count = tmp_rend_count;
		objc[0].shad_count = tmp_shad_count;
		objc[0].tsta_count = tmp_tsta_count;
		objc[0].tset_count = tmp_tset_count;
		objc[0].texf_count = tmp_texf_count;
	}

	bonepalette2 = tmp_bonepalette2;
	bonepalette = tmp_bonepalette;
	vtxl_buff = tmp_vtxl_buff;
	vtxe = tmp_vtxe;
	vset = tmp_vset;
	face = tmp_face;
	pset = tmp_pset;
	mesh = tmp_mesh;

	if(meshonly == false){
		texf = tmp_texf;
		tset = tmp_tset;
		tsta = tmp_tsta;
		shad = tmp_shad;
		rend = tmp_rend;
		mate = tmp_mate;
	}

	return true;
}

//--------------------------------------------------
// グループ削除
//--------------------------------------------------
void clAQO::RemoveGroup(const unsigned int delete_index){

	if(delete_index >= objc[0]._16) return;
	
	unsigned int tmp_count = objc[0]._16 - 1;
	unsigned int tmp_face_count_total = 0;
	unsigned int tmp_vtxl_count_total = 0;

	stMESH *tmp_mesh;
	stVSET *tmp_vset;
	stVTXE **tmp_vtxe;
	unsigned char ***tmp_vtxl_buff;
	unsigned short **tmp_bonepalette;
	unsigned short **tmp_bonepalette2;
	stPSET *tmp_pset;
	unsigned short **tmp_face;

	tmp_mesh = new stMESH[tmp_count];
	tmp_vset = new stVSET[tmp_count];
	tmp_vtxe = new stVTXE *[tmp_count];
	tmp_vtxl_buff = new unsigned char **[tmp_count];
	tmp_bonepalette = new unsigned short *[tmp_count];
	tmp_bonepalette2 = new unsigned short *[tmp_count];
	tmp_pset = new stPSET[tmp_count];
	tmp_face = new unsigned short *[tmp_count];

	unsigned int tmp_index = 0;
	for(unsigned int i=0;i<objc[0]._16;i++){
		if(i != delete_index){
			tmp_mesh[tmp_index] = mesh[i];
			tmp_mesh[tmp_index]._c0 = tmp_index;
			tmp_mesh[tmp_index]._c1 = tmp_index;
			tmp_vset[tmp_index] = vset[i];
			tmp_vtxe[tmp_index] = new stVTXE [tmp_vset[tmp_index].vtxe_count];
			for(unsigned int j=0;j<tmp_vset[tmp_index].vtxe_count;j++){
				tmp_vtxe[tmp_index][j] = vtxe[i][j];
			}
			tmp_vtxl_buff[tmp_index] = new unsigned char *[tmp_vset[tmp_index].vtxl_count];
			for(unsigned int j=0;j<tmp_vset[tmp_index].vtxl_count;j++){
				tmp_vtxl_buff[tmp_index][j] = new unsigned char[tmp_vset[tmp_index].vert_size];
				memcpy(tmp_vtxl_buff[tmp_index][j], vtxl_buff[i][j], tmp_vset[tmp_index].vert_size);
			}
			tmp_vtxl_count_total += tmp_vset[tmp_index].vtxl_count;
			tmp_bonepalette[tmp_index] = new unsigned short[tmp_vset[tmp_index].bonepalette_count];
			memcpy(tmp_bonepalette[tmp_index], bonepalette[i], tmp_vset[tmp_index].bonepalette_count * sizeof(unsigned short));
			tmp_bonepalette2[tmp_index] = new unsigned short[tmp_vset[tmp_index].bonepalette2_count];
			memcpy(tmp_bonepalette2[tmp_index], bonepalette2[i], tmp_vset[tmp_index].bonepalette2_count * sizeof(unsigned short));
			tmp_pset[tmp_index] = pset[i];
			tmp_face[tmp_index] = new unsigned short[tmp_pset[tmp_index].face_count];
			memcpy(tmp_face[tmp_index], face[i], sizeof(unsigned short) * tmp_pset[tmp_index].face_count);
			tmp_face_count_total += tmp_pset[tmp_index].face_count;

			tmp_index++;
		}
	}

	if(unrm != NULL){
		unsigned int **tmp_u_data1 = new unsigned int *[1];
		unsigned int **tmp_u_data2a = new unsigned int *[1];
		unsigned int **tmp_u_data2b = new unsigned int *[1];
		tmp_u_data1[0] = new unsigned int [unrm[0]._u_data1_count];
		tmp_u_data2a[0] = new unsigned int [unrm[0]._u_data2_count];
		tmp_u_data2b[0] = new unsigned int [unrm[0]._u_data2_count];
		unsigned int _data2_count = 0;
		unsigned int tmp_data1_count = 0;
		unsigned int tmp_data2_count = 0;
		for(unsigned int i=0;i<unrm[0]._u_data1_count;i++){
			unsigned int count = 0;
			for(unsigned int j=0;j<_u_data1[0][i];j++){
				if(_u_data2a[0][_data2_count + j] != delete_index){
					count++;
				}
			}
			if(count){
				for(unsigned int j=0;j<_u_data1[0][i];j++){
					unsigned int dec = 0;
					if(_u_data2a[0][_data2_count + j] > delete_index){
						dec = 1;
					}
					if(_u_data2a[0][_data2_count + j] != delete_index){
						tmp_u_data2a[0][tmp_data2_count] = _u_data2a[0][_data2_count + j] - dec;
						tmp_u_data2b[0][tmp_data2_count] = _u_data2b[0][_data2_count + j] - dec;
						tmp_data2_count++;
					}
				}
				tmp_u_data1[0][tmp_data1_count] = count;
				tmp_data1_count++;
			}
			_data2_count += _u_data1[0][i];
		}
		unrm[0]._u_data1_count = tmp_data1_count;
		unrm[0]._u_data2_count = tmp_data2_count;
		delete [] _u_data1[0];
		delete [] _u_data1;
		delete [] _u_data2a[0];
		delete [] _u_data2a;
		delete [] _u_data2b[0];
		delete [] _u_data2b;
		_u_data1 = tmp_u_data1;
		_u_data2a = tmp_u_data2a;
		_u_data2b = tmp_u_data2b;
	}

	if(bonepalette2 != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++)
			delete [] bonepalette2[i];
		delete [] bonepalette2;
	}

	if(bonepalette != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++)
			delete [] bonepalette[i];
		delete [] bonepalette;
	}

	if(vtxl_buff != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++){
			for(unsigned int j=0;j<vset[i].vtxl_count;j++){
				delete [] vtxl_buff[i][j];
			}
			delete [] vtxl_buff[i];
		}
		delete [] vtxl_buff;
	}

	if(vtxe != NULL){
		for(unsigned int i=0;i<objc[0].vset_count;i++)
			delete [] vtxe[i];
		delete [] vtxe;
	}

	if(vset != NULL) delete [] vset;

	if(face != NULL){
		for(unsigned int i=0;i<objc[0].pset_count;i++)
			delete [] face[i];
		delete [] face;
	}

	if(pset != NULL) delete [] pset;
	if(mesh != NULL) delete [] mesh;

	objc[0]._16 = tmp_count;
	objc[0].mesh_count = tmp_count;
	objc[0].vset_count = tmp_count;
	objc[0].pset_count = tmp_count;
	objc[0].face_count_total = tmp_face_count_total;
	objc[0].vtxl_count_total = tmp_vtxl_count_total;

	bonepalette2 = tmp_bonepalette2;
	bonepalette = tmp_bonepalette;
	vtxl_buff = tmp_vtxl_buff;
	vtxe = tmp_vtxe;
	vset = tmp_vset;
	face = tmp_face;
	pset = tmp_pset;
	mesh = tmp_mesh;
}

//--------------------------------------------------
// 適当インポート
//--------------------------------------------------
bool clAQO::ImportVertexFromObj(const char *filename){
	struct stVectObj {
		float vx, vy, vz;
		float nx, ny, nz;
		float u, v;
		bool flag;
	};
	stVectObj **vobj = new stVectObj *[objc[0].vset_count];
	for(unsigned int i=0;i<objc[0].vset_count;i++){
		vobj[i] = new stVectObj[vset[i].vtxl_count];
		memset(vobj[i], 0x00, sizeof(stVectObj) * vset[i].vtxl_count);
	}
	FILE *obj;
	if(fopen_s(&obj, filename, "r")){
		printf("Error: File can't open. input(.obj)=[%s]\n", filename);
		return false;
	}
	char buf[1024];
	unsigned int v_index = 0;
	unsigned int vt_index = 0;
	unsigned int vn_index = 0;
	unsigned int group_index = 0;
	while(fgets(buf, sizeof(buf) - 1, obj) != NULL){
		char *s;
		s = strstr(buf, "o ");
		if(s != NULL){
			group_index = (unsigned int)atoi(s + 2);
			v_index = 0;
			vt_index = 0;
			vn_index = 0;
		}
		if(v_index < vset[group_index].vtxl_count){
			s = strstr(buf, "v ");
			if(s != NULL){
				s += 2;
				while(*s == ' ' || *s == '\t') s++;
				vobj[group_index][v_index].vx = (float)atof(s);
				s = strchr(s, ' ');
				if(s != NULL){
					while(*s == ' ' || *s == '\t') s++;
					vobj[group_index][v_index].vy = (float)atof(s);
				}
				s = strchr(s, ' ');
				if(s != NULL){
					while(*s == ' ' || *s == '\t') s++;
					vobj[group_index][v_index].vz = (float)atof(s);
				}
				v_index++;
			}
		}
		if(vn_index < vset[group_index].vtxl_count){
			s = strstr(buf, "vn ");
			if(s != NULL){
				s += 2;
				while(*s == ' ' || *s == '\t') s++;
				vobj[group_index][vn_index].nx = (float)atof(s);
				s = strchr(s, ' ');
				if(s != NULL){
					while(*s == ' ' || *s == '\t') s++;
					vobj[group_index][vn_index].ny = (float)atof(s);
				}
				s = strchr(s, ' ');
				if(s != NULL){
					while(*s == ' ' || *s == '\t') s++;
					vobj[group_index][vn_index].nz = (float)atof(s);
				}
				vn_index++;
			}
		}
		if(vt_index < vset[group_index].vtxl_count){
			s = strstr(buf, "vt ");
			if(s != NULL){
				s += 2;
				while(*s == ' ' || *s == '\t') s++;
				vobj[group_index][vt_index].u = (float)atof(s);
				s = strchr(s, ' ');
				if(s != NULL){
					while(*s == ' ' || *s == '\t') s++;
					vobj[group_index][vt_index].v = (float)atof(s);
				}
				vt_index++;
			}
		}
	}
	fclose(obj);

	for(unsigned int i=0;i<objc[0].vset_count;i++){
		unsigned int vert_index = 0;
		unsigned int uv_index = 0;
		for(unsigned int j=0;j<vset[i].vtxe_count;j++){
			if(vtxe[i][j].type == 0x00000000){
				vert_index = j;
			}
			else if(vtxe[i][j].type == 0x00000010){
				uv_index = j;
			}
		}
		for(unsigned int j=0;j<vset[i].vtxl_count;j++){
			stPosition vert;
			memcpy(&vert, vtxl_buff[i][j] + vtxe[i][vert_index].pos, sizeof(stPosition));
			float dm = 0.0f;
			stPosition dm_vert;
			memset(&dm_vert, 0x00, sizeof(dm_vert));
			unsigned int kk=0,ll=0;
			bool first = true;
			for(unsigned int k=0;k<objc[0].vset_count;k++){
				for(unsigned int l=0;l<vset[k].vtxl_count;l++){
					float dx = (float)fabs(vobj[k][l].vx - vert.x);
					float dy = (float)fabs(vobj[k][l].vy - vert.y);
					float dz = (float)fabs(vobj[k][l].vz - vert.z);
					if(vobj[k][l].flag == false && (dm > (dx + dy + dz) || first)){
						dm = (dx + dy + dz);
						dm_vert.x = vobj[k][l].vx;
						dm_vert.y = vobj[k][l].vy;
						dm_vert.z = vobj[k][l].vz;
						kk = k; ll=l;
						first = false;
					}
				}
			}
			vobj[kk][ll].flag = true;
			memcpy(vtxl_buff[i][j] + vtxe[i][vert_index].pos, &dm_vert, sizeof(stPosition));
		}
	}

	for(unsigned int i=0;i<objc[0].vset_count;i++)
		delete [] vobj[i];
	delete [] vobj;

	return true;
}

//--------------------------------------------------
// max/min
//--------------------------------------------------
void clAQO::GetPosition_max_min(void){

	for(unsigned int i=0;i<objc[0].vset_count;i++){

		unsigned int pos = 0;

		for(unsigned int j=0;j<vset[i].vtxe_count;j++){
			if(vtxe[i][j].type == 0x00000000){
				pos = j;
				break;
			}
		}

		for(unsigned int j=0;j<vset[i].vtxl_count;j++){

			stPosition org;
			memset(&org, 0x00, sizeof(org));
			memcpy(&org, vtxl_buff[i][j] + pos, sizeof(org));

			if(!i && !j){
				max.x = org.x;
				max.y = org.y;
				max.z = org.z;
				min.x = org.x;
				min.y = org.y;
				min.z = org.z;
			}
			else{
				if(org.x > max.x) max.x = org.x;
				if(org.y > max.y) max.y = org.y;
				if(org.z > max.z) max.z = org.z;
				if(org.x < min.x) min.x = org.x;
				if(org.y < min.y) min.y = org.y;
				if(org.z < min.z) min.z = org.z;
			}
		}
	}
}

//--------------------------------------------------
// MovePosition
//--------------------------------------------------
void clAQO::MovePosition(const float x, const float y, const float z){

	for(unsigned int i=0;i<objc[0].vset_count;i++){
		for(unsigned int j=0;j<vset[i].vtxe_count;j++){

			if(vtxe[i][j].type == 0x00000000){

				for(unsigned int k=0;k<vset[i].vtxl_count;k++){

					stPosition p;
					memset(&p, 0x00, sizeof(p));
					memcpy(&p, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(p));
					p.x += x;
					p.y += y;
					p.z += z;
					memcpy(vtxl_buff[i][k] + vtxe[i][j].pos, &p, sizeof(p));

				}

				break;
			}
		}
	}
}

//--------------------------------------------------
// UV座標
//--------------------------------------------------
void clAQO::HalfUV(const float u){

	for(unsigned int i=0;i<objc[0].vset_count;i++){
		for(unsigned int j=0;j<vset[i].vtxe_count;j++){

			if(vtxe[i][j].type == 0x00000010 || vtxe[i][j].type == 0x00000011){

				for(unsigned int k=0;k<vset[i].vtxl_count;k++){
					stUV uv;
					memset(&uv, 0x00, sizeof(uv));
					memcpy(&uv, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(uv));
					if(uv.u != 0.0f) uv.u = uv.u / 2;
					uv.u += u;
					memcpy(vtxl_buff[i][k] + vtxe[i][j].pos, &uv, sizeof(uv));
				}
			}
		}
	}
}

//--------------------------------------------------
// Rotate
//--------------------------------------------------
void clAQO::Rotate(const float r, const char xyz){

	GetPosition_max_min();

	float xx = (float)fabs(max.x - min.x);
	float yy = (float)fabs(max.y - min.y);
	float zz = (float)fabs(max.z - min.z);
	float rt = r * (float)(3.14159265358 / 180.0);

	for(unsigned int i=0;i<objc[0].vset_count;i++){
		for(unsigned int j=0;j<vset[i].vtxe_count;j++){

			if(vtxe[i][j].type == 0x00000000){

				for(unsigned int k=0;k<vset[i].vtxl_count;k++){

					stPosition p;
					memset(&p, 0x00, sizeof(p));
					memcpy(&p, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(p));

					p.x += min.x * -1;
					p.y += min.y * -1;
					p.z += min.z * -1;

					p.x -= xx / 2;
					p.y -= yy / 2;
					p.z -= zz / 2;

					float px = p.x;
					float py = p.y;
					float pz = p.z;

					switch(xyz){
					case 'x':
						p.z = (float)(pz*cos(rt)-py*sin(rt));
						p.y = (float)(pz*sin(rt)+py*cos(rt));
						break;
					case 'y':
						p.x = (float)(px*cos(rt)-pz*sin(rt));
						p.z = (float)(px*sin(rt)+pz*cos(rt));
						break;
					case 'z':
						p.y = (float)(py*cos(rt)-px*sin(rt));
						p.x = (float)(py*sin(rt)+px*cos(rt));
						break;
					}

					p.x += xx / 2;
					p.y += yy / 2;
					p.z += zz / 2;

					p.x -= min.x * -1;
					p.y -= min.y * -1;
					p.z -= min.z * -1;

					memcpy(vtxl_buff[i][k] + vtxe[i][j].pos, &p, sizeof(p));
				}
				break;
			}
		}
	}
}

//--------------------------------------------------
// Scale
//--------------------------------------------------
void clAQO::Scale(const float s, const char xyz){

	GetPosition_max_min();

	float xx = (float)fabs(max.x - min.x);
	float yy = (float)fabs(max.y - min.y);
	float zz = (float)fabs(max.z - min.z);

	for(unsigned int i=0;i<objc[0].vset_count;i++){
		for(unsigned int j=0;j<vset[i].vtxe_count;j++){

			if(vtxe[i][j].type == 0x00000000){
				for(unsigned int k=0;k<vset[i].vtxl_count;k++){

					stPosition p;
					memset(&p, 0x00, sizeof(p));
					memcpy(&p, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(p));

					switch(xyz){
					case 'x':
						p.x += min.x * -1;
						p.x -= xx / 2;
						p.x *= s;
						p.x += xx / 2;
						p.x += min.x;
						break;
					case 'y':
						p.y += min.y * -1;
						p.y -= yy / 2;
						p.y *= s;
						p.y += yy / 2;
						p.y += min.y;
						break;
					case 'z':
						p.z += min.z * -1;
						p.z -= zz / 2;
						p.z *= s;
						p.z += zz / 2;
						p.z += min.z;
						break;
					}
					memcpy(vtxl_buff[i][k] + vtxe[i][j].pos, &p, sizeof(p));
				}
				break;
			}
		}
	}
}

//--------------------------------------------------
// ReplaceTexfilename
//--------------------------------------------------
void clAQO::ReplaceTexfilename(const char *dest){
	char _dd[32], _mm[32], _ss[32], _nn[32];
	memset(_dd, 0x00, sizeof(_dd));
	memset(_mm, 0x00, sizeof(_mm));
	memset(_ss, 0x00, sizeof(_ss));
	memset(_nn, 0x00, sizeof(_nn));
	sprintf_s(_dd, sizeof(_dd), "%s_dd", dest);
	sprintf_s(_mm, sizeof(_mm), "%s_mm", dest);
	sprintf_s(_ss, sizeof(_ss), "%s_ss", dest);
	sprintf_s(_nn, sizeof(_nn), "%s_nn", dest);
	for(unsigned int i=0;i<objc[0].tsta_count;i++){
		strchg(tsta[i]._6c, sizeof(tsta[i]._6c), "pl_body_diffuse", _dd);
		strchg(tsta[i]._6c, sizeof(tsta[i]._6c), "pl_body_multi", _mm);
		strchg(tsta[i]._6c, sizeof(tsta[i]._6c), "pl_body_decal", _ss);
		strchg(tsta[i]._6c, sizeof(tsta[i]._6c), "pl_body_normal", _nn);
	}
	for(unsigned int i=0;i<objc[0].texf_count;i++){
		strchg(texf[i]._80, sizeof(texf[i]._80), "pl_body_diffuse", _dd);
		strchg(texf[i]._80, sizeof(texf[i]._80), "pl_body_multi", _mm);
		strchg(texf[i]._80, sizeof(texf[i]._80), "pl_body_decal", _ss);
		strchg(texf[i]._80, sizeof(texf[i]._80), "pl_body_normal", _nn);
	}
}

//--------------------------------------------------
// ReplaceString
//--------------------------------------------------
void clAQO::ReplaceString(const char *src, const char *dest){
	for(unsigned int i=0;i<objc[0].mate_count;i++){
		strchg(mate[i]._3a, sizeof(mate[i]._3a), src, dest);
		strchg(mate[i]._39, sizeof(mate[i]._39), src, dest);
	}
	for(unsigned int i=0;i<objc[0].tsta_count;i++){
		strchg(tsta[i]._6c, sizeof(tsta[i]._6c), src, dest);
	}
	for(unsigned int i=0;i<objc[0].texf_count;i++){
		strchg(texf[i]._80, sizeof(texf[i]._80), src, dest);
	}
}

//--------------------------------------------------
// SetSukeSuke
//--------------------------------------------------
void clAQO::SetSukeSuke(unsigned int sukeref){
	for(unsigned int i=0;i<objc[0].rend_count;i++){
		rend[i]._43 = 1;
		rend[i]._4d = sukeref;
	}
}

//--------------------------------------------------
// SetAlpha
//--------------------------------------------------
void clAQO::SetAlpha(void){
	for(unsigned int i=0;i<objc[0].rend_count;i++){
		rend[i]._4b = 1;
	}
}

//--------------------------------------------------
// ダンプ
//--------------------------------------------------
void clAQO::dump_hex(unsigned char **buf, unsigned int pos, unsigned int count, unsigned int size){
	for(unsigned int i=0;i<count;i++){
		printf_d(mode_display, "%04X(%04d): ", i, i);
		for(unsigned int j=0;j<size;j++){
			printf_d(mode_display, "%02X ", (unsigned char)(*(buf[i] + pos + j)));
		}
	}
	printf_d(mode_display, "\n");
	return;
}

void clAQO::dump_pos(unsigned char **buf, unsigned int pos, unsigned int count){
	for(unsigned int i=0;i<count;i++){
		printf_d(mode_display, "%04X(%04d): ", i, i);
		stPosition p;
		memset(&p, 0x00, sizeof(p));
		memcpy(&p, buf[i] + pos, sizeof(p));
		for(unsigned int j=0;j<sizeof(p);j++){
			printf_d(mode_display, "%02X ", *(buf[i] + pos + j));
		}
		printf_d(mode_display, "(x=%f / y=%f / z=%f)\n", p.x, p.y, p.z);
	}
	return;
}
void clAQO::dump_uv(unsigned char **buf, unsigned int pos, unsigned int count){
	for(unsigned int i=0;i<count;i++){
		printf_d(mode_display, "%04X(%04d): ", i, i);
		stUV p;
		memset(&p, 0x00, sizeof(p));
		memcpy(&p, buf[i] + pos, sizeof(p));
		for(unsigned int j=0;j<sizeof(p);j++){
			printf_d(mode_display, "%02X ", *(buf[i] + pos + j));
		}
		printf_d(mode_display, "(u=%f / v=%f)\n", p.u, p.v);
	}
	return;
}
void clAQO::dump_float(unsigned char **buf, unsigned int pos, unsigned int count, unsigned int ary_size){
	for(unsigned int i=0;i<count;i++){
		printf_d(mode_display, "%04X(%04d): ", i, i);
		for(unsigned int j=0;j<sizeof(float) * ary_size;j++){
			printf_d(mode_display, "%02X ", *(buf[i] + pos + j));
		}
		printf_d(mode_display, "(");
		for(unsigned int j=0;j<ary_size;j++){
			float f;
			memset(&f, 0x00, sizeof(f));
			memcpy(&f, buf[i] + pos + sizeof(f) * j, sizeof(f));
			if(j) printf_d(mode_display, " / ");
			printf_d(mode_display, "%f", f);
		}
		printf_d(mode_display, ")\n");
	}
	return;
}
void clAQO::dump_ubyte(unsigned char **buf, unsigned int pos, unsigned int count, unsigned int ary_size){
	for(unsigned int i=0;i<count;i++){
		printf_d(mode_display, "%04X(%04d): ", i, i);
		for(unsigned int j=0;j<sizeof(unsigned char) * ary_size;j++){
			printf_d(mode_display, "%02X ", *(buf[i] + pos + j));
		}
		printf_d(mode_display, "(");
		for(unsigned int j=0;j<ary_size;j++){
			unsigned char c;
			memset(&c, 0x00, sizeof(unsigned char));
			memcpy(&c, buf[i] + pos + sizeof(unsigned char) * j, sizeof(unsigned char));
			if(j) printf_d(mode_display, " / ");
			printf_d(mode_display, "%d", c);
		}
		printf_d(mode_display, ")\n");
	}
	return;
}

void clAQO::show_vtxe_header(const char *str, unsigned int index, stVTXE vtxe){
	printf_d(mode_display, "----- %d: %s -----\n", index, str);
	printf_d(mode_display, "type    = [%08X] (%d)\n", vtxe.type, vtxe.type);
	printf_d(mode_display, "type2   = [%08X] (%d)\n", vtxe.type2, vtxe.type2);
	printf_d(mode_display, "pos     = [%08X] (%d)\n", vtxe.pos, vtxe.pos);
	printf_d(mode_display, "reserve = [%08X] (%d)\n", vtxe.reserve, vtxe.reserve);
	printf_d(mode_display, "\n");
}

//--------------------------------------------------
// UNRM再作成
//--------------------------------------------------
void clAQO::RemakeUNRM(void){
	// 開放
	if(_u_data2b != NULL){
		for(unsigned int i=0;i<1;i++)
			delete [] _u_data2b[i];
		delete [] _u_data2b;
	}
	if(_u_data2a != NULL){
		for(unsigned int i=0;i<1;i++)
			delete [] _u_data2a[i];
		delete [] _u_data2a;
	}
	if(_u_data1 != NULL){
		for(unsigned int i=0;i<1;i++)
			delete [] _u_data1[i];
		delete [] _u_data1;
	}
	if(unrm != NULL){
		delete [] unrm;
	}

	unrm = new stUNRM[1];
	memset(unrm, 0x00, sizeof(stUNRM));

	_u_data1 = new unsigned int *[1];
	_u_data2a = new unsigned int *[1];
	_u_data2b = new unsigned int *[1];
	_u_data1[0] = new unsigned int [objc[0].vtxl_count_total];
	_u_data2a[0] = new unsigned int [objc[0].vtxl_count_total];
	_u_data2b[0] = new unsigned int [objc[0].vtxl_count_total];

	bool **flg = new bool *[objc[0].vset_count];
	for(unsigned int i=0;i<objc[0].vset_count;i++){
		flg[i] = new bool[vset[i].vtxl_count];
		memset(flg[i], 0x00, sizeof(bool) * vset[i].vtxl_count);
	}

	for(unsigned int i=0;i<objc[0].vset_count;i++){
		unsigned int k = 0;
		for(unsigned int j=0;j<vset[i].vtxe_count;j++){
			if(vtxe[i][j].type == 0x00000000){
				k = j;
				break;
			}
		}
		for(unsigned int j=0;j<vset[i].vtxl_count;j++){
			if(flg[i][j] == false){
				flg[i][j] = true;
				stPosition p;
				memset(&p, 0x00, sizeof(p));
				memcpy(&p, vtxl_buff[i][j] + vtxe[i][k].pos, sizeof(p));
				unsigned int count = 1;
				for(unsigned int ii=0;ii<objc[0].vset_count;ii++){
					unsigned int kk = 0;
					for(unsigned int jj=0;jj<vset[ii].vtxe_count;jj++){
						if(vtxe[ii][jj].type == 0x00000000){
							kk = jj;
							break;
						}
					}
					for(unsigned int jj=0;jj<vset[ii].vtxl_count;jj++){
						if(flg[ii][jj] == false){
							stPosition pp;
							memset(&pp, 0x00, sizeof(pp));
							memcpy(&pp, vtxl_buff[ii][jj] + vtxe[ii][kk].pos, sizeof(pp));
							//if((fabs(p.x-pp.x)+fabs(p.y-pp.y)+fabs(p.z-pp.z))<0.0001f){
							if(!memcmp(&p, &pp, sizeof(p))){
								count++;
							}
						}
					}
				}
				if(count > 1){
					_u_data2a[0][unrm[0]._u_data2_count] = i;
					_u_data2b[0][unrm[0]._u_data2_count] = j;
					unrm[0]._u_data2_count++;
					for(unsigned int ii=0;ii<objc[0].vset_count;ii++){
						unsigned int kk = 0;
						for(unsigned int jj=0;jj<vset[ii].vtxe_count;jj++){
							if(vtxe[ii][jj].type == 0x00000000){
								kk = jj;
								break;
							}
						}
						for(unsigned int jj=0;jj<vset[ii].vtxl_count;jj++){
							if(flg[ii][jj] == false){
								stPosition pp;
								memset(&pp, 0x00, sizeof(pp));
								memcpy(&pp, vtxl_buff[ii][jj] + vtxe[ii][kk].pos, sizeof(pp));
								//if((fabs(p.x-pp.x)+fabs(p.y-pp.y)+fabs(p.z-pp.z)) < 0.0001f){
								if(!memcmp(&p, &pp, sizeof(p))){
									flg[ii][jj] = true;
									_u_data2a[0][unrm[0]._u_data2_count] = ii;
									_u_data2b[0][unrm[0]._u_data2_count] = jj;
									unrm[0]._u_data2_count++;
								}
							}
						}
					}
					_u_data1[0][unrm[0]._u_data1_count] = count;
					unrm[0]._u_data1_count++;
				}
			}
		}
	}

	for(unsigned int i=0;i<objc[0].vset_count;i++){
		delete [] flg[i];
	}
	delete [] flg;
}

//--------------------------------------------------
// NIFL形式読み込み
//--------------------------------------------------
bool clAQO::LoadNIFL(clNIFL *nifl){

	printf_d(mode_display, "\n***** AQO *****\n");

	unsigned int offset;

	/********** OBJC **********/
	objc = new stOBJC[1];
	memset(&objc[0], 0x00, sizeof(stOBJC));
	offset = nifl->REL0_GetEntry();
	nifl->REL0_Seek(offset);
	nifl->REL0_Read(&objc[0], sizeof(stOBJC));

	printf_d(mode_display, "\n");
	printf_d(mode_display, "***** OBJC *****\n");
	printf_d(mode_display, "real offset      = [%08X]\n", nifl->REL0_GetRealOffset() + offset);
	printf_d(mode_display, "size             = [%08X] (%d)\n", sizeof(stOBJC), sizeof(stOBJC));
	printf_d(mode_display, "\n");

	printf_d(mode_display, "_10              = [%08X] (%d)\n", objc[0]._10, objc[0]._10);
	printf_d(mode_display, "_11              = [%08X] (%d)\n", objc[0]._11, objc[0]._11);
	printf_d(mode_display, "_12              = [%08X] (%d)\n", objc[0]._12, objc[0]._12);
	printf_d(mode_display, "VERT size        = [%08X] (%d)\n", objc[0]._13, objc[0]._13);

	printf_d(mode_display, "FACE count(total)= [%08X] (%d)\n", objc[0].face_count_total, objc[0].face_count_total);
	printf_d(mode_display, "_unk_01 reserve? = [%08X] (%d)\n", objc[0]._unk_01, objc[0]._unk_01);
	printf_d(mode_display, "VTXL count(total)= [%08X] (%d)\n", objc[0].vtxl_count_total, objc[0].vtxl_count_total);
	printf_d(mode_display, "_unk_02 reserve? = [%08X] (%d)\n", objc[0]._unk_02, objc[0]._unk_02);

	printf_d(mode_display, "_16              = [%08X] (%d)\n", objc[0]._16, objc[0]._16);
	printf_d(mode_display, "VSET count       = [%08X] (%d)\n", objc[0].vset_count, objc[0].vset_count);
	printf_d(mode_display, "VSET offset      = [%08X]\n", objc[0].vset_offset);
	printf_d(mode_display, "PSET count       = [%08X] (%d)\n", objc[0].pset_count, objc[0].pset_count);

	printf_d(mode_display, "PSET offset      = [%08X]\n", objc[0].pset_offset);
	printf_d(mode_display, "MESH count       = [%08X] (%d)\n", objc[0].mesh_count, objc[0].mesh_count);
	printf_d(mode_display, "MESH offset      = [%08X]\n", objc[0].mesh_offset);
	printf_d(mode_display, "MATE count       = [%08X] (%d)\n", objc[0].mate_count, objc[0].mate_count);

	printf_d(mode_display, "MATE offset      = [%08X]\n", objc[0].mate_offset);
	printf_d(mode_display, "REND count       = [%08X] (%d)\n", objc[0].rend_count, objc[0].rend_count);
	printf_d(mode_display, "REND offset      = [%08X]\n", objc[0].rend_offset);
	printf_d(mode_display, "SHAD count       = [%08X] (%d)\n", objc[0].shad_count, objc[0].shad_count);

	printf_d(mode_display, "SHAD offset      = [%08X]\n", objc[0].shad_offset);
	printf_d(mode_display, "TSTA count       = [%08X] (%d)\n", objc[0].tsta_count, objc[0].tsta_count);
	printf_d(mode_display, "TSTA offset      = [%08X]\n", objc[0].tsta_offset);
	printf_d(mode_display, "TSET count       = [%08X] (%d)\n", objc[0].tset_count, objc[0].tset_count);

	printf_d(mode_display, "TSET offset      = [%08X]\n", objc[0].tset_offset);
	printf_d(mode_display, "TEXF count       = [%08X] (%d)\n", objc[0].texf_count, objc[0].texf_count);
	printf_d(mode_display, "TEXF offset      = [%08X]\n", objc[0].texf_offset);
	printf_d(mode_display, "_1e              = \n"); dump(mode_display, objc[0]._1e, sizeof(objc[0]._1e));
	printf_d(mode_display, "reserve          = [%08X] (%d)\n", objc[0].reserve, objc[0].reserve);

	printf_d(mode_display, "UNRM offset      = [%08X]\n", objc[0].unrm_offset);

	/********** MESH **********/
	mesh = new stMESH[objc[0].mesh_count];
	for(unsigned int i=0;i<objc[0].mesh_count;i++){

		offset = objc[0].mesh_offset + sizeof(stMESH) * i;
		nifl->REL0_Seek(offset);
		memset(&mesh[i], 0x00, sizeof(stMESH));
		nifl->REL0_Read(&mesh[i], sizeof(stMESH));

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** MESH:%02X(%d) *****\n", i, i);
		printf_d(mode_display, "real offset      = [%08X]\n", nifl->REL0_GetRealOffset() + offset);
		printf_d(mode_display, "size             = [%08X] (%d)\n", sizeof(stMESH), sizeof(stMESH));
		printf_d(mode_display, "\n");
		printf_d(mode_display, "_b0              = [%08X] (%d)\n", mesh[i]._b0, mesh[i]._b0);
		printf_d(mode_display, "_c7              = [%08X] (%d)\n", mesh[i]._c7, mesh[i]._c7);
		printf_d(mode_display, "MATE index       = [%08X] (%d)\n", mesh[i].mate_index, mesh[i].mate_index);
		printf_d(mode_display, "REND index       = [%08X] (%d)\n", mesh[i].rend_index, mesh[i].rend_index);
		printf_d(mode_display, "SHAD index       = [%08X] (%d)\n", mesh[i].shad_index, mesh[i].shad_index);
		printf_d(mode_display, "TSET index       = [%08X] (%d)\n", mesh[i].tset_index, mesh[i].tset_index);
		printf_d(mode_display, "_b5              = [%08X] (%d)\n", mesh[i]._b5, mesh[i]._b5);
		printf_d(mode_display, "_c0              = [%08X] (%d)\n", mesh[i]._c0, mesh[i]._c0);
		printf_d(mode_display, "_c1              = [%08X] (%d)\n", mesh[i]._c1, mesh[i]._c1);
		printf_d(mode_display, "_cd              = [%08X] (%d)\n", mesh[i]._cd, mesh[i]._cd);
		printf_d(mode_display, "_c2              = [%08X] (%d)\n", mesh[i]._c2, mesh[i]._c2);
		printf_d(mode_display, "reserve          = [%08X] (%d)\n", mesh[i].reserve, mesh[i].reserve);
	}

	/********** MATE **********/
	mate = new stMATE[objc[0].mate_count];
	for(unsigned int i=0;i<objc[0].mate_count;i++){

		offset = objc[0].mate_offset + sizeof(stMATE) * i;
		nifl->REL0_Seek(offset);
		memset(&mate[i], 0x00, sizeof(stMATE));
		nifl->REL0_Read(&mate[i], sizeof(stMATE));

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** MATE:%02X(%d) *****\n", i, i);
		printf_d(mode_display, "real offset      = [%08X]\n", nifl->REL0_GetRealOffset() + offset);
		printf_d(mode_display, "size             = [%08X] (%d)\n", sizeof(stMATE), sizeof(stMATE));
		printf_d(mode_display, "\n");
		printf_d(mode_display, "_30              = \n"); dump(mode_display, mate[i]._30, 16);
		printf_d(mode_display, "_31              = \n"); dump(mode_display, mate[i]._31, 16);
		printf_d(mode_display, "_32              = \n"); dump(mode_display, mate[i]._32, 16);
		printf_d(mode_display, "_33              = \n"); dump(mode_display, mate[i]._33, 16);
		printf_d(mode_display, "_34              = [%08X] (%d)\n", mate[i]._34, mate[i]._34);
		printf_d(mode_display, "_35              = [%08X] (%d)\n", mate[i]._35, mate[i]._35);
		printf_d(mode_display, "_36              = [%08X] (%d)\n", mate[i]._36, mate[i]._36);
		printf_d(mode_display, "_37              = [%08X] (%d)\n", mate[i]._37, mate[i]._37);
		printf_d(mode_display, "_38              = [%08X] (%d)\n", mate[i]._38, mate[i]._38);
		printf_d(mode_display, "_3a              = [%s]\n", mate[i]._3a);
		printf_d(mode_display, "_39              = [%s]\n", mate[i]._39);
	}

	/********** REND **********/
	rend = new stREND[objc[0].rend_count];
	for(unsigned int i=0;i<objc[0].rend_count;i++){

		offset = objc[0].rend_offset + sizeof(stREND) * i;
		nifl->REL0_Seek(offset);
		memset(&rend[i], 0x00, sizeof(stREND));
		nifl->REL0_Read(&rend[i], sizeof(stREND));

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** REND:%02X(%d) *****\n", i, i);
		printf_d(mode_display, "real offset      = [%08X]\n", nifl->REL0_GetRealOffset() + offset);
		printf_d(mode_display, "size             = [%08X] (%d)\n", sizeof(stREND), sizeof(stREND));
		printf_d(mode_display, "\n");
		printf_d(mode_display, "_40              = [%08X] (%d)\n", rend[i]._40, rend[i]._40);
		printf_d(mode_display, "_41              = [%08X] (%d)\n", rend[i]._41, rend[i]._41);
		printf_d(mode_display, "_42              = [%08X] (%d)\n", rend[i]._42, rend[i]._42);
		printf_d(mode_display, "_43              = [%08X] (%d)\n", rend[i]._43, rend[i]._43);
		printf_d(mode_display, "_44              = [%08X] (%d)\n", rend[i]._44, rend[i]._44);
		printf_d(mode_display, "_45              = [%08X] (%d)\n", rend[i]._45, rend[i]._45);
		printf_d(mode_display, "_46              = [%08X] (%d)\n", rend[i]._46, rend[i]._46);
		printf_d(mode_display, "_47              = [%08X] (%d)\n", rend[i]._47, rend[i]._47);
		printf_d(mode_display, "_48              = [%08X] (%d)\n", rend[i]._48, rend[i]._48);
		printf_d(mode_display, "_49              = [%08X] (%d)\n", rend[i]._49, rend[i]._49);
		printf_d(mode_display, "_4a              = [%08X] (%d)\n", rend[i]._4a, rend[i]._4a);
		printf_d(mode_display, "_4b              = [%08X] (%d)\n", rend[i]._4b, rend[i]._4b);
		printf_d(mode_display, "_4c              = [%08X] (%d)\n", rend[i]._4c, rend[i]._4c);
		printf_d(mode_display, "_4d              = [%08X] (%d)\n", rend[i]._4d, rend[i]._4d);
		printf_d(mode_display, "_4e              = [%08X] (%d)\n", rend[i]._4e, rend[i]._4e);
		printf_d(mode_display, "_4f              = [%08X] (%d)\n", rend[i]._4f, rend[i]._4f);
		printf_d(mode_display, "_50              = [%08X] (%d)\n", rend[i]._50, rend[i]._50);
	}

	/********** SHAD **********/
	shad = new stSHAD[objc[0].shad_count];
	for(unsigned int i=0;i<objc[0].shad_count;i++){

		offset = objc[0].shad_offset + sizeof(stSHAD) * i;
		nifl->REL0_Seek(offset);
		memset(&shad[i], 0x00, sizeof(stSHAD));
		nifl->REL0_Read(&shad[i], sizeof(stSHAD));

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** SHAD:%02X(%d) *****\n", i, i);
		printf_d(mode_display, "real offset      = [%08X]\n", nifl->REL0_GetRealOffset() + offset);
		printf_d(mode_display, "size             = [%08X] (%d)\n", sizeof(stSHAD), sizeof(stSHAD));
		printf_d(mode_display, "\n");
		printf_d(mode_display, "_90              = [%08X] (%d)\n", shad[i]._90, shad[i]._90);
		printf_d(mode_display, "_91              = [%s]\n", shad[i]._91);
		printf_d(mode_display, "_92              = [%s]\n", shad[i]._92);
		printf_d(mode_display, "_93              = [%08X] (%d)\n", shad[i]._93, shad[i]._93);
	}

	/********** TSTA **********/
	tsta = new stTSTA[objc[0].tsta_count];
	for(unsigned int i=0;i<objc[0].tsta_count;i++){

		offset = objc[0].tsta_offset + sizeof(stTSTA) * i;
		nifl->REL0_Seek(offset);
		memset(&tsta[i], 0x00, sizeof(stTSTA));
		nifl->REL0_Read(&tsta[i], sizeof(stTSTA));

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** TSTA:%02X(%d) *****\n", i, i);
		printf_d(mode_display, "real offset      = [%08X]\n", nifl->REL0_GetRealOffset() + offset);
		printf_d(mode_display, "size             = [%08X] (%d)\n", sizeof(stTSTA), sizeof(stTSTA));
		printf_d(mode_display, "\n");
		printf_d(mode_display, "_60              = [%08X] (%d)\n", tsta[i]._60, tsta[i]._60);
		printf_d(mode_display, "_61              = [%08X] (%d)\n", tsta[i]._61, tsta[i]._61);
		printf_d(mode_display, "_62              = [%08X] (%d)\n", tsta[i]._62, tsta[i]._62);
		printf_d(mode_display, "_63              = \n"); dump(mode_display, tsta[i]._63, 12);
		printf_d(mode_display, "_64              = [%08X] (%d)\n", tsta[i]._64, tsta[i]._64);
		printf_d(mode_display, "_65              = [%08X] (%d)\n", tsta[i]._65, tsta[i]._65);
		printf_d(mode_display, "_66              = [%08X] (%d)\n", tsta[i]._66, tsta[i]._66);
		printf_d(mode_display, "_67              = [%08X] (%d)\n", tsta[i]._67, tsta[i]._67);
		printf_d(mode_display, "_68              = [%08X] (%d)\n", tsta[i]._68, tsta[i]._68);
		printf_d(mode_display, "_69              = [%08X] (%d)\n", tsta[i]._69, tsta[i]._69);
		printf_d(mode_display, "_6a              = [%08X] (%d)\n", tsta[i]._6a, tsta[i]._6a);
		printf_d(mode_display, "_6b              = [%08X] (%d)\n", tsta[i]._6b, tsta[i]._6b);
		printf_d(mode_display, "_6c              = [%s]\n", tsta[i]._6c);
	}

	/********** TSET **********/
	tset = new stTSET[objc[0].tset_count];
	for(unsigned int i=0;i<objc[0].tset_count;i++){

		offset = objc[0].tset_offset + sizeof(stTSET) * i;
		nifl->REL0_Seek(offset);
		memset(&tset[i], 0x00, sizeof(stTSET));
		nifl->REL0_Read(&tset[i], sizeof(stTSET));

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** TSET:%02X(%d) *****\n", i, i);
		printf_d(mode_display, "real offset      = [%08X]\n", nifl->REL0_GetRealOffset() + offset);
		printf_d(mode_display, "size             = [%08X] (%d)\n", sizeof(stTSET), sizeof(stTSET));
		printf_d(mode_display, "\n");
		printf_d(mode_display, "_70              = [%08X] (%d)\n", tset[i]._70, tset[i]._70);
		printf_d(mode_display, "_71              = [%08X] (%d)\n", tset[i]._71, tset[i]._71);
		printf_d(mode_display, "_72              = [%08X] (%d)\n", tset[i]._72, tset[i]._72);
		printf_d(mode_display, "_73              = [%08X] (%d)\n", tset[i]._73, tset[i]._73);
		printf_d(mode_display, "_74              = [%08X] (%d)\n", tset[i]._74, tset[i]._74);
		printf_d(mode_display, "_75              = %d,%d,%d,%d\n", tset[i]._75[0], tset[i]._75[1], tset[i]._75[2], tset[i]._75[3]); //dump(mode_display, tset[i]._75, 16);
	}

	/********** TEXF **********/
	texf = new stTEXF[objc[0].texf_count];
	for(unsigned int i=0;i<objc[0].texf_count;i++){

		offset = objc[0].texf_offset + sizeof(stTEXF) * i;
		nifl->REL0_Seek(offset);
		memset(&texf[i], 0x00, sizeof(stTEXF));
		nifl->REL0_Read(&texf[i], sizeof(stTEXF));

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** TEXF:%02X(%d) *****\n", i, i);
		printf_d(mode_display, "real offset      = [%08X]\n", nifl->REL0_GetRealOffset() + offset);
		printf_d(mode_display, "size             = [%08X] (%d)\n", sizeof(stTEXF), sizeof(stTEXF));
		printf_d(mode_display, "\n");
		printf_d(mode_display, "_80              = [%s]\n", texf[i]._80);
	}

	/********** PSET **********/
	pset = new stPSET[objc[0].pset_count];
	face = new unsigned short *[objc[0].pset_count];

	for(unsigned int i=0;i<objc[0].pset_count;i++){

		offset = objc[0].pset_offset + sizeof(stPSET) * i;
		nifl->REL0_Seek(offset);
		memset(&pset[i], 0x00, sizeof(stPSET));
		nifl->REL0_Read(&pset[i], sizeof(stPSET));

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** PSET:%02X(%d) *****\n", i, i);
		printf_d(mode_display, "real offset      = [%08X]\n", nifl->REL0_GetRealOffset() + offset);
		printf_d(mode_display, "size             = [%08X] (%d)\n", sizeof(stPSET), sizeof(stPSET));
		printf_d(mode_display, "\n");
		printf_d(mode_display, "_c6              = [%08X] (%d)\n", pset[i]._c6, pset[i]._c6);
		printf_d(mode_display, "_bb              = [%08X] (%d)\n", pset[i]._bb, pset[i]._bb);
		printf_d(mode_display, "FACE count offset= [%08X]\n", pset[i].face_count_offset);
		printf_d(mode_display, "FACE count       = [%08X] (%d)\n", pset[i].face_count, pset[i].face_count);
		printf_d(mode_display, "FACE data offset = [%08X]\n", pset[i].face_data_offset);
		printf_d(mode_display, "reserve          = [%08X] (%d)\n", pset[i].reserve, pset[i].reserve);

		face[i] = new unsigned short[pset[i].face_count];
		memset(face[i], 0x00, sizeof(unsigned short) * pset[i].face_count);
		offset = pset[i].face_data_offset;
		nifl->REL0_Seek(offset);
		nifl->REL0_Read(face[i], sizeof(unsigned short) * pset[i].face_count);
		printf_d(mode_display, "\n");
		printf_d(mode_display, "FACE data        = ");
		for(unsigned int j=0;j<pset[i].face_count;j++){
			if(j) printf_d(mode_display, ", ");
			printf_d(mode_display, "%d", face[i][j]);
		}
		printf_d(mode_display, "\n");
	}

	/********** VSET **********/
	vset = new stVSET[objc[0].vset_count];
	vtxe = new stVTXE *[objc[0].vset_count];
	vtxl_buff = new unsigned char **[objc[0].vset_count];
	bonepalette = new unsigned short *[objc[0].vset_count];
	bonepalette2 = new unsigned short *[objc[0].vset_count];
	for(unsigned int i=0;i<objc[0].vset_count;i++){

		offset = objc[0].vset_offset + sizeof(stVSET) * i;
		nifl->REL0_Seek(offset);
		memset(&vset[i], 0x00, sizeof(stVSET));
		nifl->REL0_Read(&vset[i], sizeof(stVSET));

		vtxe[i] = new stVTXE [vset[i].vtxe_count];
		vtxl_buff[i] = new unsigned char *[vset[i].vtxl_count];

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** VSET:%02X(%d) *****\n", i, i);
		printf_d(mode_display, "real offset         = [%08X]\n", nifl->REL0_GetRealOffset() + offset);
		printf_d(mode_display, "size                = [%08X] (%d)\n", sizeof(stVSET), sizeof(stVSET));
		printf_d(mode_display, "\n");
		printf_d(mode_display, "VERT size           = [%08X] (%d)\n", vset[i].vert_size, vset[i].vert_size);
		printf_d(mode_display, "VTXE count          = [%08X] (%d)\n", vset[i].vtxe_count, vset[i].vtxe_count);
		printf_d(mode_display, "VTXE offset         = [%08X]\n", vset[i].vtxe_offset);
		printf_d(mode_display, "VTXL count          = [%08X] (%d)\n", vset[i].vtxl_count, vset[i].vtxl_count);
		printf_d(mode_display, "VTXL offset         = [%08X]\n", vset[i].vtxl_offset);
		printf_d(mode_display, "_unk_02             = [%08X] (%d)\n", vset[i]._unk_02, vset[i]._unk_02);
		printf_d(mode_display, "Bone Palette count  = [%08X] (%d)\n", vset[i].bonepalette_count, vset[i].bonepalette_count);
		printf_d(mode_display, "Bone Palette offset = [%08X]\n", vset[i].bonepalette_offset);
		printf_d(mode_display, "_unk_04             = [%08X] (%d)\n", vset[i]._unk_04, vset[i]._unk_04);
		printf_d(mode_display, "_unk_05             = [%08X] (%d)\n", vset[i]._unk_05, vset[i]._unk_05);
		printf_d(mode_display, "_unk_06             = [%08X] (%d)\n", vset[i]._unk_06, vset[i]._unk_06);
		printf_d(mode_display, "Bone Palette2 count = [%08X] (%d)\n", vset[i].bonepalette2_count, vset[i].bonepalette2_count);
		printf_d(mode_display, "Bone Palette2 offset= [%08X]\n", vset[i].bonepalette2_offset);

		/********** Bone Palette **********/
		bonepalette[i] = new unsigned short[vset[i].bonepalette_count];
		offset = vset[i].bonepalette_offset;
		nifl->REL0_Seek(offset);
		memset(bonepalette[i], 0x00, sizeof(unsigned short) * vset[i].bonepalette_count);
		nifl->REL0_Read(bonepalette[i], sizeof(unsigned short) * vset[i].bonepalette_count);
		printf_d(mode_display, "\n");
		printf_d(mode_display, "Bone Palette        = ");
		for(unsigned int j=0;j<vset[i].bonepalette_count;j++){
			if(j) printf_d(mode_display, ", ");
			printf_d(mode_display, "%d", bonepalette[i][j]);
		}
		printf_d(mode_display, "\n");

		bonepalette2[i] = new unsigned short[vset[i].bonepalette2_count];
		offset = vset[i].bonepalette2_offset;
		nifl->REL0_Seek(offset);
		memset(bonepalette2[i], 0x00, sizeof(unsigned short) * vset[i].bonepalette2_count);
		nifl->REL0_Read(bonepalette2[i], sizeof(unsigned short) * vset[i].bonepalette2_count);
		printf_d(mode_display, "\n");
		printf_d(mode_display, "Bone Palette2       = ");
		for(unsigned int j=0;j<vset[i].bonepalette2_count;j++){
			if(j) printf_d(mode_display, ", ");
			printf_d(mode_display, "%d", bonepalette2[i][j]);
		}
		printf_d(mode_display, "\n");

		/********** VTXE **********/
		for(unsigned int j=0;j<vset[i].vtxe_count;j++){
			offset = vset[i].vtxe_offset + sizeof(stVTXE) * j;
			nifl->REL0_Seek(offset);
			memset(&vtxe[i][j], 0x00, sizeof(stVTXE));
			nifl->REL0_Read(&vtxe[i][j], sizeof(stVTXE));
		}

		/********** VTXL **********/
		for(unsigned int j=0;j<vset[i].vtxl_count;j++){
			vtxl_buff[i][j] = new unsigned char[vset[i].vert_size];
			offset = vset[i].vtxl_offset + vset[i].vert_size * j;
			nifl->REL0_Seek(offset);
			memset(vtxl_buff[i][j], 0x00, vset[i].vert_size);
			nifl->REL0_Read(vtxl_buff[i][j], vset[i].vert_size);
		}
	}

	/********** UNRM **********/
	if(objc[0].unrm_offset){
		unrm = new stUNRM[1];
		_u_data1 = new unsigned int *[1];
		_u_data2a = new unsigned int *[1];
		_u_data2b = new unsigned int *[1];

		offset = objc[0].unrm_offset;
		nifl->REL0_Seek(offset);
		memset(&unrm[0], 0x00, sizeof(stUNRM));
		nifl->REL0_Read(&unrm[0], sizeof(stUNRM));

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** UNRM *****\n");
		printf_d(mode_display, "real offset      = [%08X]\n", nifl->REL0_GetRealOffset() + offset);
		printf_d(mode_display, "size             = [%08X] (%d)\n", sizeof(stUNRM), sizeof(stUNRM));
		printf_d(mode_display, "\n");
		printf_d(mode_display, "_u_data1_count   = [%08X] (%d)\n", unrm[0]._u_data1_count, unrm[0]._u_data1_count);
		printf_d(mode_display, "_u_data1_offset  = [%08X]\n", unrm[0]._u_data1_offset);
		printf_d(mode_display, "_u_data2_count   = [%08X] (%d)\n", unrm[0]._u_data2_count, unrm[0]._u_data2_count);
		printf_d(mode_display, "_u_data2a_offset = [%08X]\n", unrm[0]._u_data2a_offset);
		printf_d(mode_display, "_u_data2b_offset = [%08X]\n", unrm[0]._u_data2b_offset);

		_u_data1[0] = new unsigned int[unrm[0]._u_data1_count];
		offset = unrm[0]._u_data1_offset;
		nifl->REL0_Seek(offset);
		memset(_u_data1[0], 0x00, sizeof(unsigned int) * unrm[0]._u_data1_count);
		nifl->REL0_Read(_u_data1[0], sizeof(unsigned int) * unrm[0]._u_data1_count);

		_u_data2a[0] = new unsigned int[unrm[0]._u_data2_count];
		offset = unrm[0]._u_data2a_offset;
		nifl->REL0_Seek(offset);
		memset(_u_data2a[0], 0x00, sizeof(unsigned int) * unrm[0]._u_data2_count);
		nifl->REL0_Read(_u_data2a[0], sizeof(unsigned int) * unrm[0]._u_data2_count);

		_u_data2b[0] = new unsigned int[unrm[0]._u_data2_count];
		offset = unrm[0]._u_data2b_offset;
		nifl->REL0_Seek(offset);
		memset(_u_data2b[0], 0x00, sizeof(unsigned int) * unrm[0]._u_data2_count);
		nifl->REL0_Read(_u_data2b[0], sizeof(unsigned int) * unrm[0]._u_data2_count);


		printf_d(mode_display, "_u_data          = \n");
		unsigned int sum = 0;
		unsigned int data2_index = 0;
		for(unsigned int i=0;i<unrm[0]._u_data1_count;i++){
			printf_d(mode_display, "%04d: %d = ", i, _u_data1[0][i]);
			for(unsigned int j=0;j<_u_data1[0][i];j++){
				if(j) printf_d(mode_display, ", ");
				stPosition p;
				memset(&p, 0x00, sizeof(p));
				memcpy(&p, vtxl_buff[_u_data2a[0][data2_index]][_u_data2b[0][data2_index]], sizeof(p));
				printf_d(mode_display, "%d:%05d(x=%f / y=%f / z=%f)", _u_data2a[0][data2_index], _u_data2b[0][data2_index], p.x,p.y,p.z);
				data2_index++;
			}
			printf_d(mode_display, "\n");
			sum += _u_data1[0][i];
		}
		printf_d(mode_display, "\n");
		printf_d(mode_display, "sum = %d\n\n", sum);
	}

	/********** VTXE,VTXL **********/
	for(unsigned int i=0;i<objc[0].vset_count;i++){

		printf_d(mode_display, "\n");
		printf_d(mode_display, "***** VTXE+VTXL:%02X(%d) *****\n", i, i);

		for(unsigned int j=0;j<vset[i].vtxe_count;j++){

			printf_d(mode_display, "\n");

			switch(vtxe[i][j].type){
			case 0x00000000: // Bind Position Buffer
				{
					show_vtxe_header("Bind Position Buffer", j, vtxe[i][j]);
					dump_pos(vtxl_buff[i], vtxe[i][j].pos, vset[i].vtxl_count);
				}
				break;
			case 0x00000001: // Bind Bone Weight Buffer
				{
					show_vtxe_header("Bind Bone Weight Buffer", j, vtxe[i][j]);
					dump_float(vtxl_buff[i], vtxe[i][j].pos, vset[i].vtxl_count, 4);
				}
				break;
			case 0x00000002: // Bind Normal Buffer
				{
					show_vtxe_header("Bind Normal Buffer", j, vtxe[i][j]);
					dump_pos(vtxl_buff[i], vtxe[i][j].pos, vset[i].vtxl_count);
				}
				break;
			case 0x00000003: // Bind Vert Color Buffer
			{
				show_vtxe_header("Bind Vert Color Buffer", j, vtxe[i][j]);
				dump_ubyte(vtxl_buff[i], vtxe[i][j].pos, vset[i].vtxl_count, 4);
			}
			break;
			case 0x0000000b: // Bind Bone Index Buffer
				{
					show_vtxe_header("Bind Bone Index Buffer", j, vtxe[i][j]);
					dump_ubyte(vtxl_buff[i], vtxe[i][j].pos, vset[i].vtxl_count, 4);
				}
				break;
			case 0x00000010: // Bind UV1 Buffer
				{
					show_vtxe_header("Bind UV1 Buffer", j, vtxe[i][j]);
					dump_uv(vtxl_buff[i], vtxe[i][j].pos, vset[i].vtxl_count);
				}
				break;
			case 0x00000011: // Bind UV2 Buffer
				{
					show_vtxe_header("Bind UV2 Buffer", j, vtxe[i][j]);
					dump_uv(vtxl_buff[i], vtxe[i][j].pos, vset[i].vtxl_count);
				}
				break;
			case 0x00000020: // tangents
				{
					show_vtxe_header("Tangents", j, vtxe[i][j]);
					dump_pos(vtxl_buff[i], vtxe[i][j].pos, vset[i].vtxl_count);
				}
				break;
			case 0x00000021: // binormals/tangents?
				{
					show_vtxe_header("Binormals", j, vtxe[i][j]);
					dump_pos(vtxl_buff[i], vtxe[i][j].pos, vset[i].vtxl_count);
				}
				break;
			default:
				{
					show_vtxe_header("Unknown", j, vtxe[i][j]);
					dump_hex(vtxl_buff[i], vtxe[i][j].pos, vset[i].vtxl_count, 4);
				}
				break;
			}
		}
	}

	GetPosition_max_min();
	printf_d(mode_display, "max x=%f, y=%f, z=%f\n", max.x, max.y, max.z);
	printf_d(mode_display, "min x=%f, y=%f, z=%f\n", min.x, min.y, min.z);

	return true;
}

//--------------------------------------------------
// 保存
//--------------------------------------------------
bool clAQO::SaveNIFL(clNIFL *nifl){

	// ファイルを空にする
	nifl->Truncate();

	// ヘッダ
	nifl->NIFL_WriteHeader();
	nifl->REL0_WriteHeader();

	// 開始オフセット設定
	nifl->REL0_SetEntry();

	// OBJC
	nifl->REL0_Write(&objc[0], sizeof(stOBJC));
	nifl->WriteAligned();

	// VSET
	if(objc[0].vset_count){
		objc[0].vset_offset = nifl->REL0_Tell();
		for(unsigned int i=0;i<objc[0].vset_count;i++){
			nifl->REL0_Write(&vset[i], sizeof(stVSET));
		}
		nifl->WriteAligned();
	}
	else{
		objc[0].vset_offset = 0;
	}

	// VTXE,VTXL,BonePalette,BonePalette2nd
	for(unsigned int i=0;i<objc[0].vset_count;i++){

		// VTXE
		vset[i].vtxe_offset = nifl->REL0_Tell();
		for(unsigned int j=0;j<vset[i].vtxe_count;j++){
			nifl->REL0_Write(&vtxe[i][j], sizeof(stVTXE));
		}
		nifl->WriteAligned();

		// VTXL
		vset[i].vtxl_offset = nifl->REL0_Tell();
		for(unsigned int j=0;j<vset[i].vtxl_count;j++){
			nifl->REL0_Write(vtxl_buff[i][j], vset[i].vert_size);
		}
		nifl->WriteAligned();

		// BonePalette
		if(vset[i].bonepalette_count){
			vset[i].bonepalette_offset = nifl->REL0_Tell();
			nifl->REL0_Write(bonepalette[i], sizeof(unsigned short) * vset[i].bonepalette_count);
			nifl->WriteAligned();
		}
		else{
			vset[i].bonepalette_offset = 0;
		}
		// BonePalette2nd
		if(vset[i].bonepalette2_count){
			vset[i].bonepalette2_offset = nifl->REL0_Tell();
			nifl->REL0_Write(bonepalette2[i], sizeof(unsigned short) * vset[i].bonepalette2_count);
			nifl->WriteAligned();
		}
		else{
			vset[i].bonepalette2_offset = 0;
		}
	}

	// PSET
	if(objc[0].pset_count){
		objc[0].pset_offset = nifl->REL0_Tell();
		for(unsigned int i=0;i<objc[0].pset_count;i++){
			nifl->REL0_Write(&pset[i], sizeof(stPSET));
		}
		nifl->WriteAligned();
		for(unsigned int i=0;i<objc[0].pset_count;i++){
			pset[i].face_count_offset = nifl->REL0_Tell();
			nifl->REL0_Write(&pset[i].face_count, sizeof(unsigned int));
			nifl->WriteAligned();
			pset[i].face_data_offset = nifl->REL0_Tell();
			nifl->REL0_Write(face[i], sizeof(unsigned short) * pset[i].face_count);
			nifl->WriteAligned();
		}
	}
	else{
		objc[0].pset_offset = 0;
	}

	// MESH
	if(objc[0].mesh_count){
		objc[0].mesh_offset = nifl->REL0_Tell();
		for(unsigned int i=0;i<objc[0].mesh_count;i++){
			nifl->REL0_Write(&mesh[i], sizeof(stMESH));
		}
		nifl->WriteAligned();
	}
	else{
		objc[0].mesh_offset = 0;
	}

	// MATE
	if(objc[0].mate_count){
		objc[0].mate_offset = nifl->REL0_Tell();
		for(unsigned int i=0;i<objc[0].mate_count;i++){
			nifl->REL0_Write(&mate[i], sizeof(stMATE));
		}
		nifl->WriteAligned();
	}
	else{
		objc[0].mate_offset = 0;
	}

	// REND
	if(objc[0].rend_count){
		objc[0].rend_offset = nifl->REL0_Tell();
		for(unsigned int i=0;i<objc[0].rend_count;i++){
			nifl->REL0_Write(&rend[i], sizeof(stREND));
		}
		nifl->WriteAligned();
	}
	else{
		objc[0].rend_offset = 0;
	}

	// SHAD
	if(objc[0].shad_count){
		objc[0].shad_offset = nifl->REL0_Tell();
		for(unsigned int i=0;i<objc[0].shad_count;i++){
			nifl->REL0_Write(&shad[i], sizeof(stSHAD));
		}
		nifl->WriteAligned();
	}
	else{
		objc[0].shad_offset = 0;
	}

	// TSTA
	if(objc[0].tsta_count){
		objc[0].tsta_offset = nifl->REL0_Tell();
		for(unsigned int i=0;i<objc[0].tsta_count;i++){
			nifl->REL0_Write(&tsta[i], sizeof(stTSTA));
		}
		nifl->WriteAligned();
	}
	else{
		objc[0].tsta_offset = 0;
	}

	// TSET
	if(objc[0].tset_count){
		objc[0].tset_offset = nifl->REL0_Tell();
		for(unsigned int i=0;i<objc[0].tset_count;i++){
			nifl->REL0_Write(&tset[i], sizeof(stTSET));
		}
		nifl->WriteAligned();
	}
	else{
		objc[0].tset_offset = 0;
	}

	// TEXF
	if(objc[0].texf_count){
		objc[0].texf_offset = nifl->REL0_Tell();
		for(unsigned int i=0;i<objc[0].texf_count;i++){
			nifl->REL0_Write(&texf[i], sizeof(stTEXF));
		}
		nifl->WriteAligned();
	}
	else{
		objc[0].texf_offset = 0;
	}

	// UNRM
	if(unrm != NULL){
		objc[0].unrm_offset = nifl->REL0_Tell();
		for(unsigned int i=0;i<1;i++){
			nifl->REL0_Write(&unrm[i], sizeof(stUNRM));
		}
		nifl->WriteAligned();

		for(unsigned int i=0;i<1;i++){
			if(unrm[i]._u_data1_count){
				unrm[i]._u_data1_offset = nifl->REL0_Tell();
				nifl->REL0_Write(_u_data1[i], sizeof(unsigned int) * unrm[i]._u_data1_count);
				nifl->WriteAligned();
			}
			else{
				unrm[i]._u_data1_offset = 0;
			}

			if(unrm[i]._u_data2_count){
				unrm[i]._u_data2a_offset = nifl->REL0_Tell();
				nifl->REL0_Write(_u_data2a[i], sizeof(unsigned int) * unrm[i]._u_data2_count);
				nifl->WriteAligned();
				unrm[i]._u_data2b_offset = nifl->REL0_Tell();
				nifl->REL0_Write(_u_data2b[i], sizeof(unsigned int) * unrm[i]._u_data2_count);
				nifl->WriteAligned();
			}
			else{
				unrm[i]._u_data2a_offset = 0;
				unrm[i]._u_data2b_offset = 0;
			}
		}
	}
	// REL0のサイズ情報更新
	nifl->REL0_SetSize();

	// NOF0生成
	nifl->NOF0_SetOffset();
	nifl->NOF0_SetCount(0);
	nifl->NOF0_WriteHeader();
	nifl->WriteAligned();

	if(objc[0].vset_count) nifl->NOF0_Write(nifl->REL0_GetEntry() + 0x28); // VSET
	if(objc[0].pset_count) nifl->NOF0_Write(nifl->REL0_GetEntry() + 0x30); // PSET
	if(objc[0].mesh_count) nifl->NOF0_Write(nifl->REL0_GetEntry() + 0x38); // MESH
	if(objc[0].mate_count) nifl->NOF0_Write(nifl->REL0_GetEntry() + 0x40); // MATE
	if(objc[0].rend_count) nifl->NOF0_Write(nifl->REL0_GetEntry() + 0x48); // REND
	if(objc[0].shad_count) nifl->NOF0_Write(nifl->REL0_GetEntry() + 0x50); // SHAD
	if(objc[0].tsta_count) nifl->NOF0_Write(nifl->REL0_GetEntry() + 0x58); // TSTA
	if(objc[0].tset_count) nifl->NOF0_Write(nifl->REL0_GetEntry() + 0x60); // TSET
	if(objc[0].texf_count) nifl->NOF0_Write(nifl->REL0_GetEntry() + 0x68); // TEXF
	if(unrm != NULL) nifl->NOF0_Write(nifl->REL0_GetEntry() + 0xa0); // UNRM

	for(unsigned int i=0;i<objc[0].vset_count;i++){
		nifl->NOF0_Write(objc[0].vset_offset + sizeof(stVSET) * i + 0x08); // VTXE
		nifl->NOF0_Write(objc[0].vset_offset + sizeof(stVSET) * i + 0x10); // VTXL
		if(vset[i].bonepalette_count){
			nifl->NOF0_Write(objc[0].vset_offset + sizeof(stVSET) * i + 0x1c); // Bone Palette
		}
		if(vset[i].bonepalette2_count){
			nifl->NOF0_Write(objc[0].vset_offset + sizeof(stVSET) * i + 0x30); // Bone Palette 2
		}
	}

	for(unsigned int i=0;i<objc[0].pset_count;i++){
		nifl->NOF0_Write(objc[0].pset_offset + sizeof(stPSET) * i + 0x08); // FACE count offset
		nifl->NOF0_Write(objc[0].pset_offset + sizeof(stPSET) * i + 0x10); // FACE data offset
	}
	if(unrm != NULL){
		if(unrm[0]._u_data1_count) nifl->NOF0_Write(objc[0].unrm_offset + 0x04); // UNRM data1
		if(unrm[0]._u_data2_count){
			nifl->NOF0_Write(objc[0].unrm_offset + 0x0c); // UNRM data2a
			nifl->NOF0_Write(objc[0].unrm_offset + 0x10); // UNRM data2b
		}
	}
	nifl->WriteAligned();
	nifl->NOF0_SetSize();

	nifl->NIFL_WriteFooter();
	nifl->WriteAligned();

	// ヘッダ情報更新
	nifl->NIFL_WriteHeader();
	nifl->REL0_WriteHeader();
	nifl->NOF0_WriteHeader();

	// 変更になったオフセッット情報を更新
	// OBJC
	nifl->REL0_Seek(nifl->REL0_GetEntry());
	nifl->REL0_Write(&objc[0], sizeof(stOBJC));
	// VSET
	nifl->REL0_Seek(objc[0].vset_offset);
	for(unsigned int i=0;i<objc[0].vset_count;i++) nifl->REL0_Write(&vset[i], sizeof(stVSET));
	// PSET
	nifl->REL0_Seek(objc[0].pset_offset);
	for(unsigned int i=0;i<objc[0].pset_count;i++) nifl->REL0_Write(&pset[i], sizeof(stPSET));
	// UNRM
	if(unrm != NULL){
		nifl->REL0_Seek(objc[0].unrm_offset);
		for(unsigned int i=0;i<1;i++) nifl->REL0_Write(&unrm[i], sizeof(stUNRM));
	}

	return true;
}

//--------------------------------------------------
// MTL Write
//--------------------------------------------------
void clAQO::WriteMTL(FILE *fpw_mtl){

	//Declare texture string array
	//tsta = new stTSTA[objc[0].tsta_count];

	//Declare texture sets
	//tset = new stTSET[objc[0].tset_count];

	//Loop materials and write
	for (unsigned int i = 0; i<objc[0].vset_count; i++)
	{
		// Get texture set index for the loop
		int texID = mesh[i].tset_index;
		fprintf(fpw_mtl, "newmtl mtl_%d_%d\n", mesh[i].mate_index, texID);

		fprintf(fpw_mtl, "	Ka 0.00000000 0.00000000 0.00000000\n");
		fprintf(fpw_mtl, "	Kd 1.00000000 1.00000000 1.00000000\n");
		fprintf(fpw_mtl, "	Ks 0.50000000 0.50000000 0.50000000\n");
		fprintf(fpw_mtl, "	Ke 0.00000000 0.00000000 0.00000000\n");

		// Check each texture id to be sure it's valid

		// diffuse
		if (tset[texID]._75[0] != -1)
		{
			fprintf(fpw_mtl, "	map_Kd %s\n", tsta[tset[texID]._75[0]]._6c);
		}
		else
		{
			fprintf(fpw_mtl, "	map_Kd default.dds\n");
		}
		
		// specular
		if (tset[texID]._75[1] != -1)
		{
			fprintf(fpw_mtl, "	map_Ks %s\n", tsta[tset[texID]._75[1]]._6c);
		}
		else
		{
			fprintf(fpw_mtl, "	map_Kd default.dds\n");
		}
		
		// reflection
		if (tset[texID]._75[2] != -1)
		{
			fprintf(fpw_mtl, "	map_refl %s\n", tsta[tset[texID]._75[2]]._6c);
		}
		else
		{
			fprintf(fpw_mtl, "	map_Kd default.dds\n");
		}
		
		// normal
		if (tset[texID]._75[3] != -1)
		{
			fprintf(fpw_mtl, "	map_Bump %s\n\n", tsta[tset[texID]._75[3]]._6c);
		}
		else
		{
			fprintf(fpw_mtl, "	map_Kd default.dds\n\n");
		}
		
	}
}

//--------------------------------------------------
// エクスポート(OBJ)
//--------------------------------------------------
bool clAQO::ExportObj(const char *filename){

	// OBJファイル名編集
	unsigned int filename_obj_size = strlen(filename) + 0x10;
	char *filename_obj = new char[filename_obj_size];
	if(filename_obj != NULL){
		memset(filename_obj, 0x00, filename_obj_size);
		strcpy_s(filename_obj, filename_obj_size, filename);
		char *p = strchr(filename_obj, '.');
		if(p == NULL){
			strcat_s(filename_obj, filename_obj_size, ".obj");
		}
	}

	// MTLファイル名編集
	unsigned int filename_mtl_size = strlen(filename) + 0x10;
	char *filename_mtl = new char[filename_mtl_size];
	if(filename_mtl != NULL){
		memset(filename_mtl, 0x00, filename_mtl_size);
		strcpy_s(filename_mtl, filename_mtl_size, filename);
		char *p = strchr(filename_mtl, '.');
		if(p != NULL) *p = '\0';
		strcat_s(filename_mtl, filename_mtl_size, ".mtl");
	}

	// OBJファイルオープン
	FILE *fpw_obj = NULL;
	if(fopen_s(&fpw_obj, filename_obj, "w")){
		printf("Error: File can't open. output(.obj)=[%s]\n", filename_obj);
		return false;
	}

	// MTLファイルオープン
	FILE *fpw_mtl = NULL;
	if(fopen_s(&fpw_mtl, filename_mtl, "w")){
		printf("Error: File can't open. output(.mtl)=[%s]\n", filename_mtl);
		fclose(fpw_obj);
		delete [] filename_mtl;
		delete [] filename_obj;
		return false;
	}

	//Write filename
	fprintf(fpw_mtl, "# %s\n", get_filename_ptr(filename_mtl));
	WriteMTL(fpw_mtl);

	
	// Write mtllib text
	fprintf(fpw_obj, "mtllib %s", get_filename_ptr(filename_mtl));

	/********** VTXE,VTXL **********/

	unsigned int v_index = 0;
	for(unsigned int i=0;i<objc[0].vset_count;i++){
		fprintf(fpw_obj, "\n\n");
		fprintf(fpw_obj, "g mesh%d_%d_%d_%d_%d\n", i, mesh[i].mate_index, mesh[i].rend_index, mesh[i].shad_index, mesh[i].tset_index);
		fprintf(fpw_obj, "o mesh%d_%d_%d_%d_%d\n", i, mesh[i].mate_index, mesh[i].rend_index, mesh[i].shad_index, mesh[i].tset_index);
		fprintf(fpw_obj, "usemtl mtl_%d_%d\n", mesh[i].mate_index, mesh[i].tset_index);
		if (vset[i].bonepalette_count > 0)
		{
			fprintf(fpw_obj, "bp ");
			for (unsigned int j = 0; j < vset[i].bonepalette_count; j++) 
			{
				fprintf(fpw_obj, "%d ", bonepalette[i][j]);
			}
			fprintf(fpw_obj, "\n");
		}

		for(unsigned int j=0;j<vset[i].vtxe_count;j++){

			switch(vtxe[i][j].type){
			case 0x00000000: // Bind Position Buffer
				{
					for(unsigned int k=0;k<vset[i].vtxl_count;k++){
						stPosition p;
						memset(&p, 0x00, sizeof(p));
						memcpy(&p, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(p));
						fprintf(fpw_obj, "v %f %f %f\n", p.x, p.y, p.z);
					}
				}
				break;
			case 0x00000001: // Bind Bone Weight Buffer
			{
				for (unsigned int k = 0; k<vset[i].vtxl_count; k++) {
					stBone p;
					memset(&p, 0x00, sizeof(p));
					memcpy(&p, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(p));
					fprintf(fpw_obj, "bw %f %f %f %f\n", p.x, p.y, p.z, p.w);
				}
			}
			break;
			case 0x00000002: // Bind Normal Buffer
				{
					for(unsigned int k=0;k<vset[i].vtxl_count;k++){
						stPosition p;
						memset(&p, 0x00, sizeof(p));
						memcpy(&p, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(p));
						fprintf(fpw_obj, "vn %f %f %f\n", p.x, p.y, p.z);
					}
				}
				break;
			case 0x00000003: // Bind Vert Color Buffer
			{
				for (unsigned int k = 0; k<vset[i].vtxl_count; k++) {
					stColor p;
					memset(&p, 0x00, sizeof(p));
					memcpy(&p, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(p));
					fprintf(fpw_obj, "vc %u %u %u %u\n", p.r, p.g, p.b, p.a);
				}
			}
			break;
			case 0x0000000b: // Bind Bone Index Buffer
			{
				for (unsigned int k = 0; k<vset[i].vtxl_count; k++) {
					stColor p;
					memset(&p, 0x00, sizeof(p));
					memcpy(&p, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(p));
					fprintf(fpw_obj, "bi %u %u %u %u\n", p.b, p.g, p.r, p.a);
				}
			}
			break;
			case 0x00000010: // Bind UV1 Buffer
				{
					for(unsigned int k=0;k<vset[i].vtxl_count;k++){
						stUV p;
						memset(&p, 0x00, sizeof(p));
						memcpy(&p, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(p));
						fprintf(fpw_obj, "vt %f %f\n", p.u, p.v);
					}
				}
				break;
			case 0x00000011: // Bind UV2 Buffer
			{
				for (unsigned int k = 0; k<vset[i].vtxl_count; k++) {
					stUV p;
					memset(&p, 0x00, sizeof(p));
					memcpy(&p, vtxl_buff[i][k] + vtxe[i][j].pos, sizeof(p));
					fprintf(fpw_obj, "vu %f %f\n", p.u, p.v);
				}
			}
			break;
			}
		}

		fprintf(fpw_obj, "\n");
		for(unsigned int j=0;j<pset[i].face_count-2;j++){
			if(j & 1){
				fprintf(fpw_obj, "f %d/%d/%d %d/%d/%d %d/%d/%d\n",
					face[i][j  ]+v_index+1, face[i][j  ]+v_index+1, face[i][j  ]+v_index+1,
					face[i][j+2]+v_index+1, face[i][j+2]+v_index+1, face[i][j+2]+v_index+1,
					face[i][j+1]+v_index+1, face[i][j+1]+v_index+1, face[i][j+1]+v_index+1);
			}
			else{
				fprintf(fpw_obj, "f %d/%d/%d %d/%d/%d %d/%d/%d\n",
					face[i][j  ]+v_index+1, face[i][j  ]+v_index+1, face[i][j  ]+v_index+1,
					face[i][j+1]+v_index+1, face[i][j+1]+v_index+1, face[i][j+1]+v_index+1,
					face[i][j+2]+v_index+1, face[i][j+2]+v_index+1, face[i][j+2]+v_index+1);
			}
		}
		v_index += vset[i].vtxl_count;
	}

	/*
	char map_kd[512];
	memset(map_kd, 0x00, sizeof(map_kd));
	memcpy(map_kd, texf[0]._80, strlen(texf[0]._80));
	//char *p = get_path(g.input_filename);
	char *p = get_path(filename);
	if(!strlen(p)){
		p = new char [512];
		GetCurrentDirectory(512, p);
		strcat_s(p, 512, "\\");
	}
	int sz = strlen(p) + strlen(texf[0]._80) + 1;
	struct _finddata_t file;
	long find;
	memset(&file, 0x00, sizeof(file));
	char *full_path = new char [sz];
	memset(full_path, 0x00, sz);
	strcpy_s(full_path, sz, p);
	strcat_s(full_path, sz, texf[0]._80);
	if((find = _findfirst(full_path, &file)) == -1L){
		sz = strlen(p) + strlen("*_d_*.dds") + 1;
		char *search_str = new char[sz];
		memset(search_str, 0x00, sz);
		strcpy_s(search_str, sz, p);
		strcat_s(search_str, sz, "*_d_*.dds");
		if((find = _findfirst(search_str, &file)) != -1L){
			memset(map_kd, 0x00, sizeof(map_kd));
			strcpy_s(map_kd, sizeof(map_kd), file.name);
			_findclose(find);
		}
	}
	
	delete [] full_path;
	delete [] p;

	fprintf(fpw_mtl, "map_Kd %s\n", map_kd);*/

	if(fpw_mtl != NULL) fclose(fpw_mtl);
	if(fpw_obj != NULL) fclose(fpw_obj);

	delete [] filename_mtl;
	delete [] filename_obj;

	return true;
}

//--------------------------------------------------
// VTBF形式読み込み
//--------------------------------------------------
bool clAQO::LoadVTBF(clVTBF *vtbf){
	clVTBF::stVTBF_header h;
	memset(&h, 0x00, sizeof(h));
	unsigned short h1, h2;
	unsigned int vtxe_index = 0;
	unsigned int vtxl_index = 0;
	while(vtbf->ReadHeader(&h)){
		switch(h.subChunkType){
			// ----- OBJC -----
			case 0x434a424f:
			{
				objc = new stOBJC[1];
				memset(objc, 0x00, sizeof(stOBJC));
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0x10: { vtbf->GetUINT(buf, &pos, &objc[0]._10); break; }
						case 0x11: { vtbf->GetUINT(buf, &pos, &objc[0]._11); break; }
						case 0x12: { vtbf->GetUINT(buf, &pos, &objc[0]._12); break; }
						case 0x13: { vtbf->GetUINT(buf, &pos, &objc[0]._13); break; }
						case 0x14: { vtbf->GetUINT(buf, &pos, &objc[0].face_count_total); break; }
						case 0x15: { vtbf->GetUINT(buf, &pos, &objc[0].vtxl_count_total); break; }
						case 0x16: { vtbf->GetUINT(buf, &pos, &objc[0]._16); break; }
						case 0x24: { vtbf->GetUINT(buf, &pos, &objc[0].vset_count); break; }
						case 0x25: { vtbf->GetUINT(buf, &pos, &objc[0].pset_count); break; }
						case 0x17: { vtbf->GetUINT(buf, &pos, &objc[0].mesh_count); break; }
						case 0x18: { vtbf->GetUINT(buf, &pos, &objc[0].mate_count); break; }
						case 0x19: { vtbf->GetUINT(buf, &pos, &objc[0].rend_count); break; }
						case 0x1a: { vtbf->GetUINT(buf, &pos, &objc[0].shad_count); break; }
						case 0x1b: { vtbf->GetUINT(buf, &pos, &objc[0].tsta_count); break; }
						case 0x1c: { vtbf->GetUINT(buf, &pos, &objc[0].tset_count); break; }
						case 0x1d: { vtbf->GetUINT(buf, &pos, &objc[0].texf_count); break; }
						case 0x1e: { memcpy(&objc[0]._1e, buf + pos + 3, 48); pos += 3 + 48; break; }
						default: { pos += 2 + sizeof(unsigned int); break; }
					}
				}
				delete [] buf;
				break;
			}
			// ----- VSET -----
			case 0x54455356:
			{
				vset = new stVSET[objc[0].vset_count];
				memset(vset, 0x00, sizeof(stVSET) * objc[0].vset_count);
				vtxe = new stVTXE *[objc[0].vset_count];
				vtxl_buff = new unsigned char **[objc[0].vset_count];
				bonepalette = new unsigned short *[objc[0].vset_count];
				bonepalette2 = new unsigned short *[objc[0].vset_count];
				for(unsigned int i=0;i<objc[0].vset_count;i++){
					bonepalette[i] = NULL;
					bonepalette2[i] = NULL;
				}
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0, index = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0xfc: { index = 0; pos += 2; break; }
						case 0xfe: { index++; pos += 2; break; }
						case 0xfd: { pos += 2; break; }
						case 0xb6: { vtbf->GetUINT(buf, &pos, &vset[index].vert_size); break; }
						case 0xb9: { vtbf->GetUINT(buf, &pos, &vset[index].vtxl_count); break; }
						case 0xbe:
						{
							if(*(buf + pos + 1) == 0x86){
								unsigned int count = *(buf + pos + 3) + 1;
								vset[index].bonepalette_count = count;
								bonepalette[index] = new unsigned short[count];
								memcpy(bonepalette[index], buf + pos + 4, sizeof(unsigned short) * count);
								pos += 4 + sizeof(unsigned short) * count;
							}
							else{
								pos += 2 + sizeof(unsigned int); // here
								//printf("%d: here = %02X %02X\n", index, *(buf + pos), *(buf + pos + 1));
							}
							break;
						}
						case 0xca:
						{
							if(*(buf + pos + 1) == 0x86){
								unsigned int count = *(buf + pos + 3) + 1;
								vset[index].bonepalette2_count = count;
								bonepalette2[index] = new unsigned short[count];
								memcpy(bonepalette2[index], buf + pos + 4, sizeof(unsigned short) * count);
								pos += 4 + sizeof(unsigned short) * count;
							}
							else{
								pos += 2 + sizeof(unsigned int); // here
								//printf("%d: here = %02X %02X\n", index, *(buf + pos), *(buf + pos + 1));
							}
							break;
						}
						case 0xbf: { vtbf->GetUINT(buf, &pos, &vset[index].vtxe_count); break; }
						default: { 
							//printf("%d: unknown = %02X %02X\n", index, *(buf + pos), *(buf + pos + 1));
							pos += 2 + sizeof(unsigned int); break;
						}
					}
				}
				delete [] buf;
				break;
			}
			// ----- VTXE -----
			case 0x45585456:
			{
				vtxe[vtxe_index] = new stVTXE [vset[vtxe_index].vtxe_count];
				memset(vtxe[vtxe_index], 0x00, sizeof(stVTXE) * vset[vtxe_index].vtxe_count);
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0, index = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0xfc: { index = 0; pos += 2; break; }
						case 0xfe: { index++; pos += 2; break; }
						case 0xfd: { pos += 2; break; }
						case 0xd0: { vtbf->GetUINT(buf, &pos, &vtxe[vtxe_index][index].type); break; }
						case 0xd1: { vtbf->GetUINT(buf, &pos, &vtxe[vtxe_index][index].type2); break; }
						case 0xd2: { vtbf->GetUINT(buf, &pos, &vtxe[vtxe_index][index].pos); break; }
						default: { pos += 2 + sizeof(unsigned int); break; }
					}
				}
				vtxe_index++;
				delete [] buf;
				break;
			}
			// ----- VTXL -----
			case 0x4c585456:
			{
				vtxl_buff[vtxl_index] = new unsigned char *[vset[vtxl_index].vtxl_count];
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 2;
				if(*(buf + pos) == 8){
					pos += 1 + 1;
				}
				else if(*(buf + pos) == 24){
					pos += 1 + 4;
				}
				else{
					pos += 1 + 2;
				}
				for(unsigned int i=0;i<vset[vtxl_index].vtxl_count;i++){
					vtxl_buff[vtxl_index][i] = new unsigned char[vset[vtxl_index].vert_size];
					memcpy(vtxl_buff[vtxl_index][i], buf + pos, vset[vtxl_index].vert_size);
					pos += vset[vtxl_index].vert_size;
				}
				vtxl_index++;
				delete [] buf;
				break;
			}
			// ----- MESH -----
			case 0x4853454d:
			{
				mesh = new stMESH[objc[0].mesh_count];
				memset(mesh, 0x00, sizeof(stMESH) * objc[0].mesh_count);
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0, index = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0xfc: { index = 0; pos += 2; break; }
						case 0xfe: { index++; pos += 2; break; }
						case 0xfd: { pos += 2; break; }
						case 0xb0: { vtbf->GetUINT(buf, &pos, &mesh[index]._b0); break; }
						case 0xc7: { vtbf->GetUINT(buf, &pos, &mesh[index]._c7); break; }
						case 0xb1: { vtbf->GetUINT(buf, &pos, &mesh[index].mate_index); break; }
						case 0xb2: { vtbf->GetUINT(buf, &pos, &mesh[index].rend_index); break; }
						case 0xb3: { vtbf->GetUINT(buf, &pos, &mesh[index].shad_index); break; }
						case 0xb4: { vtbf->GetUINT(buf, &pos, &mesh[index].tset_index); break; }
						case 0xb5: { vtbf->GetUINT(buf, &pos, &mesh[index]._b5); break; }
						case 0xc0: { vtbf->GetUINT(buf, &pos, &mesh[index]._c0); break; }
						case 0xc1: { vtbf->GetUINT(buf, &pos, &mesh[index]._c1); break; }
						case 0xcd: { vtbf->GetUINT(buf, &pos, &mesh[index]._cd); break; }
						case 0xc2: { vtbf->GetUINT(buf, &pos, &mesh[index]._c2); break; }
						default: { pos += 2 + sizeof(unsigned int); break; }
					}
				}
				delete [] buf;
				break;
			}
			// ----- PSET -----
			case 0x54455350:
			{
				pset = new stPSET[objc[0].pset_count];
				memset(pset, 0x00, sizeof(stPSET) * objc[0].pset_count);
				face = new unsigned short *[objc[0].pset_count];
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0, index = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0xfc: { index = 0; pos += 2; break; }
						case 0xfe: { index++; pos += 2; break; }
						case 0xfd: { pos += 2; break; }
						case 0xc6: { vtbf->GetUINT(buf, &pos, &pset[index]._c6); break; }
						case 0xbb: { vtbf->GetUINT(buf, &pos, &pset[index]._bb); break; }
						case 0xbc: { vtbf->GetUINT(buf, &pos, &pset[index].face_count); break; }
						case 0xc5: { pos += 2 + sizeof(unsigned int); break; }
						case 0xb8: {
							face[index] = new unsigned short[pset[index].face_count];
							vtbf->GetUSHORT_Array(buf, &pos, face[index]);
							break;
						}
						default: { pos += 2 + sizeof(unsigned int); break; }
					}
				}
				delete [] buf;
				break;
			}
			// ----- MATE -----
			case 0x4554414d:
			{
				mate = new stMATE[objc[0].mate_count];
				memset(mate, 0x00, sizeof(stMATE) * objc[0].mate_count);
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0, index = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0xfc: { index = 0; pos += 2; break; }
						case 0xfe: { index++; pos += 2; break; }
						case 0xfd: { pos += 2; break; }
						case 0x30: { memcpy(mate[index]._30, buf + pos + 3, 16); pos += 3 + 16; break; }
						case 0x31: { memcpy(mate[index]._31, buf + pos + 3, 16); pos += 3 + 16; break; }
						case 0x32: { memcpy(mate[index]._32, buf + pos + 3, 16); pos += 3 + 16; break; }
						case 0x33: { memcpy(mate[index]._33, buf + pos + 3, 16); pos += 3 + 16; break; }
						case 0x34: { vtbf->GetUINT(buf, &pos, &mate[index]._34); break; }
						case 0x35: { vtbf->GetUINT(buf, &pos, &mate[index]._35); break; }
						case 0x36: { vtbf->GetUINT(buf, &pos, &mate[index]._36); break; }
						case 0x37: { vtbf->GetUINT(buf, &pos, &mate[index]._37); break; }
						case 0x38: { vtbf->GetUINT(buf, &pos, &mate[index]._38); break; }
						case 0x3a: { vtbf->GetCHAR(buf, &pos, mate[index]._3a); break; }
						case 0x39: { vtbf->GetCHAR(buf, &pos, mate[index]._39); break; }
						default: { pos += 2 + sizeof(unsigned int); break; }
					}
				}
				delete [] buf;
				break;
			}
			// ----- REND -----
			case 0x444e4552:
			{
				rend = new stREND[objc[0].rend_count];
				memset(rend, 0x00, sizeof(stREND) * objc[0].rend_count);
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0, index = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0xfc: { index = 0; pos += 2; break; }
						case 0xfe: { index++; pos += 2; break; }
						case 0xfd: { pos += 2; break; }
						case 0x40: { vtbf->GetUINT(buf, &pos, &rend[index]._40); break; }
						case 0x41: { vtbf->GetUINT(buf, &pos, &rend[index]._41); break; }
						case 0x42: { vtbf->GetUINT(buf, &pos, &rend[index]._42); break; }
						case 0x43: { vtbf->GetUINT(buf, &pos, &rend[index]._43); break; }
						case 0x44: { vtbf->GetUINT(buf, &pos, &rend[index]._44); break; }
						case 0x45: { vtbf->GetUINT(buf, &pos, &rend[index]._45); break; }
						case 0x46: { vtbf->GetUINT(buf, &pos, &rend[index]._46); break; }
						case 0x47: { vtbf->GetUINT(buf, &pos, &rend[index]._47); break; }
						case 0x48: { vtbf->GetUINT(buf, &pos, &rend[index]._48); break; }
						case 0x49: { vtbf->GetUINT(buf, &pos, &rend[index]._49); break; }
						case 0x4a: { vtbf->GetUINT(buf, &pos, &rend[index]._4a); break; }
						case 0x4b: { vtbf->GetUINT(buf, &pos, &rend[index]._4b); break; }
						case 0x4c: { vtbf->GetUINT(buf, &pos, &rend[index]._4c); break; }
						case 0x4d: { vtbf->GetUINT(buf, &pos, &rend[index]._4d); break; }
						case 0x4e: { vtbf->GetUINT(buf, &pos, &rend[index]._4e); break; }
						case 0x4f: { vtbf->GetUINT(buf, &pos, &rend[index]._4f); break; }
						case 0x50: { vtbf->GetUINT(buf, &pos, &rend[index]._50); break; }
						default: { pos += 2 + sizeof(unsigned int); break; }
					}
				}
				delete [] buf;
				break;
			}
			// ----- SHAD -----
			case 0x44414853:
			{
				shad = new stSHAD[objc[0].shad_count];
				memset(shad, 0x00, sizeof(stSHAD) * objc[0].shad_count);
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0, index = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0xfc: { index = 0; pos += 2; break; }
						case 0xfe: { index++; pos += 2; break; }
						case 0xfd: { pos += 2; break; }
						case 0x90: { vtbf->GetUINT(buf, &pos, &shad[index]._90); break; }
						case 0x91: { vtbf->GetCHAR(buf, &pos, shad[index]._91); break; }
						case 0x92: { vtbf->GetCHAR(buf, &pos, shad[index]._92); break; }
						case 0x93: { vtbf->GetUINT(buf, &pos, &shad[index]._93); break; }
						default: { pos += 2 + sizeof(unsigned int); break; }
					}
				}
				delete [] buf;
				break;
			}
			// ----- SHAP -----
			case 0x50414853:
			{
				vtbf->Skip(&h);
				break;
			}
			// ----- TSTA -----
			case 0x41545354:
			{
				tsta = new stTSTA[objc[0].tsta_count];
				memset(tsta, 0x00, sizeof(stTSTA) * objc[0].tsta_count);
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0, index = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0xfc: { index = 0; pos += 2; break; }
						case 0xfe: { index++; pos += 2; break; }
						case 0xfd: { pos += 2; break; }
						case 0x60: { vtbf->GetUINT(buf, &pos, &tsta[index]._60); break; }
						case 0x61: { vtbf->GetUINT(buf, &pos, &tsta[index]._61); break; }
						case 0x62: { vtbf->GetUINT(buf, &pos, &tsta[index]._62); break; }
						case 0x63: { memcpy(tsta[index]._63, buf + pos + 3, 12); pos += 3 + 12; break; }
						case 0x64: { vtbf->GetUINT(buf, &pos, &tsta[index]._64); break; }
						case 0x65: { vtbf->GetUINT(buf, &pos, &tsta[index]._65); break; }
						case 0x66: { vtbf->GetUINT(buf, &pos, &tsta[index]._66); break; }
						case 0x67: { vtbf->GetUINT(buf, &pos, &tsta[index]._67); break; }
						case 0x68: { vtbf->GetUINT(buf, &pos, &tsta[index]._68); break; }
						case 0x69: { vtbf->GetUINT(buf, &pos, &tsta[index]._69); break; }
						case 0x6a: { vtbf->GetUINT(buf, &pos, &tsta[index]._6a); break; }
						case 0x6b: { vtbf->GetUINT(buf, &pos, &tsta[index]._6b); break; }
						case 0x6c: { vtbf->GetCHAR(buf, &pos, tsta[index]._6c); break; }
						default: { pos += 2 + sizeof(unsigned int); break; }
					}
				}
				delete [] buf;
				break;
			}
			// ----- TSET -----
			case 0x54455354:
			{
				tset = new stTSET[objc[0].tset_count];
				memset(tset, 0x00, sizeof(stTSET) * objc[0].tset_count);
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0, index = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0xfc: { index = 0; pos += 2; break; }
						case 0xfe: { index++; pos += 2; break; }
						case 0xfd: { pos += 2; break; }
						case 0x70: { vtbf->GetUINT(buf, &pos, &tset[index]._70); break; }
						case 0x71: { vtbf->GetUINT(buf, &pos, &tset[index]._71); break; }
						case 0x72: { vtbf->GetUINT(buf, &pos, &tset[index]._72); break; }
						case 0x73: { vtbf->GetUINT(buf, &pos, &tset[index]._73); break; }
						case 0x74: { vtbf->GetUINT(buf, &pos, &tset[index]._74); break; }
						case 0x75: { vtbf->GetUINT_Array(buf, &pos, tset[index]._75); break; }
						default: { pos += 2 + sizeof(unsigned int); break; }
					}
				}
				delete [] buf;
				break;
			}
			// ----- TEXF -----
			case 0x46584554:
			{
				texf = new stTEXF[objc[0].texf_count];
				memset(texf, 0x00, sizeof(stTEXF) * objc[0].texf_count);
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0, index = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0xfc: { index = 0; pos += 2; break; }
						case 0xfe: { index++; pos += 2; break; }
						case 0xfd: { pos += 2; break; }
						case 0x80: { vtbf->GetCHAR(buf, &pos, texf[index]._80); break; }
						default: { pos += 2 + sizeof(unsigned int); break; }
					}
				}
				delete [] buf;
				break;
			}
			// ----- UNRM -----
			case 0x4d524e55:
			{
				unrm = new stUNRM[1];
				_u_data1 = new unsigned int *[1];
				_u_data2a = new unsigned int *[1];
				_u_data2b = new unsigned int *[1];
				unsigned char *buf = vtbf->ReadData(&h, &h1, &h2);
				unsigned int pos = 0, index = 0;
				while(pos < h.chunkSize - 8){
					switch(*(buf + pos)){
						case 0xfc: { index = 0; pos += 2; break; }
						case 0xfe: { index++; pos += 2; break; }
						case 0xfd: { pos += 2; break; }
						case 0xda: { vtbf->GetUINT(buf, &pos, &unrm[index]._u_data1_count); break; }
						case 0xdb: {
							_u_data1[index] = new unsigned int[unrm[index]._u_data1_count];
							vtbf->GetUINT_Array(buf, &pos, _u_data1[index]);
							break;
						}
						case 0xdc: { vtbf->GetUINT(buf, &pos, &unrm[index]._u_data2_count); break; }
						case 0xdd: {
							_u_data2a[index] = new unsigned int[unrm[index]._u_data2_count];
							vtbf->GetUINT_Array(buf, &pos, _u_data2a[index]);
							break;
						}
						case 0xde: {
							_u_data2b[index] = new unsigned int[unrm[index]._u_data2_count];
							vtbf->GetUINT_Array(buf, &pos, _u_data2b[index]);
							break;
						}
						default: { pos += 2 + sizeof(unsigned int); break; }
					}
				}
				delete [] buf;
				break;
			}
			// ----- ???? -----
			default:
			{
				vtbf->Skip(&h);
				break;
			}
		}
	}
	return true;
}
