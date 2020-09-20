_check_prog() {
	! _typeDep true && return 1
	
	return 0
}

_test_prog() {
	_getDep true
	
	! _check_prog && echo 'missing: dependency mismatch' && _stop 1
	
	return 0
}

_test_build_prog() {
	_getDep gperf
	_getDep xsltproc
}

# WARNING: Only use this function to retrieve initial sources, as documenation.. Do NOT perform update (ie. git submodule) operations. Place those instructions under _update_mod .
_fetch_prog() {
	true
}

_build_transfer() {
	[[ "$1" == "" ]] && return 1
	[[ "$2" == "" ]] && return 1
	[[ "$3" == "" ]] && return 1
	rsync -q -ax --exclude ".git" --exclude "README.git" "$1"/"$3" "$2"/"$3"
}

_build_transfer_dir() {
	mkdir -p "$2"
	_build_transfer "$@"
}

#"$1" == "targetArch"
_build_prog_sequence() {
	_start
	_prepare_build_prog
	local localFunctionEntryPWD
	localFunctionEntryPWD="$PWD"
	
	_messageNormal 'BUILD: Product: Init'
	
	local targetArch
	targetArch=$(gcc -v 2>&1 | awk '/Target/ { print $2 }')
	[[ "$1" != "" ]] && targetArch="$1"
	
	#disable pkg-config
	export PKG_CONFIG_PATH="$scriptAbsoluteFolder"/build
	
	mkdir -p "$safeTmp"/build
	
	_build_transfer_dir "$scriptLib"/eudev "$safeTmp"/build/eudev .
	_build_transfer_dir "$scriptLib"/libusb "$safeTmp"/build/libusb .
	_build_transfer_dir "$scriptLib"/libusb-compat-0.1_git "$safeTmp"/build/libusb-compat-0.1_git .
	_build_transfer_dir "$scriptLib"/hidapi "$safeTmp"/build/hidapi .
	
	_build_transfer_dir "$scriptLib"/openocd-code "$safeTmp"/build/openocd-code .
	
	## eUDEV
	_messageNormal 'BUILD: eUDEV'
	if [[ "$targetArch" != *'darwin'* ]]
	then
		cd "$safeTmp"/build/eudev
		export UDEV_DIR=`pwd`
		! ./autogen.sh && _messageError 'FAIL: autoregen' && _stop 1
		! ./configure --enable-static --disable-shared --disable-blkid --disable-kmod  --disable-manpages && _messageError 'FAIL: configure' && _stop 1
		! make clean && _messageError 'FAIL: make clean' && _stop 1
		! make -j8 && _messageError 'FAIL: make' && _stop 1

		export CFLAGS="-I$UDEV_DIR/src/libudev/"
		export LDFLAGS="-L$UDEV_DIR/src/libudev/.libs/"
		export LIBS="-ludev"
	fi
	
	## LibUSB
	_messageNormal 'BUILD: LibUSB'
	cd "$safeTmp"/build/libusb
	export LIBUSB_DIR=`pwd`
	! ./bootstrap.sh && _messageError 'FAIL: bootstrap' && _stop 1
	! ./configure --enable-static --disable-shared && _messageError 'FAIL: configure' && _stop 1
	! make clean && _messageError 'FAIL: make clean' && _stop 1
	! make && _messageError 'FAIL: make' && _stop 1
	
	export LIBUSB1_CFLAGS="-I$LIBUSB_DIR/libusb/"
	export LIBUSB1_LIBS="-L$LIBUSB_DIR/libusb/.libs/ -lusb-1.0 -lpthread"

	export LIBUSB_1_0_CFLAGS="-I$LIBUSB_DIR/libusb/"
	export LIBUSB_1_0_LIBS="-L$LIBUSB_DIR/libusb/.libs/ -lusb-1.0 -lpthread"
	
	## LibUSB-Compat
	_messageNormal 'BUILD: LibUSB-Compat'
	cd "$safeTmp"/build/libusb-compat-0.1_git
	export LIBUSB0_DIR=`pwd`
	! ./bootstrap.sh && _messageError 'FAIL: bootstrap' && _stop 1
	! autoreconf && _messageError 'FAIL: autoreconf' && _stop 1
	! ./configure --enable-static --disable-shared && _messageError 'FAIL: configure' && _stop 1
	! make clean && _messageError 'FAIL: make clean' && _stop 1
	! make && _messageError 'FAIL: make' && _stop 1
	
	export libusb_CFLAGS="-I$LIBUSB_DIR/libusb/"
	export libusb_LIBS="-L$LIBUSB_DIR/libusb/.libs/ -lusb-1.0 -lpthread"
	export libudev_CFLAGS="-I$UDEV_DIR/src/libudev/"
	export libudev_LIBS="-L$UDEV_DIR/src/libudev/.libs/ -ludev"
	
	## HIDAPI
	_messageNormal 'BUILD: HIDAPI'
	cd "$safeTmp"/build/hidapi
	! ./bootstrap && _messageError 'FAIL: bootstrap' && _stop 1
	export HIDAPI_DIR=`pwd`
	./configure --enable-static --disable-shared
	make clean
	make -j4
	
	
	## PRODUCT - OpenOCD
	_messageNormal 'BUILD: Product: Complete'
	cd "$safeTmp"/build/openocd-code
	! ./bootstrap "nosubmodule" && _messageError 'FAIL: bootstrap' && _stop 1
	export LIBUSB0_CFLAGS="-I$LIBUSB0_DIR/libusb/" 
	export LIBUSB0_LIBS="-L$LIBUSB0_DIR/libusb/.libs/ -lusb -lpthread" 
	export LIBUSB1_CFLAGS="-I$LIBUSB_DIR/libusb/" 
	export LIBUSB1_LIBS="-L$LIBUSB_DIR/libusb/.libs/ -lusb-1.0 -lpthread" 
	export HIDAPI_CFLAGS="-I$HIDAPI_DIR/hidapi/"

	if [[ "$targetArch" != *darwin* ]]; then
		export HIDAPI_LIBS="-L$HIDAPI_DIR/linux/.libs/ -L$HIDAPI_DIR/libusb/.libs/ -lhidapi-hidraw -lhidapi-libusb"
	else
		export HIDAPI_LIBS="-L$HIDAPI_DIR/mac/.libs/ -L$HIDAPI_DIR/libusb/.libs/ -lhidapi"
	fi

	export CFLAGS="-DHAVE_LIBUSB_ERROR_NAME"
	! PKG_CONFIG_PATH=`pwd` ./configure --disable-werror --prefix="$scriptAbsoluteFolder"/build && _messageError 'FAIL: configure' && _stop 1
	! make clean && _messageError 'FAIL: make clean' && _stop 1
	! CFLAGS=-static make && _messageError 'FAIL: make' && _stop 1
	! make install && _messageError 'FAIL: make install' && _stop 1

	
	
	cd "$localFunctionEntryPWD"
	_stop
}

_build_prog() {
	_fetch_prog
	
	"$scriptAbsoluteLocation" _build_prog_sequence "$@"
}

_testBuilt_prog() {
	! [[ -e "$scriptAbsoluteFolder"/build/bin/openocd ]] && _stop 1
	
	if ! "$scriptAbsoluteFolder"/build/bin/openocd --help 2>&1 | grep 'Open On-Chip Debugger' >/dev/null 2>&1
	then
		_stop 1
	fi
}

# CAUTION: Reboot or relogin may be required to take effect.
_setup_udev() {
	! _wantSudo && echo 'denied: sudo' && _stop 1
	
	sudo -n bash -c '[[ -e /etc/udev/rules.d/ ]]' && sudo -n cp -r "$scriptLib"/app/udev/rules/. /etc/udev/rules.d/
	
	# WARNING: System groups are expected to have been created with correct uid/gid by other utilities prior to running these scripts.
	#sudo -n groupadd plugdev
	sudo -n usermod -a -G plugdev "$USER"
	
	#sudo -n groupadd dialout
	sudo -n usermod -a -G dialout "$USER"
}

_setup_prog() {
	_setup_udev
}
