#!/bin/bash

source ~/shgen/mm_func_2020.sh

proj='+proj=lcc +lat_1=64.25 +lat_2=65.75 +lat_0=65 +lon_0=-19 +x_0=500000 +y_0=500000 +ellps=WGS84 +datum=WGS84 +units=m +no_defs'
gcpproj='+proj=lcc +lat_1=64.25 +lat_2=65.75 +lat_0=65 +lon_0=-19 +x_0=2700000 +y_0=300000 +ellps=GRS80 +units=m +no_defs'

loc3D='iceland'

ref=$idem_zmae
frames=/u01/jmcb/loftm/data/hofsj95/
cd $frames
sres=0.015

gcpnam=hofsj95_s8

cat > "$gcpnam.gcps" << EOF
GCP001 2698250.345 264222.444 8-3679_crp.tif 7909.33610 11881.44589 8-3680_crp.tif 12882.81347 12012.13098
#GCP002 2700467.777 258322.760 8-3679_crp.tif 3190.61193 896.73024 8-3680_crp.tif 8138.44856 880.18782
GCP003 2703357.435 259551.011 8-3680_crp.tif 2828.33302 3305.85742 8-3681_crp.tif 7568.01091 3091.90884
GCP004 2703264.139 258397.313 8-3680_crp.tif 2966.18648 1225.09720 8-3681_crp.tif 7700.90165 983.02651
GCP005 2706562.381 260018.737 8-3681_crp.tif 1550.15567 4010.84005 8-3682_crp.tif 6494.95953 4042.27064
GCP006 2704859.011 260172.112 8-3681_crp.tif 4758.28155 4270.00457 8-3682_crp.tif 9688.74865 4308.05213
#GCP007 2706631.207 258860.666 8-3681_crp.tif 1457.79385 1954.61774 8-3682_crp.tif 6307.89237 1991.25230
GCP008 2706133.701 263923.399 8-3681_crp.tif 2242.73149 11533.50374 8-3682_crp.tif 7384.25224 11569.58688 8-3683_crp.tif 12428.31059 11640.44357
GCP009 2708321.978 260344.646 8-3682_crp.tif 3289.03930 4737.32782 8-3683_crp.tif 7996.04593 4782.23359
GCP010 2708453.591 258494.149 8-3682_crp.tif 2975.56052 1301.74372 8-3683_crp.tif 7725.30172 1354.92070
GCP011 2712102.940 261919.839 8-3683_crp.tif 769.35363 7765.41708 8-3684_crp.tif 5747.93159 7845.06192 8-3685_crp.tif 10677.29586 7665.57670
GCP012 2710924.044 259764.674 8-3683_crp.tif 3208.53288 3762.70381 8-3684_crp.tif 7967.37241 3859.71819 8-3685_crp.tif 12473.52653 3591.17964
GCP013 2711584.609 258845.048 8-3684_crp.tif 6737.58163 2211.02519 8-3685_crp.tif 11145.44623 1984.08392
GCP014 2714074.430 259478.957 8-3684_crp.tif 2204.13252 3369.68358 8-3685_crp.tif 6662.03793 3351.72817 8-3686_crp.tif 11476.08777 3427.34079
GCP015 2716597.153 258735.092 8-3685_crp.tif 2003.96928 2230.18682 8-3686_crp.tif 6805.81909 2328.44188
GCP016 2714231.866 264216.196 8-3685_crp.tif 6791.89589 12329.05610 8-3686_crp.tif 11909.56800 12419.86707
GCP017 2717385.166 261450.863 8-3685_crp.tif 734.89027 7272.17737 8-3686_crp.tif 5580.02607 7351.40865 8-3687_crp.tif 10329.21585 7333.76341
#GCP018 2717931.194 260050.807 8-3686_crp.tif 4404.96312 4805.56529 8-3687_crp.tif 9156.08285 4773.68668
EOF

gcps_get_3D_mm $gcpnam.gcps $ref ${gcpnam}_3Dloc "${gcpproj}"
gcps_get_2D_mm $gcpnam.gcps ${gcpnam}_2D

###########################################
########## Tie Point Extraction ###########
###########################################

img="8-.*crp.tif"
chantier 153.15 $img 
#rm -rf Tmp-MM-Dir Pastis/*1-*cln.tif Homol/Pastis1-*cln.tif 
mm3d Tapioca Line ${img} 4000 2 ByP=32 @SFS
#mm3d Schnaps ${img} 
#mm3d HomolFilterMasq ${img} 
#
##############################
########### Part 1 ###########
##############################
#
project=hofsj95_s8
date=19950824
img="8-.*crp.tif"

chantier 153.15 $img 
mm3d Tapas RadialBasic ${img} Out=rel_${project}_${date} LibFoc=0 LibPP=0 LibAff=0 #SH=_mini #HomolMasqFiltered 
mm3d Tapas Fraser ${img} InCal=rel_${project}_${date} InOri=rel_${project}_${date} Out=fras_${project}_${date} LibFoc=0 #SH=_mini
GCPBascule ${img} fras_${project}_${date} bsc_${project}_${date} ${gcpnam}_3Dloc.xml ${gcpnam}_2D.xml
Campari ${img} bsc_${project}_${date} cmp_${project}_${date} GCP=[${gcpnam}_3Dloc.xml,1,${gcpnam}_2D.xml,1] NbIterEnd=20 NbLiais=1000 #SH=_mini #GradualRefineCal=Fraser
sgm $img cmp_${project}_${date} 2 5 'NbProc=32' # MasqIm=Masq'
ortho 0.5 feather
