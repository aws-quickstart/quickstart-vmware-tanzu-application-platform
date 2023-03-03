# Finds all `FROM` image references in any Dockerfile in the specified
# directory, loads them through the proxy DOCKER_HUB_PROXY and retags them to
# their originial name.
# Can be disabled if SKIP_LOAD_DOCKERFILE_FROMS is set.
docker::loadDockerfileFroms() {
  local dir="${1:-.}"
  local orgImg proxyImg
  local proxy="${DOCKER_HUB_PROXY?}"

  [[ -v SKIP_LOAD_DOCKERFILE_FROMS ]] && {
    echo >&2 "SKIP_LOAD_DOCKERFILE_FROMS is set, so not pulling Dockerfile FROMs through the proxy"
    return
  }

  while read orgImg ; do
    if grep -q '/' <<< "$orgImg"
    then
      proxyImg="${proxy}/${orgImg}"
    else
      proxyImg="${proxy}/library/${orgImg}"
    fi

    docker pull "$proxyImg" || {
      echo >&2 "Could not pull '$proxyImg', skipping"
      continue
    }

    docker tag "$proxyImg" "$orgImg" || {
      echo >&2 "Could not retag '$proxyImg' to '$orgImg', skipping"
      continue
    }
  done <<< "$( find "$dir" -type f -iname Dockerfile | xargs -r sed -n 's/^FROM \(.*\)/\1/ip' | sort | uniq )"
}

# Save images from dockerd into a tarball via `docker save`.
# Can be disabled if either the env var SKIP_DOCKER_CACHE_SAVE or
# SKIP_DOCKER_CACHE is set.
# Needs: pigz
docker::imageCacheSave() {
  local dest="$1"
  local images=()
  local repo tag id
  local base="$(basename "$dest")"
  local scratch="${SCRATCH_DIR:-/scratch}"

  [[ -v SKIP_DOCKER_CACHE_SAVE ]] && {
    echo >&2 "SKIP_DOCKER_CACHE_SAVE is set, so not saving images to '$dest'"
    return
  }
  [[ -v SKIP_DOCKER_CACHE ]] && {
    echo >&2 "SKIP_DOCKER_CACHE is set, so not saving images to '$dest'"
    return
  }

  while read repo tag id
  do
    if [[ "$repo" == '<none>' ]] || [[ "$tag" == '<none>' ]] ; then
      images+=( "$id" )
    else
      images+=( "${repo}:${tag}" )
    fi
  done < <( docker image ls -a --format '{{ .Repository }}\t{{ .Tag }}\t{{ .ID }}' )

  mkdir -p "$scratch"
  docker save "${images[@]}" | pigz > "${scratch}/${base}"
  mv "${scratch}/${base}" "$dest"
}

# Load images in $1 into dockerd via `docker load`.
# Can be disabled if either the env var SKIP_DOCKER_CACHE or
# SKIP_DOCKER_CACHE_LOAD is set.
docker::imageCacheLoad() {
  local images="$1"

  [[ -v SKIP_DOCKER_CACHE_LOAD ]] && {
    echo >&2 "SKIP_DOCKER_CACHE_LOAD is set, so not loading images from '$images'"
    return
  }
  [[ -v SKIP_DOCKER_CACHE ]] && {
    echo >&2 "SKIP_DOCKER_CACHE is set, so not loading images from '$images'"
    return
  }

  [[ -e "$images" ]] || {
    echo >&2 "'$images' does not exist, not loading cached layers"
    return
  }

  # docker load can handle gzipped tarballs
  docker load -i "$images"
}
