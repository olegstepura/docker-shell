#!/bin/bash

REQUIRED_SHELL_FEATURES="sudo docker cat head base64 netstat tput ls rm eval read stat awk grep tr rlwrap"

TXTRED='\e[0;31m' # red
TXTGRN='\e[0;32m' # green
TXTYLW='\e[0;33m' # yellow
TXTBLU='\e[0;34m' # blue
TXTPUR='\e[0;35m' # purple
TXTCYN='\e[0;36m' # cyan
TXTWHT='\e[0;37m' # white
BLDRED='\e[1;31m' # red    - Bold
BLDGRN='\e[1;32m' # green
BLDYLW='\e[1;33m' # yellow
BLDBLU='\e[1;34m' # blue
BLDPUR='\e[1;35m' # purple
BLDCYN='\e[1;36m' # cyan
BLDWHT='\e[1;37m' # white
TXTRST='\e[0m'    # Text reset

function error {
	echo -e "$BLDRED$1$TXTRST"
}

function info {
	echo -e "$BLDGRN$1$TXTRST"
}

function header {
	echo -e "$BLDYLW$1$TXTRST"
}

function banner {
	echo -e "$BLDCYN$1$TXTRST"
}

function separator {
	head -c 64 < /dev/zero | tr '\0' "$1"
}

function up_one_line {
	# Go upper one line
	tput cuu1
	# Erase line
	tput el
}

function section_end {
	echo ""
	echo ""
}

function press_any_key {
	read -n1 -r -p "Press any key to proceed..."
}

function declare_var {
	# parameters: VAR, DATA 
	eval "export $VAR=\"$DATA\""
}

function _enter_data {
	# parameters: VAR, RLWRAP_ARGUMENTS, POSSIBLE_VALUES, PROMPT, PLACEHOLDER
	local FILE=$(tempfile)
	echo "$POSSIBLE_VALUES" > $FILE
	local DATA=$(rlwrap $RLWRAP_ARGUMENTS --prompt-colour=Yellow --histsize=0 --substitute-prompt="$PROMPT: " --break-chars=',' --file $FILE --pre-given "$PLACEHOLDER" --one-shot cat)
	rm $FILE
	DATA="${DATA/ /}" declare_var
}

function enter_value {
	# parameters: VAR, POSSIBLE_VALUES, PROMPT, PLACEHOLDER
	_enter_data
}

function enter_file {
	# parameters: VAR, POSSIBLE_VALUES, PROMPT, PLACEHOLDER
	RLWRAP_ARGUMENTS="--complete-filenames" _enter_data
}

function select_value {
	# parameters: VAR, POSSIBLE_VALUES[], PROMPT
	local PS3=$(header "$PROMPT: ")
	select opt in "${POSSIBLE_VALUES[@]}"; do
		case $opt in
			*)
				if [ -n "$opt" ]; then 
					break
				else
					error "Wrong option selected!"
				fi
			;;
		esac
	done
	DATA="$opt" declare_var
}

function docker_select_image {
	# parameters: VAR
	banner "Please select docker image from list:"
	local POSSIBLE_VALUES=($(sudo docker images | awk 'NR>1 { print $1; }' | grep -v "<none>" | tr '\n' ' '))
	PROMPT="Image number" select_value
	up_one_line
	header "Using image \"${!VAR}\""
	section_end
}

function docker_enter_image_name {
	# parameters: VAR, POSSIBLE_NAME
	banner "Please enter image name (usually in format user/name):"
	local LABEL="Image name"
	PROMPT="$LABEL" PLACEHOLDER="local/$POSSIBLE_NAME" POSSIBLE_VALUES="$POSSIBLE_NAME" enter_value
	up_one_line
	header "$LABEL \"${!VAR}\""
	section_end
}

function docker_select_container {
	# parameters: VAR, DESC 
	banner "Please select docker container ($DESC) from list:"
	local POSSIBLE_VALUES=($(sudo docker ps --format="{{.Names}}" | tr '\n' ' '))
	PROMPT="Container number" select_value
	up_one_line
	header "Using container \"${!VAR}\": $DESC"
	section_end
}

function docker_enter_container_name {
	# parameters: VAR, IMAGE
	banner "Please enter container name (to be displayed in list of running containers, format: container-name):"
	local PLACEHOLDER=$(echo $IMAGE | cut -d '/' -f2)
	local LABEL="Container name"
	PROMPT="$LABEL" POSSIBLE_VALUES="$PLACEHOLDER" enter_value
	up_one_line
	header "$LABEL \"${!VAR}\""
	section_end
}

function docker_enter_dir {
	# parameters: VAR, DESC, POSSIBLE_VALUES, PLACEHOLDER 
	banner "Please enter host $DESC directory:"
	PROMPT="Path" enter_file
	up_one_line
	mkdir -pv "${!VAR}"
	header "Using $DESC directory \"${!VAR}\", contents:"
	ls --almost-all -C --quote-name --classify --group-directories-first --color=always "${!VAR}"
	section_end
}

function docker_enter_file {
	# parameters: VAR, DESC, POSSIBLE_VALUES, PLACEHOLDER
	banner "Please enter host file with $DESC:"
	PROMPT="File" enter_file
	up_one_line
	local SIZE=$(stat -c%s "${!VAR}")
	header "Using $DESC file \"${!VAR}\", size: $SIZE bytes"
	section_end
}

function docker_enter_port {
	# parameters: VAR, DESC, POSSIBLE_VALUES, PLACEHOLDER
    banner "Please enter host port to expose $DESC to the world:"
    PROMPT="Port" enter_value
    up_one_line
	local USAGE=$(sudo netstat -lnp | grep "^tcp\|udp" | grep ":${!VAR} ")
	local MESSAGE="$DESC port \"${!VAR}\""
	if [ -n "$USAGE" ]; then
		error "$MESSAGE port is in use:"
		error "$USAGE"
	else
		header "Using $MESSAGE"
    fi
    section_end
}

function docker_enter_value {
	# parameters: VAR, DESC, PROMPT, POSSIBLE_VALUES, PLACEHOLDER
	banner "Please enter $DESC:"
	if [ -z "$PROMPT" ]; then
		PROMPT="$DESC"
	fi
	enter_value
	up_one_line
	header "Using $PROMPT \"${!VAR}\""
	section_end
}

function docker_enter_password {
	# parameters: VAR, DESC, PROMPT, LENGTH, RANDOM_SOURCE
	banner "Please enter password for $DESC (below is fresh generated one, ${BLDRED}last time to copy it${BLDCYN}, it will be hidden on pressing enter):"
	if [ -z "$PROMPT" ]; then
		PROMPT="$DESC"
	fi
	if [ -z "$LENGTH" ]; then
		LENGTH=24
	fi
	if [ -z "RANDOM_SOURCE" ]; then
		RANDOM_SOURCE=/dev/urandom
	fi
	PLACEHOLDER="$(cat $RANDOM_SOURCE | head -c $LENGTH | base64 | head -c $LENGTH)" enter_value
	up_one_line
	local PASS="${!VAR}"
	header "Using password for $PROMPT with length ${#PASS} symbols"
	section_end
}

function print_without_sensitive_data {
	# parameters: COMMAND, SENSITIVE_DATA
	local SUBST=$(head -c ${#SENSITIVE_DATA} < /dev/zero | tr '\0' '*')
	info "${COMMAND//$SENSITIVE_DATA/$SUBST}"
}

function _run {
	# parameters: COMMAND, SENSITIVE_DATA
	header "Will run:"
	header $(separator '-')
	print_without_sensitive_data
	header $(separator '-')
	press_any_key
	up_one_line
	
	eval "$COMMAND"
	section_end
}

function docker_run {
	# parameters: ARGUMENTS, CONTAINER_NAME, IMAGE, CONTAINER_COMMAND, SENSITIVE_DATA
	local COMMAND="sudo docker run $ARGUMENTS --name \"$CONTAINER_NAME\" --env TZ=\"$(cat /etc/timezone)\" --detach \"$IMAGE\" $CONTAINER_COMMAND"
	_run

	sudo docker ps
	section_end

	error $(separator '=')
	error "Tailing logs... It's safe to press CTRL+C to stop watching"
	error $(separator '=')
	section_end
	sudo docker logs -f "$CONTAINER_NAME"
}

function docker_build {
	# parameters: ARGUMENTS, IMAGE, DIR, SENSITIVE_DATA
	local COMMAND="sudo docker build --force-rm=true --rm=true $ARGUMENTS -t \"$IMAGE\" \"$DIR\""
	_run "$COMMAND"
}

for i in $REQUIRED_SHELL_FEATURES; do
    type $i >/dev/null 2>&1 || { echo -e "\n\n${BLDRED}Command \"${BLDCYN}$i${BLDRED}\" is not available! Required programs/shell features: ${TXTCYN}$REQUIRED_SHELL_FEATURES${TXTRST}\n\n"; exit 1; }
done
