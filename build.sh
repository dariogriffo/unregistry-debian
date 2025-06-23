unregistry_VERSION=$1
BUILD_VERSION=$2
declare -a arr=("bookworm" "trixie" "sid")
for i in "${arr[@]}"
do
  DEBIAN_DIST=$i
  FULL_VERSION=$unregistry_VERSION-${BUILD_VERSION}+${DEBIAN_DIST}_amd64
  docker build . -t unregistry-$DEBIAN_DIST  --build-arg DEBIAN_DIST=$DEBIAN_DIST --build-arg unregistry_VERSION=$unregistry_VERSION --build-arg BUILD_VERSION=$BUILD_VERSION --build-arg FULL_VERSION=$FULL_VERSION -f uDockerfile
  id="$(docker create unregistry-$DEBIAN_DIST)"
  docker cp $id:/unregistry_$FULL_VERSION.deb - > ./unregistry_$FULL_VERSION.deb
  tar -xf ./unregistry_$FULL_VERSION.deb
  
  docker build . -t docker-pussh-$DEBIAN_DIST  --build-arg DEBIAN_DIST=$DEBIAN_DIST --build-arg unregistry_VERSION=$unregistry_VERSION --build-arg BUILD_VERSION=$BUILD_VERSION --build-arg FULL_VERSION=$FULL_VERSION -f pDockerfile
  id="$(docker create docker-pussh-$DEBIAN_DIST)"
  docker cp $id:/docker-pussh_$FULL_VERSION.deb - > ./docker-pussh_$FULL_VERSION.deb
  tar -xf ./docker-pussh_$FULL_VERSION.deb
done


