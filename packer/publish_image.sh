#!/bin/bash
#OS_NAME=hpc-centos-7
#OS_NAME=centos-7
#OS_NAME=debian-10
# ./publish_image.sh <prefix> <slurm version> <os>
# ./publish_image.sh dev 22-05-8 hpc-centos-7
PREFIX=$1
SLURM=$2
OS_NAME=$3
SOURCE_PROJECT=schedmd-public-292016
PUBLISH_PROJECT=schedmd-slurm-public
PUBLISH_PREFIX=schedmd
LICENSE=projects/$PUBLISH_PROJECT/global/licenses/schedmd-slurm-gcp-free-plan
SOURCE_FAMILY=$PREFIX-v5-slurm-$SLURM-$OS_NAME

family_info=$(gcloud compute images describe-from-family $SOURCE_FAMILY --project=$SOURCE_PROJECT --format=json)
SOURCE_IMAGE=$(jq -r .name <<< $family_info)
creation_time=$(jq -r .creationTimestamp <<< $family_info)
publish_image=${SOURCE_IMAGE/#$PREFIX/$PUBLISH_PREFIX}
publish_family=${SOURCE_FAMILY/$PREFIX/$PUBLISH_PREFIX}

echo source image: $SOURCE_PROJECT/$SOURCE_IMAGE
echo created $creation_time
echo publish image: $PUBLISH_PROJECT/$publish_image
read -p "publish image?" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi
#gcloud compute images delete --project=$PUBLISH_PROJECT $IMAGE_NAME
echo
echo Create Image $publish_image
CREATE_CMD=\
"gcloud compute images create $publish_image \
--project $PUBLISH_PROJECT \
--family $publish_family \
--source-image-project $SOURCE_PROJECT \
--source-image $SOURCE_IMAGE \
--licenses $LICENSE \
--description \"Public Slurm image based on the $OS_NAME image\" \
--force"
echo $CREATE_CMD
eval "$CREATE_CMD"

echo
echo Add public compute.imageUser to $publish_image
MAKE_PUBLIC=\
"gcloud compute images add-iam-policy-binding $publish_image \
--member='allAuthenticatedUsers' \
--role='roles/compute.imageUser' \
--project=$PUBLISH_PROJECT"
echo $MAKE_PUBLIC
eval "$MAKE_PUBLIC"

echo
echo Add public compute.viewer to $publish_image
MAKE_VIEWABLE=\
"gcloud compute images add-iam-policy-binding $publish_image \
--member='allAuthenticatedUsers' \
--role='roles/compute.viewer' \
--project=$PUBLISH_PROJECT"
echo $MAKE_VIEWABLE
eval "$MAKE_VIEWABLE"
