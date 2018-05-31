# Makefile to build the LV-CAP NodeRED application

# Application version string. This is the EA Quality System version and must be incremented for every release.
APP_VER=1.0.0

# EATL drawing number
dwg=2756

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

# Application ID
# Values used to produce the image tag (length of these two combined must be less
# than 46 characters):
# Vendor Name as in section 4.1 of LV-CAP API document
VENDOR=imconsulting
# Application Name chosen as per section 4.1 of LV-CAP API document
APP_NAME=node-red

all: certifcates

# include rules for TLS certificates
include ../LV-CAP/Makefile.tls.inc
# release rules
include ../LV-CAP/Makefile.rel.inc

certifcates: cert
# Copy the cert files to necessary location
ifeq ($(strand),development)
		cp $(APID).key dev/
		cp $(APID).crt dev/
else
		cp $(APID).key prod/
		cp $(APID).crt prod/
endif

.PHONY: clean

clean:
	rm -f $(OBJ)
	rm -f $(EXEC)
	rm -f dev/*
	rm -f prod/*

dockerize: certifcates

	# Build the container usign the standard Dockerfile
	docker build . -t $(VENDOR)/$(APP_NAME):$(APP_VER)

	# Export the container to a compressed tar
	docker save $(VENDOR)/$(APP_NAME):$(APP_VER) | xz -z -6 --x86 --lzma2 --threads=0 > $(APID)_$(APP_VER)-$(strand).tar

# The #include of ../LV-CAP/Makefile.rel.inc sets up the rules to make .zip release file of the
# binary and sample configuration file. We just have to point the release target correctly
# because some Applications point that at something else.
release: $(relname).zip

.PHONY: release
