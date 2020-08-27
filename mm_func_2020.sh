#!/bin/bash

# ------------------------------------------------------------------
#  [belart] mm_func_2020.sh
#  This makes a MicMac project fit into a very small script, as long as this is "sourced"
#  Dependencies:
#  -Ames StereoPipeline (https://ti.arc.nasa.gov/tech/asr/groups/intelligent-robotics/ngt/stereo/)
#  -General unix tools: sed, awk, grep, sort
#  -GNU Parallel
#  -Rename
# ------------------------------------------------------------------

#Some general variables are assumed to be defined: "proj", "project" or "date".

source ~/shgen/mm_xml.sh
source ~/shgen/mm_tr3D.sh

geoXYZ="+proj=geocent +ellps=WGS84 +datum=WGS84 +no_defs"
latlon="+proj=latlong +ellps=WGS84 +datum=WGS84 +no_defs"

#proj='+proj=utm +zone=18 +south +datum=WGS84 +units=m +no_defs'
#proj='+proj=lcc +lat_1=64.25 +lat_2=65.75 +lat_0=65 +lon_0=-19 +x_0=500000 +y_0=500000 +ellps=WGS84 +datum=WGS84 +units=m +no_defs'
#proj='+proj=lcc +lat_1=64.25 +lat_2=65.75 +lat_0=65 +lon_0=-19 +x_0=2700000 +y_0=300000 +ellps=GRS80 +units=m +no_defs'

get_georef()
{
    gdalinfo $1 | egrep -e 'Lower Left|Upper Right' | sed -e 's/[,()]//g' | awk '{print $3,$4}' | tr '\n' ' '
}

gcpsXYZ_get_3D_mm()
{
    #Takes a GCP file, which first four columns are ID, X,Y Z (followed by 2d img meas) and returns the 3D.xml GCP file needed in MicMac
    sed '/^#/ d' ${1} > ${1}.tmp
    cat ${1}.tmp

    if test -z "$3"
    then
        echo "GCPs are in default projection"
        awk '{print $2,$3,$4}' ${1}.tmp | cs2cs -f "%.4f" ${proj} +to ${geoXYZ} | tr3d_geo2local > ${1}_XYZloc.csv
    else
        echo "GCPs are in custom projection"
        awk '{print $2,$3,$4}' ${1}.tmp | cs2cs -f "%.4f" ${3} +to ${geoXYZ} | tr3d_geo2local > ${1}_XYZloc.csv
    fi

    #awk '{print $2,$3,$4}' ${1}.tmp | cs2cs -f "%.4f" ${proj} +to ${geoXYZ} | tr3d_geo2local > ${1}_XYZloc.csv
    awk '{print $1}' ${1}.tmp > ${1}_id.csv
    paste ${1}_id.csv ${1}_XYZloc.csv > $2
    
    wc -l $2
    cat $2

    mm3d GCPConvert "#F=N_X_Y_Z" $2
    rm ${1}.tmp ${1}_XYZloc.csv ${1}_id.csv #$2 #Can delete $3 since previous line creates another file .xml
}

gcps_get_3D_mm()
{
    #Takes a GCP file, which first three columns are ID, X,Y (followed by 2d img meas), and a reference DEM to extract Z, and returns the 3D.xml GCP file needed in MicMac. Works also with .vrt
    sed '/^#/ d' ${1} > ${1}.tmp
    rm ${1}_XYZ.csv
    awk '{print $2,$3,0}' ${1}.tmp > ${1}_XY0.csv

    if test -z "$4"
    then
        echo "GCPs are in default projection"
        geodiff $2 ${1}_XY0.csv --csv-format '1:easting 2:northing 3:height_above_datum' --csv-proj4 "${proj}" -o $1
    else
        echo "GCPs are in custom projection"
        geodiff $2 ${1}_XY0.csv --csv-format '1:easting 2:northing 3:height_above_datum' --csv-proj4 "${4}" -o $1
    fi
    
    rename 's/-diff/_XYZ/' $1-diff.csv
    #sed -i '/^#/ d' ${1}_XYZ.csv
    sed -i '/#/d' ${1}_XYZ.csv
    
    #Special characters, like "ZeroZ" become zero now
    lines=$(grep -n "ZeroZ" ${1}.tmp | awk -F ":" '{print $1}')
    if [[ ! -z "$lines" ]]
    then
        for i in $lines
        do
                echo "Modifying special GCP, line:" $i
                fxline=$(awk -v l=$i 'BEGIN{FS=OFS=","} ( NR == l) {print $1,$2,0}' ${1}_XYZ.csv)
                sed -i "${i}s/.*/$fxline/" ${1}_XYZ.csv
        done
    fi
    
    awk -F "," '{ print $1,$2,$3 }' ${1}_XYZ.csv | cs2cs -f "%.4f" ${latlon} +to ${geoXYZ} | tr3d_geo2local > ${1}_XYZloc.csv
    awk '{print $1}' ${1}.tmp > ${1}_id.csv
    paste ${1}_id.csv ${1}_XYZloc.csv > $3

    wc -l $3
    cat $3
    
    mm3d GCPConvert "#F=N_X_Y_Z" $3
    rm ${1}.tmp ${1}_XY0.csv ${1}_XYZ.csv ${1}_XYZloc.csv ${1}_id.csv #$3 #Can delete $3 since previous line creates another file .xml
}

poe_mm()
{
    NAM=$(basename $1 .ori)
    awk '{ print $1 }' $1 > $1-id.tmp
    awk '{ print $5, $6, $7 }' $1 > $1-opk.tmp
    awk '{ print $2, $3, $4 }' $1 | cs2cs -f "%.4f" ${proj} +to ${geoXYZ} | tr3d_geo2local > $1-local-noid.tmp
    paste $1-id.tmp $1-local-noid.tmp $1-opk.tmp > ${NAM}_loc.ori
    sed -i 1i"#F=N X Y Z W P K\n#\n#image       latitude        longitude       altitude        yaw     pitch   roll    " ${NAM}_loc.ori
    rm $1-*.tmp
}

check_abs_ori()
{
    tail -n +13 $2 | parallel_local2prj > Campari_${project}_${date}_prj.csv
    less Campari_${project}_${date}_prj.csv
    geodiff $1 Campari_${project}_${date}_prj.csv --csv-format '1:easting 2:northing 3:height_above_datum' --csv-proj4 "${proj}" -o $3
    point2dem $3-diff.csv -s 50 --search-radius-factor 2 --csv-format '1:lon 2:lat 3:height_above_datum' --csv-proj4 "${proj}" --threads 16 
    rm Campari_${project}_${date}_prj.csv
}

intp_flightline()
{
    #given a csv file (from OriExport, after cleaning obviously wrong orientations), it fills the missing photographs, assuming they are sequential and simple interpolation
    awk '{print $1}' $1 | sed 's/_crp.tif//g' | awk -F"-" '{print $2}' 
    X1=$(grep $2 $1 | awk '{print $5}')
    Y1=$(grep $2 $1 | awk '{print $6}')
    Z1=$(grep $2 $1 | awk '{print $7}')

    X2=$(grep $3 $1 | awk '{print $5}')
    Y2=$(grep $3 $1 | awk '{print $6}')
    Z2=$(grep $3 $1 | awk '{print $7}')

    echo "X1:"$X1
    echo "X2:"$X2

    python3 << EOF
import pandas as pd
import numpy as np
print(pd.Series([$X1, $X2], index=[$2, $3]).interpolate(method='index'))
EOF

    #awk '$1 < prev { print saved "\n" $0 "\n" } { prev = $1; saved = $0 }' $1

    ##This takes two orientation files, and calculates all the orientations of images in between, by simple interpolation
    #XYZori=$(grep "<Centre>" $1 | sed 's/\///' | awk -F "<Centre>" '{print $2}')
    #XYZend=$(grep "<Centre>" $2 | sed 's/\///' | awk -F "<Centre>" '{print $2}')
    #dir=$(dirname "$1")
    #Nori=$(basename "$1" | grep -o '[0-9]\+' | tail -1)
    #Nend=$(basename "$2" | grep -o '[0-9]\+' | tail -1)
    #N_ph=$(expr $Nend - $Nori + 1)
    #base=$(echo $XYZori $XYZend | awk -v N=$N_ph '{print ($4-$1)/N,($5-$2)/N,($6-$3)/N}')
    #for i in $(seq 1 $N_ph)
    #do
    #   Nextph=$(basename "$1" | sed "s/$Nori/$(expr $Nori + $i)/g")
    #   echo "Creating interpolated file:" $Nextph
    #   cp $1 $dir/$Nextph
    #   NextXYZ=$(echo $base $XYZori | awk -v N=$i '{printf "%.3f %.3f %.3f", ($1*N)+$4,($2*N)+$5,($3*N)+$6}')
    #   sed -i -e "s/$XYZori/$NextXYZ/g" $dir/$Nextph
    #done
}

sgm()
{
    echo -e "\n---------------------\n- SGM, DEM AND DDEM -\n---------------------"
    #$5 -> Any other parameter to pass to Malt
    #mm3d Malt Ortho $1 $2 DirMEC=mec DoOrtho=1 DefCor=0 NbVI=2 AffineLast=1 SzW=5 Regul=0.05 ZPas=0.1 ZInc=1 ZoomF=$(awk -v N=$3 'BEGIN{print 2**N}') $5
    mm3d Malt Ortho $1 $2 DirMEC=mec_${project}_${date} DoOrtho=1 DefCor=0 NbVI=2 AffineLast=1 SzW=7 Regul=0.005 ZoomF=$(awk -v N=$3 'BEGIN{print 2**N}') $5
    mm3d Nuage2Ply "mec_${project}_${date}/NuageImProf_STD-MALT_Etape_$((9-$3)).xml" Bin=0 Out=${project}_${date}.ply
    tail -n +10 ${project}_${date}.ply | parallel_local2prj > ${project}_${date}.csv
    point2dem ${project}_${date}.csv -s $4 --search-radius-factor 2 --csv-format '1:easting 2:northing 3:height_above_datum' --csv-proj4 "${proj}" --threads 8
    geodiff $ref ${project}_${date}-DEM.tif -o Ref_minus_${project}_${date}
    rm ${project}_${date}-log-point2dem*.txt
}

copy_msk()
{
    echo -e "\n---------------------\n- Copying mask to a pattern of images (e.g. to mask fiducials) -\n---------------------"
    #$1 -> Reference mask. It should finish in _Masq.tif (an XML file should also be coupled to this file)
    #$2 -> Pattern of images (wildcard)
    namref=$(basename $1 _Masq.tif)
    for img in $@
    do
        namslv=$(basename $img .tif)
        echo "Creating mask for image "$namslv
        cp -n $1 ${namslv}_Masq.tif
        cp -n ${namref}_Masq.xml ${namslv}_Masq.xml
        sed -i "s/$1/${namslv}_Masq.tif/g" ${namslv}_Masq.xml
    done
}

ortho()
{
    echo -e "\n---------\n- ORTHO -\n---------"
    px=$1
    if [ "$2" = "tawny" ]; then
        echo "Mosaic with Tawny"
        mm3d Tawny Ortho-mec_${project}_${date} Out=Ortloc_${project}_${date}.tif DEq=2 DegRap=4
        gdalbuildvrt Ortho-mec_${project}_${date}/Ortloc_${project}_${date}.vrt Ortho-mec_${project}_${date}/Ortloc_${project}_${date}*.tif
    elif [ "$2" = "feather" ]; then
        echo "Mosaic with feathering"
        mm3d TestLib SeamlineFeathering Ortho-mec_${project}_${date}/Ort_.*tif
        gdalbuildvrt Ortho-mec_${project}_${date}/Ortloc_${project}_${date}.vrt Ortho-mec_${project}_${date}/MosaicFeathering*.tif
    elif [ "$2" = "gdal" ]; then
        echo "Mosaic with GDAL"
        gdalbuildvrt -srcnodata 0 Ortho-mec_${project}_${date}/Ortloc_${project}_${date}.vrt Ortho-mec_${project}_${date}/Ort_*.tif
    else
        echo "Error: Introduce -tawny-, -feather- or -gdal-"
        exit
    fi
    
    #ortholoc2isn Ortho-mec/Ortloc_${project}_${date}.tif $px
    #To do: simplify and speedup the reprojection using RCPs, see https://www.orfeo-toolbox.org/Applications/GenerateRPCSensorModel.html
    
    gdal_translate -scale -ot Byte -of GTiff Ortho-mec_${project}_${date}/Ortloc_${project}_${date}.vrt Ortho-mec_${project}_${date}/Ortloc_${project}_${date}_sc.tif
    gdalwarp -overwrite -r cubic -tr $1 $1 Ortho-mec_${project}_${date}/Ortloc_${project}_${date}_sc.tif Ortho-mec_${project}_${date}/Ortloc_${project}_${date}_pxfix.tif
    tail -n +10 ${project}_${date}.ply | awk 'NR%10==0{ print $1,$2 }' > loc_tmp_${project}_${date}.csv
    awk 'NR%10==0' ${project}_${date}.csv > prj_tmp_${project}_${date}.csv
    paste loc_tmp_${project}_${date}.csv prj_tmp_${project}_${date}.csv | shuf -n2000 | awk -v px=$1 -v X_min=$(get_georef Ortho-mec_${project}_${date}/Ortloc_${project}_${date}_pxfix.tif | awk '{print $1}') -v Y_max=$(get_georef Ortho-mec_${project}_${date}/Ortloc_${project}_${date}_pxfix.tif | awk '{print $4}') '{ printf "%.3f %.3f %.3f %.3f %.3f\n", (($1 - X_min)/px), ((Y_max - $2)/px),$3,$4,$5 }' | sed 's/^/-gcp /' | paste -s > gcps_ort_loc2prj_${project}_${date}.csv
    gdal_translate -of GTiff -a_srs "${proj}" -ot Byte $(cat gcps_ort_loc2prj_${project}_${date}.csv) Ortho-mec_${project}_${date}/Ortloc_${project}_${date}_pxfix.tif Ortho-mec_${project}_${date}/Ortloc_${project}_${date}_w_gcps.tif
    gdalwarp -overwrite -tr $1 $1 -r bilinear -srcnodata 0 -of GTiff -ot Byte -co "INTERLEAVE=BAND" -co "TILED=YES" -co "COMPRESS=LZW" -tps -tap Ortho-mec_${project}_${date}/Ortloc_${project}_${date}_w_gcps.tif Orthomosaic_${project}_${date}_${1}x${1}m.tif
    gdal_translate -of JP2OpenJPEG Orthomosaic_${project}_${date}_${1}x${1}m.tif Orthomosaic_${project}_${date}_${1}x${1}m.jp2
    rm loc_tmp_${project}_${date}.csv prj_tmp_${project}_${date}.csv gcps_ort_loc2prj_${project}_${date}.csv
}

ortho_predem()
{
    #Work in progress
    mm3d Malt Ortho IMG_.*.tif Ori-RPC-d3-adj DoMEC=0 DoOrtho=1 ImMNT=DSM.tif ImOrtho=IMG_.*.tif
}

raster_loc2prj()
{
    echo -e "\n---------\n- ORTHO -\n---------"
    #In construction. simplify and speedup the reprojection using RCPs, see https://www.orfeo-toolbox.org/Applications/GenerateRPCSensorModel.html
    #Idea: take georef and amount of rows and columns
    #Then divide in four parts the X and Y coordinates
    #This creates a 25x25 grid, with px and georef values. Use this to assign RCPs to each image
    
    ortholoc=$1
    NAM=$(basename "$1" | sed 's/.\{4\}$//')
    
    size=$(gdalinfo $ortholoc | grep "Size is" | awk '{print $3,$4}')
    row=$(echo $size | awk -F ", " '{print $1}')
    col=$(echo $size | awk -F ", " '{print $2}')
    echo "Rows:"$row" Cols:"$col
    LL=$(get_georef $ortholoc | awk '{print $1,$2}')
    UR=$(get_georef $ortholoc | awk '{print $3,$4}')
    echo "LL:"$LL" UR:"$UR
    
    stepR=$( echo "scale=2; $row/10.0" | bc)
    stepC=$( echo "scale=2; $col/10.0" | bc)
    
    LLX=$(echo $LL | awk '{print $1}')
    URX=$(echo $UR | awk '{print $1}')
    
    LLY=$(echo $LL | awk '{print $2}')
    URY=$(echo $UR | awk '{print $2}')
    
    stepX=$( echo "scale=3; ($URX - $LLX)/10.0" | bc)
    stepY=$( echo "scale=3; -($URY - $LLY)/10.0" | bc)
    
    avg_z=$(awk NR>10 '{print $3}' PC_${project}_${date}_ascii.ply | shuf -n100000 | awk '{ total += $1; count++ } END { print total/count }')
    
    rm ${NAM}_XY0loc.csv ${NAM}_XYpx.csv
    for i in $(seq $URY $stepY $LLY)
    do
        for j in $(seq $LLX $stepX $URX)
        do
                echo $j " " $i " " $avg_z >> ${NAM}_XYZloc.csv
        done
    done
    
    for i in $(seq 0 $stepC $col)
    do
        for j in $(seq 0 $stepR $row)
        do
                echo $j " " $i >> ${NAM}_XYpx.csv
        done
    done
    
    cat ${NAM}_XYZloc.csv | parallel_local2prj > ${NAM}_XYZ.csv
    
    paste ${NAM}_XYpx.csv ${NAM}_XYZ.csv | awk '{print "-gcp "$1,$2,$3,$4}' > ${NAM}_gcps.csv
    
    gdal_translate -of VRT -a_srs EPSG:3057 -ot Byte $(cat ${NAM}_gcps.csv) $ortholoc Ortho-mec/${NAM}.vrt
    gdalwarp -overwrite -tr $2 $2 -r bilinear -of GTiff -ot Byte -tps -tap Ortho-mec/${NAM}.vrt Ortho-mec/${NAM}_prj.tif
}

ortho_debug()
{
    echo -e "\n---------\n- ORTHO -\n---------"
    #In construction. simplify and speedup the reprojection using RCPs, see https://www.orfeo-toolbox.org/Applications/GenerateRPCSensorModel.html
    #Idea: take georef and amount of rows and columns
    #Then divide in four parts the X and Y coordinates
    #This creates a 25x25 grid, with px and georef values. Use this to assign RCPs to each image
    
    tstimg=Ortho-mec/Ort_2-1677_crp.tif
    
    size=$(gdalinfo $tstimg | grep "Size is" | awk '{print $3,$4}')
    row=$(echo $size | awk -F ", " '{print $1}')
    col=$(echo $size | awk -F ", " '{print $2}')
    echo "Rows:"$row" Cols:"$col
    LL=$(get_georef $tstimg | awk '{print $1,$2}')
    UR=$(get_georef $tstimg | awk '{print $3,$4}')
    echo "LL:"$LL" UR:"$UR
    
    stepR=$( echo "scale=2; $row/10.0" | bc)
    stepC=$( echo "scale=2; $col/10.0" | bc)
    
    LLX=$(echo $LL | awk '{print $1}')
    URX=$(echo $UR | awk '{print $1}')
    
    LLY=$(echo $LL | awk '{print $2}')
    URY=$(echo $UR | awk '{print $2}')
    
    stepX=$( echo "scale=3; ($URX - $LLX)/10.0" | bc)
    stepY=$( echo "scale=3; -($URY - $LLY)/10.0" | bc)
    
    rm XYZloc.tmp XYpx.tmp
    for i in $(seq $URY $stepY $LLY)
    do
        for j in $(seq $LLX $stepX $URX)
        do
                echo $j " " $i "6361000" >> XYZloc.tmp
        done
    done
    
    for i in $(seq 0 $stepC $col)
    do
        for j in $(seq 0 $stepR $row)
        do
                echo $j " " $i >> XYpx.tmp
        done
    done
    
    cat XYZloc.tmp | parallel_local2prj > XYZ.tmp
    
    paste XYpx.tmp XYZ.tmp | awk '{print "-gcp "$1,$2,$3,$4}' > gcps.tmp
    
    gdal_translate -of VRT -a_srs EPSG:3057 -ot Byte $(cat gcps.tmp) $tstimg Ortho-mec/Ort_2-1677_crp.vrt
    gdalwarp -overwrite -tr 1 1 -r bilinear -of GTiff -ot Byte -tps -tap Ortho-mec/Ort_2-1677_crp.vrt Ortho-mec/Ort_2-1677_crp_prj.tif
    
    #TO DO: DO THIS THROUGH RPCS:
    #otbcli_GenerateRPCSensorModel -outgeom Ortho-mec/Ort_2-1677_crp.rpb -inpoints gcps.tmp -outstat stats.txt
    #gdalwarp -overwrite -r bilinear -rpc -t_srs "${proj}" $tstimg Ortho-mec/Ort_2-1677_crp_prj.tif
}
