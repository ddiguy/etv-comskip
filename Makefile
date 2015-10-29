NAME=ETVComskip
VERSION=3.1
# El Capitan (10.11)
OsVersion=$(shell python -c 'import platform,sys;x=platform.mac_ver()[0].split(".");sys.stdout.write("%s.%s" % (x[0],x[1]))')
IMGNAME=${NAME}-${VERSION}-${OsVersion}
SUMMARY="Version ${VERSION} for EyeTV3 for ${OsVersion}"

DLDIR=~/Downloads
PORT=/opt/local/bin/port
LOCALBIN=/opt/local/bin

all: xcode macports distdir MarkCommercials comskip ComSkipper EyeTVTriggers Install docs # dmg

upload::
	pushd ${DLDIR} && git clone https://github.com/essandess/etv-comskip.git && popd

xcode::
	# Install OS X Command Line Tools
	@if ! [ $(shell xcode-select -p 1>&2 2> /dev/null; echo $$?) -eq '0' ]; \
	then \
		echo 'Please install Xcode Command Line Tools as a sudoer...'; \
		sudo /usr/bin/xcode-select --install; \
		sudo /usr/bin/xcodebuild -license; \
	else \
		echo "Xcode Command Line Tools found in $(shell xcode-select -p)."; \
	fi

macports:: xcode
	# Install MacPorts
	@if ! [ -x ${PORT} ]; \
	then \
		open -a Safari https://www.macports.org/install.php; \
		echo "Please download and install Macports from https://www.macports.org/install.php\n then run make again."; \
		exit 1; \
	else \
		echo "Macports executable found in ${PORT}."; \
	fi
	echo 'Please update and install the necessary Macports as a sudoer:'
	# sudo ${PORT} selfupdate
	# sudo ${PORT} upgrade outdated
	# sudo ${PORT} install python27 py-appscript py-py2app ffmpeg argtable mp4v2 coreutils
	# sudo ${PORT} select --set python python27
	# sudo ${PORT} uninstall ffmpeg-devel
	# sudo ${PORT} uninstall inactive
	[[ $(shell port -qv installed | egrep '^ +python27 .+(active)' 1>&2 2> /dev/null; echo $$?) -eq '0' ]] || ( sudo ${PORT} install python27 ; sudo ${PORT} select --set python python27 )
	[[ $(shell port -qv installed | egrep '^ +py-appscript .+(active)' 1>&2 2> /dev/null; echo $$?) -eq '0' ]] || sudo ${PORT} install py-appscript
	@# [[ $(shell port -qv installed | egrep '^ +py-py2app .+(active)' 1>&2 2> /dev/null; echo $$?) -eq '0' ]] || sudo ${PORT} install py-py2app
	[[ $(shell port -qv installed | egrep '^ +py-pip .+(active)' 1>&2 2> /dev/null; echo $$?) -eq '0' ]] || sudo ${PORT} install py-pip
	@# pyinstaller ; the python configure.py shouldn't be necessary
	-[[ $(shell pip freeze 2>/dev/null | grep -i pyinstaller | wc -l) -eq '0' ]] && \
		( sudo -H pip install pyinstaller ; \
		pushd `python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())"`/PyInstaller ; \
		sudo python -m PyInstaller configure.py ; \
		popd )
	-[[ $(shell port -qv installed | egrep '^ +ffmpeg-devel .+(active)' 1>&2 2> /dev/null; echo $$?) -eq '0' ]] && sudo ${PORT} uninstall ffmpeg-devel
	[[ $(shell port -qv installed | egrep '^ +ffmpeg .+(active)' 1>&2 2> /dev/null; echo $$?) -eq '0' ]] || sudo ${PORT} install ffmpeg +x11
	[[ $(shell port -qv installed | egrep '^ +argtable .+(active)' 1>&2 2> /dev/null; echo $$?) -eq '0' ]] || sudo ${PORT} install argtable
	[[ $(shell port -qv installed | egrep '^ +mp4v2 .+(active)' 1>&2 2> /dev/null; echo $$?) -eq '0' ]] || sudo ${PORT} install mp4v2
	[[ $(shell port -qv installed | egrep '^ +coreutils .+(active)' 1>&2 2> /dev/null; echo $$?) -eq '0' ]] || sudo ${PORT} install coreutils

distdir:: macports
	pushd ${DLDIR} && ( test -d ETVComskip && rm -fr ETVComskip ; mkdir ETVComskip ) && popd
	pushd ${DLDIR}/ETVComskip && ( test -d bin || mkdir bin ) && popd
	pushd ${DLDIR}/ETVComskip && ( test -d scripts || mkdir scripts ) && popd

dmg: distdir MarkCommercials comskip ComSkipper EyeTVTriggers Install docs
	pushd ${DLDIR}/ETVComskip; \
	rm *.dmg*; \
	hdiutil create -fs HFS+ -format UDBZ -volname ${IMGNAME} -srcfolder . ${IMGNAME}; \
	popd

comskip:: distdir MarkCommercials
	# comskip
	@# original Makefile make command
	@# pushd ./src/Comskip; make INCLUDES="-I/opt/local/include" LIBS="-L/opt/local/lib"; popd
	pushd ./src/Comskip; ./autogen.sh && ./configure && make; popd
	install -m 755 ./src/comskip/comskip ${DLDIR}/ETVComskip/bin
	install -m 755 ./src/comskip/comskip-gui ${DLDIR}/ETVComskip/bin
	# comskip.ini
	install -m 644 ./src/comskip_ini/comskip.ini ${DLDIR}/ETVComskip
	install -m 644 ./src/comskip_ini/comskip.ini.us_cabletv ${DLDIR}/ETVComskip

ComSkipper:: distdir
	-rm -rf src/scripts/ComSkipper/dist
	-rm -rf src/scripts/ComSkipper/build
	-rm -rf ETVComskip/bin/ComSkipper
	-rm -rf ETVComskip/ComSkipper.app
	@# pushd ./src/scripts/ComSkipper && /opt/local/bin/python setup.py py2app ; mv ./dist/ComSkipper.app ${DLDIR}/ETVComskip ; popd
	pushd ./src/scripts/ComSkipper && \
	`python -c "from distutils.sysconfig import get_python_lib; pibin = get_python_lib(); print pibin.split('/lib/python',1)[0] + '/bin/pyinstaller'"` --onefile --windowed --osx-bundle-identifier=com.github.essandess.etv-comskip ComSkipper.py && \
	mv ./dist/ComSkipper ${DLDIR}/ETVComskip/bin && \
	mv ./dist/ComSkipper.app ${DLDIR}/ETVComskip && \
	popd
	/usr/libexec/PlistBuddy -c "Set :LSBackgroundOnly integer 1" ${DLDIR}/ETVComskip/ComSkipper.app/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" ${DLDIR}/ETVComskip/ComSkipper.app/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :LSMultipleInstancesProhibited bool true" ${DLDIR}/ETVComskip/ComSkipper.app/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :LSUIPresentationMode integer 4" ${DLDIR}/ETVComskip/ComSkipper.app/Contents/Info.plist
 
MarkCommercials:: distdir
	-rm -rf src/scripts/MarkCommercials/dist
	-rm -rf src/scripts/MarkCommercials/build
	-rm -rf ETVComskip/MarkCommercials
	-rm -rf ETVComskip/MarkCommercials.app
	@# pushd ./src/scripts/MarkCommercials && /opt/local/bin/python setup.py py2app ; mv ./dist/MarkCommercials.app ${DLDIR}/ETVComskip ; popd
	pushd ./src/scripts/MarkCommercials && \
	`python -c "from distutils.sysconfig import get_python_lib; pibin = get_python_lib(); print pibin.split('/lib/python',1)[0] + '/bin/pyinstaller'"` --onefile --windowed --osx-bundle-identifier=com.github.essandess.etv-comskip MarkCommercials.py && \
	mv ./dist/MarkCommercials ${DLDIR}/ETVComskip/bin && \
	mv ./dist/MarkCommercials.app ${DLDIR}/ETVComskip && \
	popd
	/usr/libexec/PlistBuddy -c "Set :LSBackgroundOnly integer 1" ${DLDIR}/ETVComskip/MarkCommercials.app/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" ${DLDIR}/ETVComskip/MarkCommercials.app/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :LSMultipleInstancesProhibited bool true" ${DLDIR}/ETVComskip/MarkCommercials.app/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :LSUIPresentationMode integer 4" ${DLDIR}/ETVComskip/MarkCommercials.app/Contents/Info.plist
	pushd ./src/scripts && osacompile -do ${DLDIR}/ETVComskip/scripts/iTunesTVFolder.scpt ./iTunesTVFolder.applescript && popd

Install:: distdir
	pushd ./src/scripts && osacompile -o ${DLDIR}/ETVComskip/Install\ ETVComskip.app ./Install.applescript && popd
	pushd ./src/scripts && osacompile -o ${DLDIR}/ETVComskip/UnInstall\ ETVComskip.app ./UnInstall.applescript && popd

EyeTVTriggers:: distdir
	pushd ./src/scripts && osacompile -do ${DLDIR}/ETVComskip/scripts/RecordingStarted.scpt ./RecordingStarted.applescript && popd
	pushd ./src/scripts && osacompile -do ${DLDIR}/ETVComskip/scripts/RecordingDone.scpt ./RecordingDone.applescript && popd
	pushd ./src/scripts && osacompile -do ${DLDIR}/ETVComskip/scripts/ExportDone.scpt ./ExportDone.applescript && popd

docs::
	cp LICENSE LICENSE.rtf AUTHORS ${DLDIR}/ETVComskip

package:: distdir MarkCommercials comskip ComSkipper EyeTVTriggers Install docs
	rm -fr ${DLDIR}/ETVComskip/ETVComskip-1.0.0rc8.mpkg
	#/Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker --doc ETVComskip-$(VERSION).pmdoc --out ${DLDIR}/ETVComskip/ETVComskip-$(VERSION).mpkg -v -b
	pkgbuild --doc ETVComskip-$(VERSION).pmdoc --out ${DLDIR}/ETVComskip/ETVComskip-$(VERSION).mpkg -v -b

install::
	sudo cp -p ${DLDIR}/ETVComskip/scripts/RecordingStarted.scpt "/Library/Application Support/EyeTV/Scripts/TriggeredScripts"
	sudo cp -p ${DLDIR}/ETVComskip/scripts/RecordingDone.scpt "/Library/Application Support/EyeTV/Scripts/TriggeredScripts"
	sudo cp -p ${DLDIR}/ETVComskip/scripts/ExportDone.scpt "/Library/Application Support/EyeTV/Scripts/TriggeredScripts"
	-pushd "/Library/Application Support" && ( test -d ETVComskip.previous && sudo rm -fr ETVComskip.previous ) && popd
	-pushd "/Library/Application Support" && ( test -d ETVComskip && sudo mv ETVComskip ETVComskip.previous ) && popd
	sudo cp -Rfp ${DLDIR}/ETVComskip "/Library/Application Support"

uninstall::
	sudo rm -fr "/Library/Application Support/ETVComskip"
	sudo rm -fr "/Library/Application Support/EyeTV/Scripts/TriggeredScripts/RecordingStarted.scpt"
	sudo rm -fr "/Library/Application Support/EyeTV/Scripts/TriggeredScripts/RecordingDone.scpt"
	sudo rm -fr "/Library/Application Support/EyeTV/Scripts/TriggeredScripts/ExportDone.scpt"

clean::
	rm -fr ${DLDIR}/ETVComskip
	-rm -fr ./src/scripts/MarkCommercials/dist
	-rm -fr ./src/scripts/MarkCommercials/build
	-rm -fr ./src/scripts/ComSkipper/dist
	-rm -fr ./src/scripts/ComSkipper/build
	-pushd ./src/Comskip && make distclean && popd

