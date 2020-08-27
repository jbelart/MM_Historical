#!/bin/bash

source ~/shgen/mm_cameras.sh

create_cam_lmi_1995

create_px_4fid_template N18-N-3504.tif 1881.640 958.289 16010.555 925.509 16045.051 15055.113 1915.400 15087.297

mm3d Kugelhupf "N18.*.tif" Ori-InterneScan/MeasuresIm-N18-N-3504.tif.xml SearchIncertitude=10 
mm3d Kugelhupf "N18.*.tif" Ori-InterneScan/MeasuresIm-N18-N-3504.tif.xml SearchIncertitude=20 
mm3d Kugelhupf "N18.*.tif" Ori-InterneScan/MeasuresIm-N18-N-3504.tif.xml SearchIncertitude=50
mm3d Kugelhupf "N18.*.tif" Ori-InterneScan/MeasuresIm-N18-N-3504.tif.xml SearchIncertitude=100

for img in N18*.tif; do echo mm3d ReSampFid $img 0.015 >> crops.jobs; done
parallel -j 32 < crops.jobs
rm crops.jobs
rename 's/.tif/_crp.tif/' OIS*.tif
rename 's/OIS-Reech_//' *_crp.tif
