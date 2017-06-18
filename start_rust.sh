#!/usr/bin/env bash

RUST_DIR=${RUST_DIR:-/steamcmd/rust}

# Define the exit handler
exit_handler() {
	echo "Shutdown signal received"

	# Only do backups if we're using the seed override
	if [ -f "$RUST_DIR/seed_override" ]; then
		# Create the backup directory if it doesn't exist
		if [ ! -d "$RUST_DIR/bak" ]; then
			mkdir -p $RUST_DIR/bak
		fi
		if [ -f "$RUST_DIR/server/$RUST_SERVER_IDENTITY/UserPersistence.db" ]; then
			# Backup all the current unlocked blueprint data
			cp -fr "$RUST_DIR/server/$RUST_SERVER_IDENTITY/UserPersistence*.db" "$RUST_DIR/bak/"
		fi

		if [ -f "$RUST_DIR/server/$RUST_SERVER_IDENTITY/xp.db" ]; then
			# Backup all the current XP data
			cp -fr "$RUST_DIR/server/$RUST_SERVER_IDENTITY/xp*.db" "$RUST_DIR/bak/"
		fi
	fi
	
	echo "Exiting.."
	exit
}

# Install Rust from install.txt
rust_install() {
	echo "Installing Rust.. (this might take a while, be patient)"
	STEAMCMD_OUTPUT=$(bash /steamcmd/steamcmd.sh +runscript /install.txt | tee /dev/stdout)
	STEAMCMD_ERROR=$(echo $STEAMCMD_OUTPUT | grep -q 'Error')
	if [ ! -z "$STEAMCMD_ERROR" ]; then
		echo "Exiting, steamcmd install or update failed: $STEAMCMD_ERROR"
		exit 1
	fi
}

# Trap specific signals and forward to the exit handler
trap 'exit_handler' SIGHUP SIGINT SIGQUIT SIGTERM

# Remove old locks
rm -fr /tmp/*.lock

# Create the necessary folder structure
if [ ! -d "$RUST_DIR" ]; then
	echo "Creating folder structure.."
	mkdir -p $RUST_DIR
fi

# Install/update steamcmd
echo "Installing/updating steamcmd.."
curl -s http://media.steampowered.com/installer/steamcmd_linux.tar.gz | tar -v -C /steamcmd -zx

# Check which branch to use
if [ ! -z ${RUST_BRANCH+x} ]; then
	echo "Using branch arguments: $RUST_BRANCH"
	sed -i "s/app_update 258550.*validate/app_update 258550 $RUST_BRANCH validate/g" /install.txt
else
	sed -i "s/app_update 258550.*validate/app_update 258550 validate/g" /install.txt
fi

# Disable auto-update if start mode is 2
if [ "$RUST_START_MODE" = "2" ]; then
	# Check that Rust exists in the first place
	if [ ! -f "$RUST_DIR/RustDedicated" ]; then
		rust_install
	else
		echo "Rust seems to be installed, skipping automatic update.."
	fi
else
	rust_install

	# Run the update check if it's not been run before
	if [ ! -f "$RUST_DIR/build.id" ]; then
		./update_check.sh
	else
		OLD_BUILDID="$(cat $RUST_DIR/build.id)"
		STRING_SIZE=${#OLD_BUILDID}
		if [ "$STRING_SIZE" -lt "6" ]; then
			./update_check.sh
		fi
	fi
fi

# Rust includes a 64-bit version of steamclient.so, so we need to tell the OS where it exists
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$RUST_DIR/RustDedicated_Data/Plugins/x86_64

# Check if Oxide is enabled
if [ "$RUST_OXIDE_ENABLED" = "1" ]; then
	# Next check if Oxide doesn't' exist, or if we want to always update it
	INSTALL_OXIDE="0"
	if [ ! -f "$RUST_DIR/CSharpCompiler" ]; then
		INSTALL_OXIDE="1"
	fi
	if [ "$RUST_OXIDE_UPDATE_ON_BOOT" = "1" ]; then
		INSTALL_OXIDE="1"
	fi

	# If necessary, download and install latest Oxide
	if [ "$INSTALL_OXIDE" = "1" ]; then
		echo "Downloading and installing latest Oxide.."
		curl -sL https://dl.bintray.com/oxidemod/builds/Oxide-Rust.zip | bsdtar -xvf- -C $RUST_DIR/
		chmod 755 $RUST_DIR/CSharpCompiler*
		chown -R root:root $RUST_DIR
	fi
fi

# Start mode 1 means we only want to update
if [ "$RUST_START_MODE" = "1" ]; then
	echo "Exiting, start mode is 1.."
	exit
fi

# Add RCON support if necessary
RUST_STARTUP_COMMAND=$RUST_SERVER_STARTUP_ARGUMENTS
if [ ! -z ${RUST_RCON_PORT+x} ]; then
	RUST_STARTUP_COMMAND="$RUST_STARTUP_COMMAND +rcon.port $RUST_RCON_PORT"
fi
if [ ! -z ${RUST_RCON_PASSWORD+x} ]; then
	RUST_STARTUP_COMMAND="$RUST_STARTUP_COMMAND +rcon.password $RUST_RCON_PASSWORD"
fi
if [ ! -z ${RUST_RCON_WEB+x} ]; then
	RUST_STARTUP_COMMAND="$RUST_STARTUP_COMMAND +rcon.web $RUST_RCON_WEB"
fi

# Check if a special seed override file exists
if [ -f "$RUST_DIR/seed_override" ]; then
	RUST_SEED_OVERRIDE=`cat $RUST_DIR/seed_override`
	echo "Found seed override: $RUST_SEED_OVERRIDE"

	# Modify the server identity to include the override seed
	RUST_SERVER_IDENTITY=$RUST_SEED_OVERRIDE
	RUST_SERVER_SEED=$RUST_SEED_OVERRIDE

	# Prepare the identity directory (if it doesn't exist)
	if [ ! -d "$RUST_DIR/server/$RUST_SEED_OVERRIDE" ]; then
		echo "Creating seed override identity directory.."
		mkdir -p "$RUST_DIR/server/$RUST_SEED_OVERRIDE"
		if [ -f "$RUST_DIR/UserPersistence.db.bak" ]; then
			echo "Copying blueprint backup in place.."
			cp -fr "$RUST_DIR/UserPersistence.db.bak" "$RUST_DIR/server/$RUST_SEED_OVERRIDE/UserPersistence.db"
		fi
		if [ -f "$RUST_DIR/xp.db.bak" ]; then
			echo "Copying blueprint backup in place.."
			cp -fr "$RUST_DIR/xp.db.bak" "$RUST_DIR/server/$RUST_SEED_OVERRIDE/xp.db"
		fi
	fi
fi

## Disable logrotate if "-logfile" is set in $RUST_STARTUP_COMMAND
LOGROTATE_ENABLED=1
RUST_STARTUP_COMMAND_LOWERCASE=`echo "$RUST_STARTUP_COMMAND" | sed 's/./\L&/g'`
if [[ $RUST_STARTUP_COMMAND_LOWERCASE == *" -logfile "* ]]; then
	LOGROTATE_ENABLED=0
fi

if [ "$LOGROTATE_ENABLED" = "1" ]; then
	echo "Log rotation enabled!"

	# Log to stdout by default
	RUST_STARTUP_COMMAND="$RUST_STARTUP_COMMAND -logfile /dev/stdout"
	echo "Using startup arguments: $RUST_SERVER_STARTUP_ARGUMENTS"

	# Create the logging directory structure
	if [ ! -d "$RUST_DIR/logs/archive" ]; then
		mkdir -p $RUST_DIR/logs/archive
	fi

	# Set the logfile filename/path
	DATE=`date '+%Y-%m-%d_%H-%M-%S'`
	RUST_SERVER_LOG_FILE="$RUST_DIR/logs/$RUST_SERVER_IDENTITY"_"$DATE.txt"

	# Archive old logs
	echo "Cleaning up old logs.."
	mv $RUST_DIR/logs/*.txt $RUST_DIR/logs/archive
else
	echo "Log rotation disabled!"
fi

# Start cron
echo "Starting scheduled task manager.."
cd /rust_docker_control
npm scheduler &

# Set the working directory
cd $RUST_DIR

# Run the server
echo "Starting Rust.."
RUST_FULL_CMD=$(echo -e '$RUST_DIR/RustDedicated $RUST_STARTUP_COMMAND +server.identity "$RUST_SERVER_IDENTITY" +server.seed "$RUST_SERVER_SEED"  +server.hostname "$RUST_SERVER_NAME" +server.url "$RUST_SERVER_URL" +server.headerimage "$RUST_SERVER_BANNER_URL" +server.description "$RUST_SERVER_DESCRIPTION" +server.worldsize "$RUST_SERVER_WORLDSIZE" +server.maxplayers "$RUST_SERVER_MAXPLAYERS" +server.saveinterval "$RUST_SERVER_SAVE_INTERVAL" 2>&1')
if [ "$LOGROTATE_ENABLED" = "1" ]; then
	unbuffer $RUST_FULL_CMD | grep --line-buffered -Ev '^\s*$|Filename' | tee $RUST_SERVER_LOG_FILE &
else
	$RUST_FULL_CMD &
fi

child=$!
wait "$child"
echo "Exiting.."
exit
