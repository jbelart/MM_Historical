# MM_Historical
Scripts for processing scanned aerial photographs. The core tools are from MicMac, but since MicMac relies on a lot of xml files, these scripts simplify the process into one single and straight-forward pipeline.

The first step for processing of scanned aerial photographs is to measure the fiducials. In MicMac, the best way is to measure and crop them, to re-create the case of a digital camera. An example to crop the images is given in crop_withfid.sh. If no fiducials are available, another example can be seen in crop_nofid.sh

With the cropped images, two cases are presented for processing. Both cases need Ground Control Points (GCPs).

example_micmac_demref.sh: Case where we have a reference HR DEM (and if needed, an orthoimage perfectly aligned to the DEM), to extract ground coordinates.

example_micmac_norefdem.sh: Case where we do not have a HR DEM, but we have an "old style" list of GCPs with XYZ coordinates (e.g. GPS-based)


Dependencies:

MicMac (https://micmac.ensg.eu/)

Ames StereoPipeline (https://ti.arc.nasa.gov/tech/asr/groups/intelligent-robotics/ngt/stereo/)

GDAL (https://www.gdal.org/)

GNU Parallel (https://www.gnu.org/software/parallel/)

General unix tools: sed, awk, grep, sort, rename

For the steps requiring digitization of coordinates (pixel or ground), it's reccommended to simply use QGIS (www.qgis.org) and the module "coordinate capturer"

If used, please cite:
Belart, J. M. C., Magnússon, E., Berthier, E., Pálsson, F., Aðalgeirsdóttir, G., and Jóhannesson, T. (2019). The geodetic mass balance of Eyjafjallajökull ice cap for 1945–2014: processing guidelines and relation to climate. Journal of Glaciology 65, 395–409. doi:10.1017/jog.2019.16
