#!/bin/sh
# Taken from https://github.com/minio/charts/blob/master/minio/templates/_helper_create_bucket.txt
set -e ; # Have script exit in the event of a failed command.
MC_CONFIG_DIR="/etc/minio/mc/"
MC="/usr/bin/mc --insecure --config-dir ${MC_CONFIG_DIR}"

# connectToMinio
# Use a check-sleep-check loop to wait for Minio service to be available
connectToMinio() {
  ATTEMPTS=0 ; LIMIT=29 ; # Allow 30 attempts
  set -e ; # fail if we can't read the keys.
  ACCESS=$(cat /config/accesskey) ; SECRET=$(cat /config/secretkey) ;
  set +e ; # The connections to minio are allowed to fail.
  echo "Connecting to Minio server: $SCHEME://$MINIO_ENDPOINT:$MINIO_PORT" ;
  MC_COMMAND="${MC} config host add myminio $SCHEME://$MINIO_ENDPOINT:$MINIO_PORT $ACCESS $SECRET" ;
  $MC_COMMAND ;
  STATUS=$? ;
  until [ $STATUS = 0 ]
  do
    ATTEMPTS=`expr $ATTEMPTS + 1` ;
    echo \"Failed attempts: $ATTEMPTS\" ;
    if [ $ATTEMPTS -gt $LIMIT ]; then
      exit 1 ;
    fi ;
    sleep 2 ; # 1 second intervals between attempts
    $MC_COMMAND ;
    STATUS=$? ;
  done ;
  set -e ; # reset `e` as active
  return 0
}

# checkBucketExists ($bucket)
# Check if the bucket exists, by using the exit code of `mc ls`
checkBucketExists() {
  BUCKET=$1
  CMD=$(${MC} ls myminio/$BUCKET > /dev/null 2>&1)
  return $?
}

# createBucket ($bucket, $policy, $purge)
# Ensure bucket exists, purging if asked to
createBucket() {
  BUCKET=$1
  POLICY=$2
  PURGE=$3
  VERSIONING=$4

  # Purge the bucket, if set & exists
  # Since PURGE is user input, check explicitly for `true`
  if [ $PURGE = true ]; then
    if checkBucketExists $BUCKET ; then
      echo "Purging bucket '$BUCKET'."
      set +e ; # don't exit if this fails
      ${MC} rm -r --force myminio/$BUCKET
      set -e ; # reset `e` as active
    else
      echo "Bucket '$BUCKET' does not exist, skipping purge."
    fi
  fi

  # Create the bucket if it does not exist
  if ! checkBucketExists $BUCKET ; then
    echo "Creating bucket '$BUCKET'"
    ${MC} mb myminio/$BUCKET
  else
    echo "Bucket '$BUCKET' already exists."
  fi


  # set versioning for bucket
  if [ ! -z $VERSIONING ] ; then
    if [ $VERSIONING = true ] ; then
        echo "Enabling versioning for '$BUCKET'"
        ${MC} version enable myminio/$BUCKET
    elif [ $VERSIONING = false ] ; then
        echo "Suspending versioning for '$BUCKET'"
        ${MC} version suspend myminio/$BUCKET
    fi
  else
      echo "Bucket '$BUCKET' versioning unchanged."
  fi

  # At this point, the bucket should exist, skip checking for existence
  # Set policy on the bucket
  echo "Setting policy of bucket '$BUCKET' to '$POLICY'."
  ${MC} policy set $POLICY myminio/$BUCKET
}

# Try connecting to Minio instance
connectToMinio
# Create the bucket
createBucket bucket none false
