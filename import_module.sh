# This script can help you
# 1 Import one module build including its rpm packages from brew production to brew-qa
# 2 Add tag to the imported module build
# It needs two args:
#   module_nvr: the nvr of module build
#   tag: that you want to tag to the imported module build

module_nvr=$1
tag=$2
rpm_NVRs=()
modulemd_files=()
baseURl="http://download.eng.bos.redhat.com"
mkdir -p module_build/$module_nvr
cd module_build/$module_nvr
dir=$(pwd)
brew buildinfo $module_nvr > buildinfo.txt
content_koji_tag=$(cat buildinfo.txt | grep 'content_koji_tag'| rev | cut -d \' -f2 | rev)

function get_rpm_build_in_module_build(){
        echo "===get rpm build with the content_koji_tag==="
    rpm_NVRs=$(brew list-tagged $content_koji_tag | grep "mbs" | sed "s/$content_koji_tag  mbs//")
}

function download_import_tag_rpm_build() {
        for NVR in $rpm_NVRs; do
        cd ${dir}
        mkdir $NVR
        cd $NVR
        echo "===start to download rpm for rpm build $NVR==="
        brew download-build $NVR
        echo "===start to import rpm build $NVR==="
        package_name=$(echo ${NVR%-*-*})
        cat <<EOF > ${dir}/importer.sh
alias koji='brew --user=root --password=redhat'
koji import --create-build /code/workspace/brew_importer/module_build/$module_nvr/${NVR}/*.rpm
koji add-tag $content_koji_tag
koji add-pkg --owner root $content_koji_tag $package_name
koji tag_build $content_koji_tag $NVR
EOF
        cd /root/brew-container
        docker-compose exec -T brew-hub sh /code/workspace/brew_importer/module_build/${module_nvr}/importer.sh
        done
}

function download_edit_metadata_json_file() {
	cd ${dir}
	echo "===start to download metadata json file==="
	module_metadata_json_file=$(cat buildinfo.txt | grep 'modulemd\.txt' | sed "s/\/mnt\/redhat//g" | sed "s/files\/module\/modulemd\.txt//g")
	download_json_url=${baseURl}${module_metadata_json_file}"metadata.json"
	wget $download_json_url
	echo "=== remove the build.log part from the metadata.json==="
	total_num=$(cat metadata.json | wc -l)
	start_num=$(expr ${total_num} - 10)
	end_num=$(expr ${total_num} - 2)
	#cp metadata.json metadata_backup.json
	sed -i "${start_num}, ${end_num} d"  metadata.json
	echo "===change the owner from other to root==="
	sed -i "s/\"owner\": \"[a-z]\+\"/\"owner\": \"root\"/g" metadata.json
}

function dowload_modulemd_files() {
	cd ${dir}
	modulemd_files=$(cat buildinfo.txt | grep 'modulemd\.' | sed "s/\/mnt\/redhat//g")
	mkdir files
    cd files
    echo "===start to download modulemd files==="
    for modulemd in $modulemd_files; do
		modulemd_file_url=$(echo "$baseURl"$modulemd)
		echo "$modulemd_file_url"
		wget $modulemd_file_url
	done
}

function import_module_build() {
        echo "===start to import module build==="
    package_name=$(echo ${module_nvr%-*-*})
    cat <<EOF > ${dir}/importer.sh
alias koji="brew --user=root --password=redhat"
koji call addBType module
koji grant-cg-access root module-build-service --new
# Import the module build by:
cd /code/workspace/brew_importer/module_build/${module_nvr}
koji import-cg metadata.json files
koji add-tag $tag
koji add-pkg --owner root ${tag} ${package_name}
koji tag_build $tag $module_nvr
EOF
        cd /root/brew-container
        docker-compose exec -T brew-hub sh /code/workspace/brew_importer/module_build/${module_nvr}/importer.sh
}

function delete_downloaded_file() {
	echo "===start to delete the downloaded files==="
	cd ${dir}/..
	rm -fr $module_nvr
}

get_content_koji_tag
get_rpm_build_in_module_build
download_import_tag_rpm_build
download_edit_metadata_json_file
dowload_modulemd_files
import_module_build
delete_downloaded_file
