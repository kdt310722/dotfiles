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
  local binary_name_delimiter="${9:--}"
  local full_binary_name=""

  if is-true-like $reverse_platform_map_and_arch_map; then
    full_binary_name="${binary_name}${binary_name_delimiter}${platform_map}-${arch_map}"
  else
    full_binary_name="${binary_name}${binary_name_delimiter}${arch_map}-${platform_map}"
  fi

  echo "${base_url}/download/v${version}/${full_binary_name}|$version"
}

notify() {
    local title="$1"
    local message="$2"

    case "$PLATFORM" in
      darwin)
        if has_command terminal-notifier; then
          terminal-notifier -title "$title" -message "$message"
        fi
        ;;
      linux)
        if has_command notify-send; then
          notify-send "$title" "$message"
        fi
        ;;
    esac
}

export BGR_TASKS_DIR="${ZSH_DATA_DIR}/bgr"

create_dir "$BGR_TASKS_DIR"

bgr() {
  local cmd="$1"
  local task_name="${2:-}"
  local title="${3:-Background Task}"
  local success_message="${4:-Task finished successfully}"
  local failure_message="${5:-Task failed}"

  if [[ -z "$task_name" ]]; then
    return 0
  fi

  local lock_file="${BGR_TASKS_DIR}/${task_name}.lock"

  if [[ -f "$lock_file" ]]; then
    local existing_pid=$(cat "$lock_file" 2>/dev/null)

    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      return 0
    else
      rm -f "$lock_file"
    fi
  fi

  setopt LOCAL_OPTIONS NO_NOTIFY NO_MONITOR

  {
    local task_id=$$
    local task_identifier="${task_name}-${task_id}"
    local output_file="${BGR_TASKS_DIR}/${task_identifier}.log"
    local pid_file="${BGR_TASKS_DIR}/${task_identifier}.pid"
    local start_time=$EPOCHSECONDS
    local exit_status=0
    local display_name="$task_name"

    echo $$ > "$lock_file"
    echo $$ > "$pid_file"

    notify "$title" "Command started ($display_name)"

    eval "$cmd" > "$output_file" 2>&1 || exit_status=$?

    local elapsed=$(( EPOCHSECONDS - start_time ))
    local elapsed_formatted="$(( elapsed % 60 ))s"

    (( elapsed < 60 )) || elapsed_formatted="$((( elapsed % 3600) / 60 ))m $elapsed_formatted"
    (( elapsed < 3600 )) || elapsed_formatted="$(( elapsed / 3600 ))h $elapsed_formatted"

    if [[ $exit_status -eq 0 ]]; then
      notify "$title" "$success_message (took $elapsed_formatted, $display_name)"
    else
      notify "$title" "$failure_message (took $elapsed_formatted, exit code: $exit_status, $display_name)"
    fi

    rm -f "$pid_file" "$lock_file"

    return $exit_status
  } &!
}
