echo "******************************************************************************"
echo "Install OS Packages." `date`
echo "******************************************************************************"
microdnf install -y unzip tar gzip shadow-utils
microdnf install -y oracle-database-preinstall-21c
microdnf update -y
rm -Rf /var/cache/yum
rm -Rf /var/cache/dnf
