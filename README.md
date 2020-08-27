# MM_Historical
Scripts for processing scanned aerial photographs. The core of these tools lays on the MicMac software, but other dependencies are needed for a straight-forward pipeline.

The first step from scanned aerial photographs is to measure the fiducials. In MicMac, the best way is to measure and crop them, to re-create the case of a digital camera. An example to crop the images is given in crop.sh

With the cropped images, two cases are presented for processing. Both cases need Ground Control Points (GCPs).

example_micmac_demref.sh: Case where we have a reference HR DEM (and if needed, an orthoimage perfectly aligned to the DEM), to extract ground coordinates.

example_micmac_norefdem.sh: Case where we do not have a HR DEM, but we have an "old style" list of GCPs with XYZ coordinates (e.g. GPS-based)

Dependencies:

MicMac (https://micmac.ensg.eu/)

Ames StereoPipeline (https://ti.arc.nasa.gov/tech/asr/groups/intelligent-robotics/ngt/stereo/)

GDAL (https://www.gdal.org/)

General unix tools: sed, awk, grep, sort

GNU Parallel

Rename

Please cite:
Belart et al., 2019
