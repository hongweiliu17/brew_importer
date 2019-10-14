#!/bin/bash
# This script can help you
# 1 Import one rpm build including its rpm packages from brew production to brew-qa
# 2 Add tag to the imported rpm build
# It needs two args:
#   rpm_nvr: the nvr of rpm build
#   tag: that you want to tag to the imported rpm build

rpm_nvr=$1
tag=$2
mkdir -p import_build/$rpm_nvr
cd import_build/$rpm_nvr
dir=$(pwd)

function download_import_tag_rpm_build() {
    cd ${dir}
    echo "===start to download rpm for rpm build $rpm_nvr==="
    brew download-build $rpm_nvr
    echo "===start to import rpm build $rpm_nvr==="
    package_name=$(echo ${rpm_nvr%-*-*})
    cat <<EOF > ${dir}/importer.sh
alias koji='brew --user=root --password=redhat'
koji import --create-build /code/workspace/brew_qa_build_import/import_build/$rpm_nvr/*.rpm
koji add-tag $tag
koji add-pkg --owner root $tag $package_name
koji tag_build $tag $rpm_nvr
EOF
    cd /root/brew-container
    docker-compose exec -T brew-hub sh /code/workspace/brew_qa_build_import/import_build/${rpm_nvr}/importer.sh
}

function delete_downloaded_file() {
	echo "===start to delete the downloaded files==="
	cd ${dir}/..
	rm -fr $rpm_nvr
}

download_import_tag_rpm_build
delete_downloaded_file
