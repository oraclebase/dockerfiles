echo "******************************************************************************"
echo "Install OS Packages." `date`
echo "******************************************************************************"
# fontconfig : Added to support OpenJDK inside container.
microdnf install -y unzip tar gzip freetype fontconfig ncurses shadow-utils
microdnf update -y
rm -Rf /var/cache/yum
rm -Rf /var/cache/dnf
