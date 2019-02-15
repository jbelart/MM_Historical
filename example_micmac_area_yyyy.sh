#!/bin/bash
source mm_func.sh

#INPUT NEEDED:
#XXX_poe.txt; XXX_gcps.txt XXX_img.txt XXX_imagenames.txt

area=Hrutfell
yr=1995

foc=152.8200
sres=0.015

ref=/data/icesat/travail_en_cours/joaquin/Oraefajokull/Oraefajokull_Lidar_2010_og_2011_og_2012_4x4m_ellipsoid_fx.tif
img=".*flipud.tif"

chantier

echo "\n----------------------------------\n- CALCULATION OF POE AND COUPLES -\n----------------------------------"

poe_isn93_2_local ${area}_${yr}_poe
mm3d OriConvert OriTxtInFile ${area}_${yr}_poe-local.csv Ini-ISN93 MTD1=1 NameCple=FileImagesNeighbour_${area}_${yr}.xml

echo "\n-------------------------\n- TIE POINT COMPUTATION -\n-------------------------"

#mm3d Tapioca MulScale ".*.tif" 500 5000 ByP=32
mm3d Tapioca File FileImagesNeighbour_${area}_${yr}.xml 3000 ByP=32

echo "\n-------------------------\n- ORIENTATION: RELATIVE -\n-------------------------"

mm3d schnaps ${img} NbWin=1000
mm3d Tapas RadialBasic ${img} InOri=Ini-ISN93 Out=Rel1_${area}_${yr} SH=_mini
mm3d Tapas Fraser ${img} InCal=Rel1_${area}_${yr} InOri=Ini-ISN93 Out=Rel_${area}_${yr} LibFoc=0
#AperiCloud ${img} Rel_${area}_${yr} Out=Rel_${area}_${yr}.ply Bin=0 WithPoints=1

echo "\n-------------------------\n- ORIENTATION: ABSOLUTE -\n-------------------------"

gcp_ascii_2_mm ${area}_${yr}_gcps ${area}_${yr}_img ${area}_${yr}_imagenames
GCPBascule ${img} Rel_${area}_${yr} Bascule_${area}_${yr} ${area}_${yr}_GCPs_local.xml ${area}_${yr}_MM_img.xml 
Campari ${img} Bascule_${area}_${yr} Campari_${area}_${yr} GCP=[${area}_${yr}_GCPs_local.xml,1,${area}_${yr}_MM_img.xml,1] NbLiais=1000 AllFree=1 SH=_mini
#AperiCloud ${img} Campari_${area}_${yr} Out=Campari_${area}_${yr}.ply Bin=0 WithPoints=1
#check_abs_ori Campari_${area}_${yr}.ply noschnaps

#######################################################
##### SGM: $1 -> Py (Py0 to Py3) $2 -> PxSize DEM #####
#######################################################

sgm 0 5

###############################################################
#### Ortho: $1 -> PxSize Ortho $2 -> method (tawny / gdal) ####
###############################################################

ortho 0.5 gdal

echo "\n-------\n- END -\n-------"
