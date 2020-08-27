#!/bin/bash

source ~/shgen/mm_cameras.sh

create_cam_amsdma_4fid_template $(cal_fid_from_px 0.016 14664.81267 7306.16558 7682.36802 14335.69364 654.85422 7365.83814 7626.22043 329.63783)

create_px_4fid_template 4-6388.tif 14682.31159 7391.01643 7654.73484 14377.42667 669.92973 7360.89690 7689.52810 371.60690
create_px_4fid_template 4-6389.tif 14673.81391 7373.26574 7670.03066 14381.39225 662.94275 7390.54434 7658.65322 377.98016
create_px_4fid_template 4-6390.tif 14663.23903 7357.21457 7687.21484 14394.98853 653.02880 7430.86109 7620.55531 390.01853
create_px_4fid_template 4-6391.tif 14657.19624 7344.18481 7696.65671 14395.93271 646.98601 7448.13969 7600.44415 391.57643
create_px_4fid_template 4-6392.tif 14657.00740 7332.66574 7698.16740 14386.86853 645.75857 7442.09690 7596.05368 383.07876
create_px_4fid_template 4-6393.tif 14663.42787 7336.44248 7687.97019 14374.40527 651.14043 7414.62109 7617.01461 370.75713
create_px_4fid_template 4-6394.tif 14670.03717 7341.35225 7675.12926 14360.43132 659.44926 7380.53597 7644.06554 355.60295
create_px_4fid_template 4-6395.tif 14676.07996 7339.84155 7667.57578 14345.13550 664.73671 7352.21039 7663.75182 341.44016
create_px_4fid_template 4-6396.tif 14682.68926 7358.53643 7660.02229 14350.61178 671.53484 7342.20202 7683.15484 345.26411
create_px_4fid_template 4-6397.tif 14685.89950 7380.44155 7656.62322 14364.20806 675.50043 7347.48946 7696.89275 358.57713
create_px_4fid_template 4-6398.tif 14683.44461 7388.56155 7659.83345 14378.93736 671.53484 7369.30016 7685.27926 373.44806
create_px_4fid_template 4-6399.tif 14677.02415 7398.19225 7669.46415 14404.05271 665.11438 7410.74992 7664.31833 399.36597
create_px_4fid_template 4-6400.tif 14665.88275 7386.67318 7681.92740 14416.13829 653.97298 7445.59039 7630.32764 411.12109
create_px_4fid_template 4-6401.tif 14658.70694 7364.95690 7694.57950 14412.92806 648.59112 7461.07504 7605.25950 409.70481
create_px_4fid_template 4-6402.tif 14654.55252 7333.04341 7701.94415 14392.53364 644.34229 7453.42713 7587.98089 389.59364
create_px_4fid_template 4-6403.tif 14656.06322 7315.10388 7697.22322 14368.55132 646.32508 7421.41922 7597.75322 365.23364
create_px_4fid_template 4-6404.tif 14664.81267 7306.16558 7682.36802 14335.69364 654.85422 7365.83814 7626.22043 329.63783

for img in 4-6{388..404}.tif; do echo mm3d ReSampFid $img 0.016 >> crops.jobs; done
parallel -j 32 < crops.jobs
rm crops.jobs
rename 's/.tif/_crp.tif/' OIS*.tif
rename 's/OIS-Reech_//' *_crp.tif