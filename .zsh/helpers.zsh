is-true-like() {
  [[ -n "$1" && "$1:l" == (1|y(es|)|t(rue|)|o(n|)) ]]
}

create_dir() {
  local dir="$1"

  if [[ ! -d $dir ]]; then
    echo "Creating $dir..."
    mkdir -p $dir
  fi
}

source_if_exists() {
  local file="$1"

  if [[ -r $file ]]; then
    source $file
  fi
}

has_command() {
  command -v $1 &> /dev/null
}

download_file() {
  local url="$1"
  local filename="$2"

  if [[ -z $url ]] || [[ -z $filename ]]; then
    print -P "%F{red}Error: URL and filename are required%f" >&2
    return 1
  fi

  if has_command curl; then
    curl -fsSL -o "$filename" "$url"
  elif has_command wget; then
    wget -q -O "$filename" "$url"
  else
    print -P "%F{red}Error: Neither curl nor wget is available%f" >&2
    return 1
  fi
}

extract_archive() {
  local archive="$1"
  local output_dir="$2"

  if [[ -z $archive ]]; then
    print -P "%F{red}Error: Archive file is required%f" >&2
    return 1
  fi

  if [[ ! -f $archive ]]; then
    print -P "%F{red}Error: Archive file not found: $archive%f" >&2
    return 1
  fi

  if [[ -n $output_dir ]]; then
    create_dir "$output_dir"
  fi

  case "$archive" in
    *.tar.gz|*.tgz)
      if [[ -n $output_dir ]]; then
        tar -xzf "$archive" -C "$output_dir"
      else
        tar -xzf "$archive"
      fi
      ;;
    *.zip)
      if has_command unzip; then
        if [[ -n $output_dir ]]; then
          unzip -q "$archive" -d "$output_dir"
        else
          unzip -q "$archive"
        fi
      else
        print -P "%F{red}Error: unzip command not available%f" >&2
        return 1
      fi
      ;;
    *)
      print -P "%F{red}Error: Unsupported archive format: $archive%f" >&2
      return 1
      ;;
  esac
}

verify_sha256() {
  local file="$1"
  local expected_hash="$2"

  if [[ -z $file ]] || [[ -z $expected_hash ]]; then
    print -P "%F{red}Error: File and expected hash are required%f" >&2
    return 1
  fi

  if [[ ! -f $file ]]; then
    print -P "%F{red}Error: File not found: $file%f" >&2
    return 1
  fi

  local actual_hash=""

  if [[ "$PLATFORM" == "darwin" ]]; then
    if has_command shasum; then
      actual_hash=$(shasum -a 256 "$file" | awk '{print $1}')
    else
      print -P "%F{red}Error: shasum command not available%f" >&2
      return 1
    fi
  else
    if has_command sha256sum; then
      actual_hash=$(sha256sum "$file" | awk '{print $1}')
    else
      print -P "%F{red}Error: sha256sum command not available%f" >&2
      return 1
    fi
  fi

  if [[ "$actual_hash" == "$expected_hash" ]]; then
    return 0
  else
    print -P "%F{red}Error: SHA256 verification failed%f" >&2
    print -P "%F{red}Error: Expected: $expected_hash%f" >&2
    print -P "%F{red}Error: Actual:   $actual_hash%f" >&2
    return 1
  fi
}

get_latest_github_version() {
  local version=$(curl -fsSL "${1}/latest" | grep -o 'tag/v[0-9.]*' | head -1 | cut -d'/' -f2 | cut -d'v' -f2)

  if [[ -z "$version" ]]; then
    print -P "%F{red}Error: Failed to fetch latest version%f" >&2
    return 1
  fi

  echo "$version"
}

get_github_binary_download_url_and_version() {
  local version=$1
  local base_url=$2
  local linux_platform_map=$3
  local darwin_platform_map=$4
  local x86_64_arch_map=$5
  local arm64_arch_map=$6
  local binary_name=$7

  if [[ "$version" == "latest" ]]; then
    version=$(get_latest_github_version $base_url)

    if [[ $? -ne 0 ]]; then
      return 1
    fi
  fi

  local platform_map=""
  local arch_map=""

  case "$PLATFORM" in
    darwin)
      platform_map=$darwin_platform_map
      ;;
    linux)
      platform_map=$linux_platform_map
      ;;
    *)
      print -P "%F{red}Error: Unsupported platform: $PLATFORM%f" >&2
      return 1
      ;;
  esac

  case "$ARCH" in
    x86_64|amd64)
      arch_map=$x86_64_arch_map
      ;;
    arm64|aarch64)
      arch_map=$arm64_arch_map
      ;;
    *)
      print -P "%F{red}Error: Unsupported architecture: $ARCH%f" >&2
      return 1
      ;;
  esac

  local reverse_platform_map_and_arch_map="${8:-false}"
  local full_binary_name=""

  if is-true-like $reverse_platform_map_and_arch_map; then
    full_binary_name="${binary_name}-${platform_map}-${arch_map}"
  else
    full_binary_name="${binary_name}-${arch_map}-${platform_map}"
  fi

  echo "${base_url}/download/v${version}/${full_binary_name}|$version"
}
