# Makefile to build the LV-CAP NodeRED application

# Application version string. This is the EA Quality System version and must be incremented for every release.
APP_VER=0.0.6

# libraries needed
LIB= -lpthread

# put C++ compiler into C++0x mode
CXXFLAGS+= -std=c++0x -O2

# debugging and warnings
CPPFLAGS+=-g -Wall -Werror
LDFLAGS+=-g -Wall

# where we output documentation to
DOC_DIR=doxygen_output
# where to find Doxygen tag files
TAG_DIR=../tag

# we need to include rapidjson from the environment folder
CPPFLAGS+= -I../../../environment/rapidjson
# no library to link so no need to add to LDFLAGS
#LDFLAGS+= -L/lib/

# we need the LV-CAP shared header file
CPPFLAGS+= -I../LV_CAP_API_Constants

# LV-CAP library code (uses #include <LV-CAP/*.h>
CPPFLAGS+= -I../
LDFLAGS+= -L../LV-CAP/
# liblvcap depends on libmosquitto, list both here to get the correct order of linkage
LIB+= -llvcap -lmosquitto

# switch on secure MQTT connections
CPPFLAGS+= -DSECURE_MQTT_BROKER

# source, executable and object files
SRC=
OBJ=$(addsuffix .o,$(basename $(SRC)))
HDR=$(addsuffix .h,$(basename $(SRC)))
# program-wide header file
PROG_HDR=
EXEC=
# TLS certificate settings, edit for developer details
# set the country
TLS_C=US
# set the province
TLS_ST=California
# set the locality
TLS_L=Oakland
# organization name
TLS_O=IMConsulting
# org. Unit
TLS_OU=Principal

# extra header file dependencies
ALL_HDR=

# Application ID
# Values used to produce the image tag (length of these two combined must be less
# than 46 characters):
# Vendor Name as in section 4.1 of LV-CAP API document
VENDOR=imconsulting
# Application Name chosen as per section 4.1 of LV-CAP API document
APP_NAME=node-red

all: cert

# all objects depend on the public headers
%.o: %.cpp %.h $(ALL_HDR)

$(EXEC): $(OBJ)
	$(CXX) $(LDFLAGS) $(OBJ) $(LIB) -o $(EXEC)

.PHONY: clean doc tests

clean:
	rm -f $(OBJ)
	rm -f $(EXEC)

# include rules for TLS certificates
include ../LV-CAP/Makefile.tls.inc
# release rules
include ../LV-CAP/Makefile.rel.inc

install: all install-cert
	install -D $(EXEC) $(DESTDIR)/$(bindir)/$(EXEC)

.PHONY: install

dockerize: cert

	# Build the container usign the standard Dockerfile
	docker build . -t $(VENDOR)/$(APP_NAME):$(APP_VER)

	# Export the container to a compressed tar
	docker save $(VENDOR)/$(APP_NAME):$(APP_VER) | xz -z -6 --x86 --lzma2 --threads=0 > $(VENDOR)_$(APP_NAME)_00.tar

# The lines below this one provide automation for releasing this item
# from EA Technology SVN.

# target to package this up for release
# see the tar documentation https://www.gnu.org/software/tar/manual/html_section/tar_52.html
# Using --transform to make the output archive contain a top-level directory which does
# not exist in the SVN repo structure.
$(relfile): Makefile cert
	-rm $@
	@# touch TLS files to avoid failures when unpacked, as the dependency rules may be stricter than are in force when this runs
	touch $(APID).csr
	touch $(APID).crt
	tar cvJf $@ -C ../ --show-transformed --transform='s,^,$(relname)/,' \
			--exclude=$(thisdir)/$(dwgname)-S*-V*.tar.xz \
			--exclude=LV-CAP/liblvcap.a --exclude=LV-CAP/doxygen_output \
			--exclude=*.o --exclude=*.h --exclude=*.cpp --exclude=*~ --exclude=*.d \
			LV-CAP/ $(thisdir)
