# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5

PYTHON_COMPAT=( python2_7 )
WANT_AUTOCONF="2.1"

inherit eutils gnome2 multilib python-single-r1 versionator wxwidgets autotools

MY_PM=${PN}$(get_version_component_range 1-2 ${PV})
MY_PM=${MY_PM/.}
MY_P=${P/_rc/RC}

DESCRIPTION="A free GIS with raster and vector functionality, as well as 3D vizualization"
HOMEPAGE="http://grass.osgeo.org/"
SRC_URI="http://grass.osgeo.org/${MY_PM}/source/${MY_P}.tar.gz"

LICENSE="GPL-2"
SLOT="7"
KEYWORDS="~amd64 ~ppc ~ppc64 ~x86"
IUSE="X cairo cxx fftw gdal geos blas lapack regex mysql netcdf nls odbc opencl opengl openmp png postgres readline sqlite threads tiff truetype wxwidgets"

RDEPEND="
	>=app-admin/eselect-1.2
	sci-libs/proj
	sys-libs/gdbm
	sys-libs/ncurses:0=
	sys-libs/zlib
	cairo? ( x11-libs/cairo[X?,opengl?] )
	fftw? ( sci-libs/fftw:3.0 )
	geos? ( sci-libs/geos )
	gdal? ( sci-libs/gdal )
	blas? ( virtual/blas )
	lapack? ( virtual/lapack )
	mysql? ( virtual/mysql )
	netcdf? ( sci-libs/netcdf )
	odbc? ( dev-db/unixODBC )
	opencl? ( virtual/opencl )
	opengl? ( virtual/opengl )
	png? ( media-libs/libpng:0= )
	postgres? ( >=dev-db/postgresql-8.4:= )
	readline? ( sys-libs/readline:0= )
	sqlite? ( dev-db/sqlite:3 )
	tiff? ( media-libs/tiff:0= )
	truetype? ( media-libs/freetype:2 )
	wxwidgets? ( >=dev-python/wxpython-2.8.10.1:2.8[cairo,opengl?] )
	X? (
		x11-libs/libICE
		x11-libs/libSM
		x11-libs/libX11
		x11-libs/libXaw
		x11-libs/libXext
		x11-libs/libXmu
		x11-libs/libXp
		x11-libs/libXpm
		x11-libs/libXt
	)"

DEPEND="${RDEPEND}
	virtual/pkgconfig
	sys-devel/flex
	sys-devel/gettext
	sys-devel/bison
	wxwidgets? ( dev-lang/swig )
	X? (
		x11-proto/xextproto
		x11-proto/xproto
	)"

S="${WORKDIR}/${MY_P}"

REQUIRED_USE="
	opengl? ( X )
	wxwidgets? ( X )
"

pkg_setup() {
	if use lapack; then
		local mylapack
		mylapack=$(eselect lapack show) || die
		if [[ -z "${mylapack/.*reference.*/}" ]] && \
			[[ -z "${mylapack/.*atlas.*/}" ]]; then
			ewarn "You need to set lapack to atlas or reference. Do:"
			ewarn "   eselect lapack set <impl>"
			ewarn "where <impl> is atlas, threaded-atlas or reference"
			die "setup failed"
		fi
	fi

	if use blas; then
		local myblas
		myblas=$(eselect blas show) || die
		if [[ -z "${myblas/.*reference.*/}" ]] && \
			[[ -z "${myblas/.*atlas.*/}" ]]; then
			ewarn "You need to set blas to atlas or reference. Do:"
			ewarn "   eselect blas set <impl>"
			ewarn "where <impl> is atlas, threaded-atlas or reference"
			die "setup failed"
		fi
	fi

	python-single-r1_pkg_setup
}

src_prepare() {
	# Fix undefined reference to errno in lib/raster/open.c
	# see http://trac.osgeo.org/grass/changeset/66398
	epatch "${FILESDIR}/${P}-include-errno.patch"

	# Fix undeclared variable if OSG is disabled
	epatch "${FILESDIR}/${P}-declare-inespg.patch"

	epatch_user
	eautoconf
}

src_configure() {
	if use wxwidgets; then
		WX_BUILD=yes
		WX_GTK_VER=2.8
		need-wxwidgets unicode
	fi

	econf \
		--enable-shared \
		--disable-w11 \
		$(use_with cxx) \
		$(use_with tiff) \
		$(use_with png) \
		$(use_with postgres) \
		$(use_with mysql) \
		$(use_with mysql mysql-includes "${ROOT}usr/include/mysql") \
		$(use_with mysql mysql-libs "${ROOT}usr/$(get_libdir)/mysql") \
		$(use_with sqlite) \
		$(use_with opengl) \
		$(use_with odbc) \
		$(use_with fftw) \
		$(use_with blas) \
		$(use_with lapack) \
		$(use_with cairo) \
		$(use_with truetype freetype) \
		$(use_with truetype freetype-includes "${ROOT}usr/include/freetype2") \
		$(use_with nls) \
		$(use_with readline) \
		--without-opendwg \
		$(use_with regex) \
		$(use_with threads pthread) \
		$(use_with openmp) \
		$(use_with opencl) \
		$(use_with gdal gdal "${ROOT}usr/bin/gdal-config") \
		--without-liblas \
		$(use_with wxwidgets wxwidgets "${WX_CONFIG}") \
		$(use_with netcdf netcdf "${ROOT}usr/bin/nc-config") \
		$(use_with geos geos "${ROOT}usr/bin/geos-config") \
		--with-proj-includes="${ROOT}usr/include/libprojectM" \
		--with-proj-libs="${ROOT}usr/$(get_libdir)" \
		--with-proj-share="${ROOT}usr/share/proj/" \
		$(use_with X x)
}

src_compile() {
	# we don't want to link against embedded mysql lib
	emake MYSQLDLIB=""
}

src_install() {
	emake DESTDIR="${D}" \
		INST_DIR="${D}"/usr/${MY_PM} \
		prefix="${D}"/usr BINDIR="${D}"/usr/bin \
		PREFIX="${D}"/usr/ \
		install

	pushd "${D}"/usr/${MY_PM} &> /dev/null

	# fix docs
	dodoc AUTHORS CHANGES
	dohtml -r docs/html/*
	rm -rf docs/ || die
	rm -rf {AUTHORS,CHANGES,COPYING,GPL.TXT,REQUIREMENTS.html} || die

	# manuals
	dodir /usr/share/man/man1
	rm -rf man/ || die

	# translations
	if use nls; then
		dodir /usr/share/locale/
		mv locale/* "${D}"/usr/share/locale/ || die
		rm -rf locale/ || die
		# pt_BR is broken
		mv "${D}"/usr/share/locale/pt_br "${D}"/usr/share/locale/pt_BR || die
	fi

	popd &> /dev/null

	# place libraries where they belong
	mv "${D}"/usr/${MY_PM}/lib/ "${D}"/usr/$(get_libdir)/ || die

	# place header files where they belong
	mv "${D}"/usr/${MY_PM}/include/ "${D}"/usr/include/ || die
	# make rules are not required on installed system
	rm -rf "${D}"/usr/include/Make || die

	# mv remaining gisbase stuff to libdir
	mv "${D}"/usr/${MY_PM} "${D}"/usr/$(get_libdir) || die

	# get proper folder for grass path in script
	sed -i \
		-e "1,\$s:^GISBASE.*:GISBASE=/usr/$(get_libdir)/${MY_PM}:" \
		"${D}"usr/bin/${MY_PM} || die

	# get proper fonts path for fontcap
	sed -i \
		-e "s|${D}/usr/${MY_PM}|${EPREFIX}usr/$(get_libdir)/${MY_PM}|" \
		"${D}"/usr/$(get_libdir)/${MY_PM}/etc/fontcap || die

	if use X; then
		local GUI="-gui"
		[[ ${WX_BUILD} == yes ]] && GUI="-wxpython"
		make_desktop_entry "/usr/bin/${MY_PM} ${GUI}" "${PN}" "${PN}-48x48" "Science;Education"
		doicon gui/icons/${PN}-48x48.png
	fi

	# install .pc file so other apps know where to look for grass
	insinto /usr/$(get_libdir)/pkgconfig/
	doins grass.pc

	# fix weird +x on tcl scripts
	find "${D}" -name "*.tcl" -exec chmod +r-x '{}' \;
}

pkg_postinst() {
	if use X; then
		fdo-mime_desktop_database_update
		gnome2_icon_cache_update
	fi
}

pkg_postrm() {
	if use X; then
		fdo-mime_desktop_database_update
		gnome2_icon_cache_update
	fi
}
