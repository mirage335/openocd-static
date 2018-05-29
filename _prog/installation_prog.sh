_check_prog() {
	! _typeDep true && return 1
	
	return 0
}

_test_prog() {
	_getDep true
	
	! _check_prog && echo 'missing: dependency mismatch' && _stop 1
}

_test_build_prog() {
	_getDep gperf
}

# WARNING: Only use this function to retrieve initial sources, as documenation.. Do NOT perform update (ie. git submodule) operations. Place those instructions under _update_mod .
_fetch_prog() {
	true
}

#"$1" == "targetArch"
_build_prog_sequence() {
	_start
	_prepare_build_prog
	local localFunctionEntryPWD
	localFunctionEntryPWD="$PWD"
	
	
	local targetArch
	targetArch=$(gcc -v 2>&1 | awk '/Target/ { print $2 }')
	[[ "$1" != "" ]] && targetArch="$1"
	
	#disable pkg-config
	export PKG_CONFIG_PATH="$scriptAbsoluteFolder"/build
	
	if [[ "$targetArch" != *'darwin'* ]]
	then
		cd "$scriptLib"/eudev
		export UDEV_DIR=`pwd`
		./autogen.sh
		./configure --enable-static --disable-shared --disable-blkid --disable-kmod  --disable-manpages
		make clean
		make -j4

		export CFLAGS="-I$UDEV_DIR/src/libudev/"
		export LDFLAGS="-L$UDEV_DIR/src/libudev/.libs/"
		export LIBS="-ludev"
	fi
	
	
	cd "$localFunctionEntryPWD"
	_stop
}

_build_prog() {
	_fetch_prog
	
	"$scriptAbsoluteLocation" _build_prog_sequence "$@"
}

_setup_udev() {
	! _wantSudo && echo 'denied: sudo' && _stop 1
	
	sudo -n bash -c '[[ -e /etc/udev/rules.d/ ]]' && sudo -n cp "$scriptLib"/app/udev/rules/. /etc/udev/rules.d/
	
	
	sudo -n usermod -a -G plugdev "$USER"
}

_setup_prog() {
	_setup_udev
}
