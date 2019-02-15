#!/bin/bash

lcc='+proj=lcc +lat_1=64.25 +lat_2=65.75 +lat_0=65 +lon_0=-19 +x_0=500000 +y_0=500000 +ellps=WGS84 +datum=WGS84 +units=m +no_defs'
geoXYZ="+proj=geocent +ellps=WGS84 +datum=WGS84 +no_defs"

tr_3d_fw_geo2local()
{
awk '{ printf "%.3f %.3f %.3f\n", 0.325568154457157*$1 + 0.945518575599317*$2 + 0*$3, -0.842463219600284*$1 + 0.290083349689293*$2 + 0.453990499739547*$3, 0.429256450649358*$1 + -0.147804849141287*$2 + 0.891006524188368*$3 }'
}

tr_3d_inv_local2geo()
{
awk '{ printf "%.3f %.3f %.3f\n", 0.325568154457157*$1+-0.842463219600284*$2+0.429256450649358*$3,0.945518575599317*$1+0.290083349689293*$2+-0.147804849141287*$3,0*$1+0.453990499739547*$2+0.891006524188368*$3 }'
}

get_georef()
{
gdalinfo -nomd -norat $1 | egrep -e 'Lower Left|Upper Right' | sed -e 's/[,()]//g' | awk '{print $3,$4}' | tr '\n' ' '
}

chantier()
{
szx=$(gdalinfo $(echo "$(set -- $( echo "$img" | tail -c +2 ); echo "$1")") | egrep -e 'Size is' | awk -v sres=$sres '{print $3*sres}')
szy=$(gdalinfo $(echo "$(set -- $( echo "$img" | tail -c +2 ); echo "$1")") | egrep -e 'Size is' | awk -v sres=$sres '{print $4*sres}')
cat > "MicMac-LocalChantierDescripteur.xml" << EOF
<Global>
	<ChantierDescripteur>
    <LocCamDataBase>
        <CameraEntry>
              <Name> ${area}_${yr} </Name>
              <SzCaptMm> $szx $szy </SzCaptMm>
              <ShortName> ${area}_${yr} </ShortName>
         </CameraEntry>
    </LocCamDataBase>
    <KeyedNamesAssociations>
            <Calcs>
                 <Arrite> 1 1 </Arrite>
                 <Direct>
                       <PatternTransform> .* </PatternTransform>
                       <CalcName> ${area}_${yr} </CalcName>
                 </Direct>
             </Calcs>
             <Key> NKS-Assoc-STD-CAM </Key>
    </KeyedNamesAssociations>
    <KeyedNamesAssociations>
            <Calcs>
                 <Arrite> 1 1 </Arrite>
                 <Direct>
                       <PatternTransform> .* </PatternTransform>
                       <CalcName> $foc </CalcName>
                 </Direct>
             </Calcs>
             <Key> NKS-Assoc-STD-FOC </Key>
    </KeyedNamesAssociations>
	</ChantierDescripteur>
</Global>
EOF
}

gcp_ascii_2_mm()
{
awk '{ print $1 }' $1.txt > gcps_id.txt
awk '{ print $2, $3, $4 }' $1.txt | cs2cs -f "%.4f" ${lcc} +to ${geoXYZ} | tr_3d_fw_geo2local > gcps_local_noid.txt
paste gcps_id.txt gcps_local_noid.txt > ${area}_${yr}_GCPs_local.txt
mm3d GCPConvert "#F=N_X_Y_Z" ${area}_${yr}_GCPs_local.txt
`bash -c "join -i <(sort $2.txt) <(sort $3.txt) > tmp0.var"`
awk '{ print $3, $4, $2, $5 }' tmp0.var > tmp1.var
mm3d GCPConvert "#F=X_Y_Z_N" tmp1.var
sed -i 's/DicoAppuisFlottant/SetOfMesureAppuisFlottants/g; /OneAppuisDAF/d; s/NamePt/NameIm/g; s/Pt/PtIm/g; /Incertitude/d; s/<NamePt>.*</<NamePt></g' tmp1.xml
printf %s\\n 'g/NameIm/m-2' x | ex tmp1.xml
awk '!x[$1]++' FS="tif" tmp1.xml | awk '!/PtIm/ { print; next;} { print $0"Coord"; print $0"</NamePt>" }' > tmp2.xml
awk '{if (/Coord/) {print $1, $2, $4} else {print}}' tmp2.xml | sed '/<PtIm>/ s/$/<\/\PtIm>/' | awk '{if (/NamePt/) {print $3} else {print}}' | awk '{if (/NamePt/) {gsub("</PtIm>", "");print} else {print}}' | awk '{if (/NamePt/) {print "<NamePt>" $0} else {print}}' > tmp3.xml
printf %s\\n 'g/NamePt/m-2' x | ex tmp3.xml
awk '/NamePt/{print "<OneMesureAF1I>"}1' tmp3.xml | awk '/PtIm/{print;print "</OneMesureAF1I>";next}1' | awk '/NameIm/{print "<MesureAppuiFlottant1Im>"}1' | awk '/MesureAppuiFlottant1Im/{print "</MesureAppuiFlottant1Im>"}1' | awk '/SetOfMesureAppuisFlottants/{print "</MesureAppuiFlottant1Im>"}1' > ${area}_${yr}_MM_img.xml
sed -i '2d;4d' ${area}_${yr}_MM_img.xml
rm gcps_id.txt gcps_local_noid.txt ${area}_${yr}_GCPs_local.txt *tmp*.xml *.var
}

poe_isn93_2_local()
{
awk '{ print $1 }' $1.txt > $1-id.txt | awk '{ print $5, $6, $7 }' $1.txt > $1-opk.txt
awk '{ print $2, $3, $4 }' $1.txt | cs2cs -f "%.4f" ${lcc} +to ${geoXYZ} | tr_3d_fw_geo2local > $1-local-noid.txt
paste $1-id.txt $1-local-noid.txt $1-opk.txt > $1-local.csv
sed -i 1i"#F=N X Y Z W P K\n#\n#image	latitude	longitude	altitude	yaw	pitch	roll	" $1-local.csv
rm $1-id.txt $1-opk.txt $1-local-noid.txt
}

check_abs_ori()
{
tail -n +13 $1 | tr_3d_inv_local2geo | cs2cs -f "%.4f" ${geoXYZ} +to ${lcc} > Campari_${area}_${yr}_isn93.csv
point2dem Campari_${area}_${yr}_isn93.csv -s 100 --search-radius-factor 4 --csv-format '1:easting 2:northing 3:height_above_datum' --csv-proj4 "${lcc}"
geodiff Campari_${area}_${yr}_isn93-DEM.tif $ref -o Campari_${area}_${yr}_${2}_minus_Ref
}

sgm()
{
echo "\n---------------------\n- SGM, DEM AND DDEM -\n---------------------"
mkdir DEM_${area}_${yr}
mm3d Malt Ortho ${img} Campari_${area}_${yr} DirMEC=MEC DoOrtho=1 DefCor=0 NbVI=2 AffineLast=1 SzW=7 Regul=0.005 ZoomF=$(awk -v N=$1 'BEGIN{print 2**N}') NbProc=16
mm3d Nuage2Ply "MEC/NuageImProf_STD-MALT_Etape_$((9-$1)).xml" Scale=1 Bin=0 Out=PC_${area}_${yr}_ascii.ply
tail -n +10 PC_${area}_${yr}_ascii.ply | tr_3d_inv_local2geo | cs2cs -f "%.4f" ${geoXYZ} +to ${lcc} > DEM_${area}_${yr}/PC_${area}_${yr}_isn93.csv
point2dem DEM_${area}_${yr}/PC_${area}_${yr}_isn93.csv -s $2 --search-radius-factor 2 --csv-format '1:easting 2:northing 3:height_above_datum' --csv-proj4 "${lcc}" --threads 32 --tif-compress None 
geodiff $ref DEM_${area}_${yr}/PC_${area}_${yr}_isn93-DEM.tif -o DEM_${area}_${yr}/Ref_minus_${area}_${yr} --tif-compress None
}

ortho()
{
echo "\n---------\n- ORTHO -\n---------"
if [ "$2" = "tawny" ]; then
	echo "Mosaic with Tawny"
	mm3d Tawny Ortho-MEC Out=Ortloc_${area}_${yr}.tif DEq=2 DegRap=4
elif [ "$2" = "gdal" ]; then
	echo "Mosaic with GDAL"
	gdal_merge.py -n 0 -o Ortho-MEC/Ortloc_${area}_${yr}.tif Ortho-MEC/Ort_*.tif
else	
	echo "Error: Introduce -tawny- or -gdal-"
	exit
fi
gdalwarp -overwrite -r bilinear -tr $1 $1 -of GTiff -ot Byte Ortho-MEC/Ortloc_${area}_${yr}.tif Ortho-MEC/Ortloc_${area}_${yr}_pxfix.tif
tail -n +10 PC_${area}_${yr}_ascii.ply | awk 'NR%10==0{ print $1,$2 }' > loc_tmp.csv
awk 'NR%10==0' DEM_${area}_${yr}/PC_${area}_${yr}_isn93.csv > isn93_tmp.csv
paste loc_tmp.csv isn93_tmp.csv | shuf -n5000 | awk -v px=$1 -v X_min=$(get_georef Ortho-MEC/Ortloc_${area}_${yr}_pxfix.tif | awk '{print $1}') -v Y_max=$(get_georef Ortho-MEC/Ortloc_${area}_${yr}_pxfix.tif | awk '{print $4}') '{ printf "%.3f %.3f %.3f %.3f %.3f\n", (($1 - X_min)/px), ((Y_max - $2)/px),$3,$4,$5 }' | sed 's/^/-gcp /' | paste -s > gcps_ort_loc2isn93.csv
gdal_translate -of GTiff -a_srs EPSG:3057 -ot Byte $(cat gcps_ort_loc2isn93.csv) Ortho-MEC/Ortloc_${area}_${yr}_pxfix.tif Ortho-MEC/Ortloc_${area}_${yr}_w_gcps.tif
gdalwarp -overwrite -tr $1 $1 -r bilinear -of GTiff -ot Byte -co "INTERLEAVE=BAND" -co "TILED=YES" -co "COMPRESS=LZW" -tps -tap Ortho-MEC/Ortloc_${area}_${yr}_w_gcps.tif Ortho-MEC/Orthomosaic_${area}_${yr}_${1}x${1}m_isn93.tif
rm loc_tmp.csv isn93_tmp.csv 
}
