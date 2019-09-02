echo "******************************************************************************"
echo "Install OS Packages." `date`
echo "******************************************************************************"
# fontconfig : Added to support OpenJDK inside container.
dnf install -y unzip tar gzip freetype fontconfig ncurses
dnf update -y
rm -Rf /var/cache/yum
rm -Rf /var/cache/dnf
