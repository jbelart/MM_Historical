#!/bin/bash

sort_ulurlrll()
{
#Sort pairs of coordinates into ULX ULY URX URY LRX LRY LLX LLY
echo -e $1 $2'\n'$3 $4'\n'$5 $6'\n'$7 $8 > XY.tmp
cat > sort_coor.py << EOF
# -*- coding: utf-8 -*-
import numpy as np
def order_points(pts):
        rect = np.zeros((4, 2), dtype = "float32")
        s = pts.sum(axis = 1)
        rect[0] = pts[np.argmin(s)]
        rect[2] = pts[np.argmax(s)]
        diff = np.diff(pts, axis = 1)
        rect[1] = pts[np.argmin(diff)]
        rect[3] = pts[np.argmax(diff)]
        return rect
print(order_points(np.genfromtxt('XY.tmp')))
EOF
python3 sort_coor.py | sed 's/[][]//g' | tr -d '\n'
rm sort_coor.py XY.tmp
}

cal_fid_from_px()
{
#Needed for pseudofid, AMS & DMA
#Example: cal_fid_from_px 0.02 706.390 5879.051 6653.75 25.909 12502.368 5826.726 6700.964 11681.486

#Expected input is:
#Fid1: Left, by the clocks
#Fid2-4: Clockwise
cat > fid_from_px.py << EOF
# -*- coding: utf-8 -*-
import numpy as np

def findIntersection(x1,y1,x2,y2,x3,y3,x4,y4):
        px= ( (x1*y2-y1*x2)*(x3-x4)-(x1-x2)*(x3*y4-y3*x4) ) / ( (x1-x2)*(y3-y4)-(y1-y2)*(x3-x4) ) 
        py= ( (x1*y2-y1*x2)*(y3-y4)-(y1-y2)*(x3*y4-y3*x4) ) / ( (x1-x2)*(y3-y4)-(y1-y2)*(x3-x4) )
        return [px, py]

fid_mm = $1 * np.array([$2,-$3,$4,-$5,$6,-$7,$8,-$9])
fc = findIntersection(fid_mm[0],fid_mm[1],fid_mm[4],fid_mm[5],fid_mm[2],fid_mm[3],fid_mm[6],fid_mm[7])
dist =  np.sqrt((fid_mm[2]-fc[0])**2+(fid_mm[3]-fc[1])**2)

t=np.matrix([[0],[0],[0],[dist]])
A=np.matrix([[fc[0],-fc[1],1,0],
                         [fid_mm[2],-fid_mm[3],1,0],
                         [fc[1],fc[0],0,1],
                         [fid_mm[3],fid_mm[2],0,1]])

x=(A.T*A).I*A.T*t

fid_mm = np.reshape(fid_mm, (-1,2))

x_fids = x[0]*fid_mm[:,0]-x[1]*fid_mm[:,1]+x[2]
y_fids = x[1]*fid_mm[:,0]+x[0]*fid_mm[:,1]+x[3]

print(x_fids.T[0],y_fids.T[0],x_fids.T[1],y_fids.T[1],x_fids.T[2],y_fids.T[2],x_fids.T[3],y_fids.T[3])
EOF
python3 fid_from_px.py | sed 's/[][]//g'
rm fid_from_px.py 
}

create_px_4fid_template()
{
#$frame $ULX $ULY $URX $URY $LRX $LRY $LLX $LLY
NAM=$(basename "$1" | sed 's/.\{4\}$//')
mkdir -p Ori-InterneScan
cat > Ori-InterneScan/MeasuresIm-${NAM}.tif.xml << EOF
<?xml version="1.0" ?>
<MesureAppuiFlottant1Im>
     <NameIm>${NAM}.tif</NameIm>
     <OneMesureAF1I>
          <NamePt>P1</NamePt>
          <PtIm>$2      $3</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P2</NamePt>
          <PtIm>$4      $5</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P3</NamePt>
          <PtIm>$6      $7</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P4</NamePt>
          <PtIm>$8      $9</PtIm>
     </OneMesureAF1I>
</MesureAppuiFlottant1Im>
EOF
}

cal_4fid_mm()
{
#From a series of fiducials, in mm, flips Y axis and translates the origin to UL. This goes into the file MeasuresCamera.xml, and avoids flip/flop of the images as output of ReSampFid.
#Input is 4 pairs of coordinates.
Yinv=$(echo $2 $4 $6 $8 | awk '{print -$1,-$2,-$3,-$4}')

Xmin=$(echo $1 $3 $5 $7 | awk '{m=$1;for(i=1;i<=NF;i++)if($i<m)m=$i;print m}')
Ymin=$(echo $Yinv | awk '{m=$1;for(i=1;i<=NF;i++)if($i<m)m=$i;print m}')

Xtr=$(echo $1 $3 $5 $7 | awk -v m=$Xmin '{print $1-m,$2-m,$3-m,$4-m}')
Ytr=$(echo $Yinv | awk -v m=$Ymin '{print $1-m,$2-m,$3-m,$4-m}')

echo $Xtr $Ytr | awk '{print $1,$5,$2,$6,$3,$7,$4,$8}'
}

cal_8fid_mm()
{
#From a series of fiducials, in mm, flips Y axis and translates the origin to UL. This goes into the file MeasuresCamera.xml, and avoids flip/flop of the images as output of ReSampFid.
#Input is 8 pairs of coordinates.
Yinv=$(echo $2 $4 $6 $8 $10 $12 $14 $16 | awk '{print -$1,-$2,-$3,-$4}')

Xmin=$(echo $1 $3 $5 $7 $9 $11 $13 $15 | awk '{m=$1;for(i=1;i<=NF;i++)if($i<m)m=$i;print m}')
Ymin=$(echo $Yinv | awk '{m=$1;for(i=1;i<=NF;i++)if($i<m)m=$i;print m}')

Xtr=$(echo $1 $3 $5 $7 $9 $11 $13 $15 | awk -v m=$Xmin '{print $1-m,$2-m,$3-m,$4-m,$5-m,$6-m,$7-m,$8-m}')
Ytr=$(echo $Yinv | awk -v m=$Ymin '{print $1-m,$2-m,$3-m,$4-m,$5-m,$6-m,$7-m,$8-m}')

echo $Xtr $Ytr | awk '{print $1,$5,$2,$6,$3,$7,$4,$8,$9,$10,$11,$12,$13,$14,$15,$16}'
}

create_cam_amsdma_4fid_template()
{
#Same format as "cal_fid_from_px"
#Fid1: Left, by the clocks
#Fid2-4: Clockwise

coor_mm=$(cal_4fid_mm $1 $2 $3 $4 $5 $6 $7 $8)

mkdir -p Ori-InterneScan
cat > Ori-InterneScan/MeasuresCamera.xml << EOF
<?xml version="1.0" ?>
<MesureAppuiFlottant1Im>
     <NameIm>Glob</NameIm>
     <OneMesureAF1I>
          <NamePt>P1</NamePt>
          <PtIm>$(echo $coor_mm | awk '{print $1}')     $(echo $coor_mm | awk '{print $2}')</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P2</NamePt>
          <PtIm>$(echo $coor_mm | awk '{print $3}')     $(echo $coor_mm | awk '{print $4}')</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P3</NamePt>
          <PtIm>$(echo $coor_mm | awk '{print $5}')     $(echo $coor_mm | awk '{print $6}')</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P4</NamePt>
          <PtIm>$(echo $coor_mm | awk '{print $7}')     $(echo $coor_mm | awk '{print $8}')</PtIm>
     </OneMesureAF1I>
</MesureAppuiFlottant1Im>
EOF
}

create_cam_lmi_4fid_template()
{
echo "Creating MeasuresCamera file..."
#$LLX $LLY $LRX $LRY $URX $URY $ULX $ULY
coor_mm=$(cal_4fid_mm $1 $2 $3 $4 $5 $6 $7 $8)

ulx=$(sort_ulurlrll $coor_mm | awk '{print $1}')
uly=$(sort_ulurlrll $coor_mm | awk '{print $2}')
urx=$(sort_ulurlrll $coor_mm | awk '{print $3}')
ury=$(sort_ulurlrll $coor_mm | awk '{print $4}')
lrx=$(sort_ulurlrll $coor_mm | awk '{print $5}')
lry=$(sort_ulurlrll $coor_mm | awk '{print $6}')
llx=$(sort_ulurlrll $coor_mm | awk '{print $7}')
lly=$(sort_ulurlrll $coor_mm | awk '{print $8}')

mkdir -p Ori-InterneScan
cat > Ori-InterneScan/MeasuresCamera.xml << EOF
<?xml version="1.0" ?>
<MesureAppuiFlottant1Im>
     <NameIm>Glob</NameIm>
     <OneMesureAF1I>
          <NamePt>P1</NamePt>
          <PtIm>$ulx    $uly</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P2</NamePt>
          <PtIm>$urx    $ury</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P3</NamePt>
          <PtIm>$lrx    $lry</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P4</NamePt>
          <PtIm>$llx    $lly</PtIm>
     </OneMesureAF1I>
</MesureAppuiFlottant1Im>
EOF
}

create_cam_lmi_8fid_template()
{
#WORK IN PROGRESS!!!
echo "Creating MeasuresCamera file..."
#$LLX $LLY $LRX $LRY $URX $URY $ULX $ULY
coor_mm=$(cal_4fid_mm $1 $2 $3 $4 $5 $6 $7 $8)

ulx=$(sort_ulurlrll $coor_mm | awk '{print $1}')
uly=$(sort_ulurlrll $coor_mm | awk '{print $2}')
urx=$(sort_ulurlrll $coor_mm | awk '{print $3}')
ury=$(sort_ulurlrll $coor_mm | awk '{print $4}')
lrx=$(sort_ulurlrll $coor_mm | awk '{print $5}')
lry=$(sort_ulurlrll $coor_mm | awk '{print $6}')
llx=$(sort_ulurlrll $coor_mm | awk '{print $7}')
lly=$(sort_ulurlrll $coor_mm | awk '{print $8}')

mkdir -p Ori-InterneScan
cat > Ori-InterneScan/MeasuresCamera.xml << EOF
<?xml version="1.0" ?>
<MesureAppuiFlottant1Im>
     <NameIm>Glob</NameIm>
     <OneMesureAF1I>
          <NamePt>P1</NamePt>
          <PtIm>$1      $2</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P2</NamePt>
          <PtIm>$3      $4</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P3</NamePt>
          <PtIm>$5      $6</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P4</NamePt>
          <PtIm>$7      $8</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P1</NamePt>
          <PtIm>$9      $10</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P2</NamePt>
          <PtIm>$11     $12</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P3</NamePt>
          <PtIm>$13     $14</PtIm>
     </OneMesureAF1I>
     <OneMesureAF1I>
          <NamePt>P4</NamePt>
          <PtIm>$15     $16</PtIm>
     </OneMesureAF1I>
</MesureAppuiFlottant1Im>
EOF
}

create_cam_lmi_1995()
{
#create_cam_lmi_8fid_template 105.997 -105.996 -105.999 -105.998 -106.000 105.998 105.998 105.997 -0.002 -111.995 -111.998 0.001 -0.001 111.997 111.997 0.000
create_cam_lmi_4fid_template 105.997 -105.996 -105.999 -105.998 -106.000 105.998 105.998 105.997 
}

create_cam_lmi_1994()
{
#create_cam_lmi_8 fid_template 105.997 -105.996 -105.999 -105.998 -106.000 105.998 105.998 105.997 -0.002 -111.995 -111.998 0.001 -0.001 111.997 111.997        0.000
create_cam_lmi_4fid_template 105.997 -105.996 -105.999 -105.998 -106.000 105.998 105.998 105.997 
}

create_cam_lmi_1993()
{
create_cam_lmi_4fid_template 106.001 -106.002 105.999 105.992 -106.004 106.003 -105.995 -105.992
}

create_cam_lmi_1991()
{
create_cam_lmi_4fid_template 106.001 -106.002 105.999 105.992 -106.004 106.003 -105.995 -105.992
}

create_cam_lmi_1991_aux()
{
create_cam_lmi_4fid_template 0.002 -115.629 -115.679 0.000 -0.002 115.831 115.777 0.000
}

create_cam_lmi_1990()
{
create_cam_lmi_4fid_template 106.001 -106.002 105.999 105.992 -106.004 106.003 -105.995 -105.992
}

create_cam_lmi_1989()
{
create_cam_lmi_4fid_template 105.996 -106.004 105.999 105.988 -105.998 106.004 -105.997 -105.990
}

create_cam_lmi_1987()
{
create_cam_lmi_4fid_template 106.000 -106.003 -106.008 -105.998 -106.004 106.007 106.000 105.990
}

create_cam_lmi_1987_aux()
{
create_cam_lmi_4fid_template 0.002 -115.629 -115.679 0.000 -0.002 115.831 115.777 0.000
}

create_cam_lmi_1986_aux()
{
create_cam_lmi_4fid_template 0.002 -115.629 -115.679 0.000 -0.002 115.831 115.777 0.000
}

create_cam_lmi_1985()
{
create_cam_lmi_4fid_template 106.000 -106.003 -106.008 -105.998 -106.004 106.007 106.000 105.990
}

create_cam_lmi_1985_aux()
{
create_cam_lmi_4fid_template 0.002 -115.629 -115.679 0.000 -0.002 115.831 115.777 0.000
}

create_cam_lmi_1984()
{
create_cam_lmi_4fid_template 106.000 -106.003 -106.008 -105.998 -106.004 106.007 106.000 105.990
}

create_cam_lmi_1984_aux()
{
create_cam_lmi_4fid_template 0.002 -115.629 -115.679 0.000 -0.002 115.831 115.777 0.000
}

create_cam_lmi_1983()
{
create_cam_lmi_4fid_template 106.000 -106.003 -106.008 -105.997 -106.004 106.007 106.000 105.990
}

create_cam_lmi_1982()
{
create_cam_lmi_4fid_template 106.000 -106.003 -106.008 -105.997 -106.004 106.007 106.000 105.990
}

create_cam_lmi_1979()
{
create_cam_lmi_4fid_template 106.004 -106.000 -106.004 -106.001 -106.007 106.003 105.997 105.993
}

create_cam_lmi_1978()
{
create_cam_lmi_4fid_template 106.004 -106.000 -106.004 -106.001 -106.007 106.003 105.997 105.993
}

create_cam_lmi_1976()
{
create_cam_lmi_4fid_template 106.004 -106.000 -106.004 -106.001 -106.007 106.003 105.997 105.993
}

create_cam_lmi_1975()
{
create_cam_lmi_4fid_template 106.004 -106.000 -106.004 -106.001 -106.007 106.003 105.997 105.993
}

create_cam_lmi_1974()
{
create_cam_lmi_4fid_template 106.004 -106.000 -106.004 -106.001 -106.007 106.003 105.997 105.993
}

create_cam_lmi_1970()
{ 
create_cam_lmi_4fid_template -81.980 -81.999 -81.998 81.989 81.990 82.009 82.008 -81.999
}

create_cam_lmi_1967()
{ 
create_cam_lmi_4fid_template -81.980 -81.999 -81.998 81.989 81.990 82.009 82.008 -81.999
}

create_cam_lmi_1958()
{ 
create_cam_lmi_4fid_template -81.980 -81.999 -81.998 81.989 81.990 82.009 82.008 -81.999
}

create_cam_lmi_1957()
{ 
create_cam_lmi_4fid_template -81.980 -81.999 -81.998 81.989 81.990 82.009 82.008 -81.999
}

create_cam_lmi_1954()
{ 
create_cam_lmi_4fid_template -81.980 -81.999 -81.998 81.989 81.990 82.009 82.008 -81.999
}

create_cam_chile_1984()
{
#create_cam_lmi_8 fid_template 105.997 -105.996 -105.999 -105.998 -106.000 105.998 105.998 105.997 -0.002 -111.995 -111.998 0.001 -0.001 111.997 111.997        0.000
create_cam_lmi_4fid_template -106.024 106.006  105.978 106.017 106.004 -106.014 -105.991 -106.014 
}
