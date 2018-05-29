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

_build_transfer() {
	[[ "$1" == "" ]] && return 1
	[[ "$2" == "" ]] && return 1
	[[ "$3" == "" ]] && return 1
	rsync -q -ax --exclude "/.git" "$1"/"$3" "$2"/"$3"
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
		! ./autogen.sh && _messageFAIL 'FAIL: autoregen' && _stop 1
		! ./configure --enable-static --disable-shared --disable-blkid --disable-kmod  --disable-manpages && _messageFAIL 'FAIL: configure' && _stop 1
		! make clean && _messageFAIL 'FAIL: make clean' && _stop 1
		! make -j4 && _messageFAIL 'FAIL: make' && _stop 1

		export CFLAGS="-I$UDEV_DIR/src/libudev/"
		export LDFLAGS="-L$UDEV_DIR/src/libudev/.libs/"
		export LIBS="-ludev"
	fi
	
	## LibUSB
	_messageNormal 'BUILD: LibUSB'
	cd "$safeTmp"/build/libusb
	export LIBUSB_DIR=`pwd`
	! ./bootstrap && _messageFAIL 'FAIL: bootstrap' && _stop 1
	! ./configure --enable-static --disable-shared && _messageFAIL 'FAIL: configure' && _stop 1
	! make clean && _messageFAIL 'FAIL: make clean' && _stop 1
	! make && _messageFAIL 'FAIL: make' && _stop 1
	
	export LIBUSB1_CFLAGS="-I$LIBUSB_DIR/libusb/"
	export LIBUSB1_LIBS="-L$LIBUSB_DIR/libusb/.libs/ -lusb-1.0 -lpthread"

	export LIBUSB_1_0_CFLAGS="-I$LIBUSB_DIR/libusb/"
	export LIBUSB_1_0_LIBS="-L$LIBUSB_DIR/libusb/.libs/ -lusb-1.0 -lpthread"
	
	## LibUSB-Compat
	_messageNormal 'BUILD: LibUSB-Compat'
	cd "$safeTmp"/build/libusb-compat-0.1_git
	export LIBUSB0_DIR=`pwd`
	! autoreconf && _messageFAIL 'FAIL: autoreconf' && _stop 1
	! ./configure --enable-static --disable-shared && _messageFAIL 'FAIL: configure' && _stop 1
	! make clean && _messageFAIL 'FAIL: make clean' && _stop 1
	! make && _messageFAIL 'FAIL: make' && _stop 1
	
	export libusb_CFLAGS="-I$LIBUSB_DIR/libusb/"
	export libusb_LIBS="-L$LIBUSB_DIR/libusb/.libs/ -lusb-1.0 -lpthread"
	export libudev_CFLAGS="-I$UDEV_DIR/src/libudev/"
	export libudev_LIBS="-L$UDEV_DIR/src/libudev/.libs/ -ludev"
	
	## HIDAPI
	_messageNormal 'BUILD: HIDAPI'
	cd "$safeTmp"/build/hidapi
	! ./bootstrap && _messageFAIL 'FAIL: bootstrap' && _stop 1
	export HIDAPI_DIR=`pwd`
	./configure --enable-static --disable-shared
	make clean
	make -j4
	
	
	## PRODUCT - OpenOCD
	_messageNormal 'BUILD: Product: Complete'
	cd "$safeTmp"/build/openocd-code
	! ./bootstrap && _messageFAIL 'FAIL: bootstrap' && _stop 1
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
	! PKG_CONFIG_PATH=`pwd` ./configure --disable-werror --prefix="$scriptAbsoluteFolder"/build && _messageFAIL 'FAIL: configure' && _stop 1
	! make clean && _messageFAIL 'FAIL: make clean' && _stop 1
	! CFLAGS=-static make && _messageFAIL 'FAIL: make' && _stop 1
	! make install && _messageFAIL 'FAIL: make install' && _stop 1

	
	
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
