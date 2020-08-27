#!/bin/bash

# ------------------------------------------------------------------
#  [belart] mm_xml.sh
#  A series of routines that create xml files needed for MicMac
#  The routines involve transformations between coordinate systems, and some raster and pointcloud operations
#  Dependencies:
#  -Ames StereoPipeline (https://ti.arc.nasa.gov/tech/asr/groups/intelligent-robotics/ngt/stereo/)
#  -General unix tools: sed, awk, grep, sort
#  -Rename
#  -GNU Parallel
# ------------------------------------------------------------------

chantier()
{
    #Receives N focals and N patterns of images associated
    #e.g. chantier_mulcam 153 "1-c151p17-1119[0-3](.*)_crp.tif|1-c151p17-1120[0-2](.*)_crp.tif" 151 "1-c151p17-11((19[8-9]|20[0-2]))_crp.tif" 152 "1-c151p17-1119[0-3](.*)_crp.tif"
    #DO NOT WRITE "[1-2]-.*crp.tif", instead write each strip separately.
    Ncams=$(echo "$#/2" | bc)
    echo "Creating Chantier with" $Ncams "cam..."
    
    for i in $(seq 1 $Ncams)
    do
        foc=$(echo $@ | awk -v n=$i '{print $((n*2)-1)}')
        pat=$(echo $@ | awk -v n=$i '{print $((n*2))}')
        echo "Camera" $i ": Focal:" $foc ", Img Pattern:" $pat
        #This makes the substitutions from MicMac readable for linux.
        patsh=$(echo $pat | awk -F "|" '{print $1}'| sed 's/\[\([^]]*\)\]/\{\1}/g' | tr -d "()" | sed 's/\.\*/\*/g' )
        #Cases when multiple photos or flightlines are specified in [] (which are now {})
        pattern=$patsh

        if [[ $patsh == *"{"* ]]; then
            par=$(echo $patsh | cut -d "{" -f2 | cut -d "}" -f1)
            if [ "${#par}" -gt "1" ]; then
                ini=$(echo $par | awk -F "-" '{print $1}')
                pattern=$(eval echo $(echo $patsh | sed "s/{.*}/$ini/g"))
            elif [ "${#par}" = "1" ]; then
                pattern=$(echo $patsh | tr -d "{}")
            fi
        fi

        echo "pattern for bash:" "$pattern"  
        s_sensor=$(gdalinfo $(echo $pattern | awk '{print $1}') | grep 'Size is' | sed 's/,//g' | awk -v k=$sres '{print k*$3,k*$4}')

        cat > "cameraentry_${i}.tmp" << EOF
        <CameraEntry>
              <Name> ${project}_${date}_cam_${i} </Name>
              <SzCaptMm> $s_sensor </SzCaptMm>
              <ShortName> ${project}_${date}_cam_${i} </ShortName>
        </CameraEntry>
EOF
        cat > "calcs_part1_${i}.tmp" << EOF
        <Calcs>
            <Arrite> 1 1 </Arrite>
            <Direct>
                <PatternTransform> $pat </PatternTransform>
                <CalcName> ${project}_${date}_cam_${i} </CalcName>
            </Direct>
        </Calcs>
EOF
        cat > "calcs_part2_${i}.tmp" << EOF
        <Calcs>
            <Arrite> 1 1 </Arrite>
            <Direct>
                <PatternTransform> $pat </PatternTransform>
                <CalcName> $foc </CalcName>
            </Direct>
        </Calcs>
EOF
    done

    cat > "chantier_template.tmp" << EOF
<Global>
        <ChantierDescripteur>
        <LocCamDataBase>
cameraentries
        </LocCamDataBase>
        <KeyedNamesAssociations>
calcspart1
        <Key> NKS-Assoc-STD-CAM </Key>
        </KeyedNamesAssociations>
        <KeyedNamesAssociations>
calcspart2
        <Key> NKS-Assoc-STD-FOC </Key>
        </KeyedNamesAssociations>
        </ChantierDescripteur>
</Global>
EOF

    awk '1;/cameraentries/{system("cat cameraentry_*.tmp")}' chantier_template.tmp | sed '/cameraentries/d'  > chantier_step1.tmp
    awk '1;/calcspart1/{system("cat calcs_part1_*.tmp")}' chantier_step1.tmp | sed '/calcspart1/d' > chantier_step2.tmp
    awk '1;/calcspart2/{system("cat calcs_part2_*.tmp")}' chantier_step2.tmp | sed '/calcspart2/d' > MicMac-LocalChantierDescripteur.xml
    rm cameraentry_*.tmp calcs_part*.tmp chantier_*.tmp  
}

chg_detect()
{
    #Not really useful since these param can be changed directly within tapioca
    #Example:
    #chg_detect Digeo Ann
    #options: Detect: Sift (default), Digeo. Match: Ann
    cat > "/home/jmcb/software/micmac/include/XML_User/MM-Environment.xml" << EOF
<MMUserEnvironment>
    <TiePDetect> mm3d:$1 </TiePDetect>
    <TiePMatch > mm3d:$2 </TiePMatch>
</MMUserEnvironment>
EOF
}

create_srsxml()
{
    cat > "SRSgeo.xml" << EOF
<SystemeCoord>
         <BSC>
            <TypeCoord>  eTC_Proj4 </TypeCoord>
            <AuxR>       1        </AuxR>
            <AuxR>       1        </AuxR>
            <AuxR>       1        </AuxR>
            <AuxStr>  ${proj}  </AuxStr>
         </BSC>
</SystemeCoord>
EOF

    cat > "SRSloc.xml" << EOF
<SystemeCoord>
         <BSC>
            <TypeCoord>  eTC_Proj4 </TypeCoord>
            <AuxR>       1        </AuxR>
            <AuxR>       1        </AuxR>
            <AuxR>       1        </AuxR>
            <AuxStr>  ${proj}  </AuxStr>
         </BSC>
</SystemeCoord>
EOF
}

fill_2d()
{
    echo "          <OneMesureAF1I>" >> $1
    echo "               <NamePt>$2</NamePt>" >> $1
    echo "               <PtIm>$3 $4</PtIm>" >> $1
    echo "          </OneMesureAF1I>" >> $1
}

gcps_get_2D_mm()
{
    sed '/^#/ d' ${1} > ${1}.tmp
    ############### 4 - Img Space ###############
    rm -f ${2}.xml
    #Convert into single lines
    tr ' ' '\n' < ${1}.tmp > ${1}_1c.tmp
    
    #Get unique imagenames with measurements
    frm=$(cat ${1} | awk 'NR==1{print $4}' | awk -F"." '{print $2}')
    grep "$frm" ${1}_1c.tmp | sort -u > ${1}_imnam.tmp 
    
    #Loop though unique images
    while read im
    do
        rm -f ${1}_2D_${im}.xml
        #Header
        echo "     <MesureAppuiFlottant1Im>" >> ${1}_2D_${im}.xml
        echo "          <NameIm>$im</NameIm>" >> ${1}_2D_${im}.xml
        
        grep "$im" ${1}.tmp > ${1}_2D_${im}.tmp
        while IFS= read -r line
        do
            gcp=$(echo $line | awk '{print $1}')
            x_px=$(echo $line | grep -o "${im}.*" | awk '{print $2}')
            y_px=$(echo $line | grep -o "${im}.*" | awk '{print $3}')
            fill_2d ${1}_2D_${im}.xml $gcp $x_px $y_px 
        done < ${1}_2D_${im}.tmp
        rm ${1}_2D_${im}.tmp
        #Tail
        echo "     </MesureAppuiFlottant1Im>" >> ${1}_2D_${im}.xml
    done < ${1}_imnam.tmp 
    
    #Header final file:
    echo "<?xml version="1.0" ?>" >> ${2}.xml
    echo "<SetOfMesureAppuisFlottants>" >> ${2}.xml
    
    for file in ${1}_2D_*.xml
    do
        cat $file >> ${2}.xml
    done
    
    echo "</SetOfMesureAppuisFlottants>" >> ${2}.xml
    
    rm ${1}.tmp ${1}_2D_*.xml ${1}_1c.tmp ${1}_imnam.tmp 
}

xml_mnt()
{
    cat > "Z_Num0_DeZoom0_STD-MALT.xml" << EOF
<FileOriMnt>
      <NameFileMnt>./mec/Z_Num7_DeZoom4_STD-MALT.tif</NameFileMnt>
      <NombrePixels>4831 4186</NombrePixels>
      <OriginePlani>-1733815 2269815</OriginePlani>
      <ResolutionPlani>5 -5</ResolutionPlani>
      <OrigineAlti>5695545</OrigineAlti>
      <ResolutionAlti>5</ResolutionAlti>
      <Geometrie>eGeomMNTEuclid</Geometrie>
</FileOriMnt>
EOF
}
