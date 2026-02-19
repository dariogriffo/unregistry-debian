unregistry_VERSION=$1
BUILD_VERSION=$2
declare -a arr=("jammy" "noble" "questing")
for i in "${arr[@]}"
do
  UBUNTU_DIST=$i
  FULL_VERSION=$unregistry_VERSION-${BUILD_VERSION}+${UBUNTU_DIST}_amd64_ubu
  docker build . -t unregistry-ubuntu-$UBUNTU_DIST --build-arg UBUNTU_DIST=$UBUNTU_DIST --build-arg unregistry_VERSION=$unregistry_VERSION --build-arg BUILD_VERSION=$BUILD_VERSION --build-arg FULL_VERSION=$FULL_VERSION -f uDockerfile.ubu
  id="$(docker create unregistry-ubuntu-$UBUNTU_DIST)"
  docker cp $id:/unregistry_$FULL_VERSION.deb - > ./unregistry_$FULL_VERSION.deb
  tar -xf ./unregistry_$FULL_VERSION.deb

  docker build . -t docker-pussh-ubuntu-$UBUNTU_DIST --build-arg UBUNTU_DIST=$UBUNTU_DIST --build-arg unregistry_VERSION=$unregistry_VERSION --build-arg BUILD_VERSION=$BUILD_VERSION --build-arg FULL_VERSION=$FULL_VERSION -f pDockerfile.ubu
  id="$(docker create docker-pussh-ubuntu-$UBUNTU_DIST)"
  docker cp $id:/docker-pussh_$FULL_VERSION.deb - > ./docker-pussh_$FULL_VERSION.deb
  tar -xf ./docker-pussh_$FULL_VERSION.deb
done
