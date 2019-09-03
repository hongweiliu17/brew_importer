# This script can help you
# 1 Import one module build including its rpm packages from brew production to brew-qa
# 2 Add tag to the imported module build
# It needs two args:
#   module_nvr: the nvr of module build
#   tag: that you want to tag to the imported module build

module_nvr=$1
tag=$2
#'rhel-8.0-candidate'
content_koji_tag=""
rpm_NVRs=()
modulemd_files=()
dir=$(pwd)

function get_buildinfo() {
	echo "print build info to buildinfo.txt"
	brew buildinfo $module_nvr > buildinfo.txt
}

function get_content_koji_tag() {
	echo "get content_koji_tag"
    content_koji_tag=$(cat buildinfo.txt | grep 'content_koji_tag'| rev | cut -d \' -f2 | rev)
    echo "$content_koji_tag"
}

function get_rpm_build_in_module_build(){
	echo "get rpm build with the content_koji_tag"
    rpm_NVRs=$(brew list-tagged $content_koji_tag | grep "mbs" | sed "s/$content_koji_tag  mbs//")
}

function download_import_tag_rpm_build() {
	echo "start to download and "
	cd ${dir}/${module_nvr}
	for NVR in $rpm_NVRs; do
    	mkdir $NVR
    	cd $NVR
        echo "start to download rpm for rpm build $NVR"
    	brew download-build $NVR
    	echo "start to import rpm build $NVR"
    	#koji import --create-build *.rpm
    	#echo "start to tag rpm build $NVR"
    	#koji add-tag $content_koji_tag
    	#package_name=$(printf '%-6d' $NVR)
    	#koji add-pkg --owner root $content_koji_tag copy-jdk-configs
    	#koji tag-build $content_koji_tag NVR
	done
}

function download_edit_metadata_json_file() {
	cd ${dir}/${module_nvr}
	echo "start to download metadata json file"
	baseURl="http://download.eng.bos.redhat.com/brewroot/packages/"
	module_metadata_json_url=$(echo "$module_nvr" | sed "s/-/\//g")"/metadata.json"
	download_json_url=${baseURl}${module_metadata_json_url}
	echo "$download_json_url"
	wget download_json_url
	echo "=== remove the build.log part from the metadata.json"
	total_num=$(cat metadata.json | wc -l)
	start_num=$(expr ${total_num} - 9)
	end_num=$(expr ${total_num} - 1)
	cp metadata.json metadata_backup.json
	sed -i "${start_num}, ${end_num} d"  metadata.json
	echo "=== change the owner from other to root"
	sed -i "s/\"owner\": \"[a-z]\+\"/\"owner\": \"root\"/g" metadata.json
}

function dowload_modulemd_files() {
	cd ${dir}/${module_nvr}
	modulemd_files=$(cat buildinfo.txt | grep 'modulemd\.' | sed "s/\/mnt\/redhat//g")
	mkdir files
    cd files
    for modulemd in $modulemd_files; do
		modulemd_file_url=$(echo "http://download.eng.bos.redhat.com"$modulemd)
		echo "$modulemd_file_url"
		wget $modulemd_file_url
	done
}

function import_module_build() {
	koji call addBType module
    koji grant-cg-access root module-build-service --new
    # Import the module build by:
    koji import-cg metadata.json files
}

mkdir $module_nvr
cd $module_nvr
#download_edit_metadata_json_file
dowload_modulemd_files
