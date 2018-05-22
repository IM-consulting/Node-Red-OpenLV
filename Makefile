# Makefile to build the LV-CAP TLS development tools

# EATL drawing name
dwgname=2746-SWREL
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
	-rm *~

# output directory name
relname=$(dwgname)-S0$(sheetten)1-V$(APP_VER)-$(strand)_LVCAP_TLS_devtools

# include rules for TLS certificates
include ../LV-CAP/Makefile.tls.inc
# release rules
include ../LV-CAP/Makefile.rel.inc


# when asked for docs, see if the generated index is up to date
doc: $(DOC_DIR)/html/index.html

# doxygen needs a number of environment variables which are referenced in
# the Doxyfile
export DOC_DIR ALL_HDR TAG_DIR TAGS

# to make that file, run Doxygen on the sources if they have changed
# before doing so, delete all the old files, otherwise the doxygen tree tends
# to grow forever with auto-named files
$(DOC_DIR)/html/index.html: $(SRC) $(ALL_HDR) $(HDR) Doxyfile
	\rm -f $(DOC_DIR)/html/*
	doxygen Doxyfile

# Install the program, where to install controlled from the environment
# DESTDIR is the install root to copy to (blank for /)
# bindir is the directory where binaries should be put (/usr/bin)
bindir=/usr/local/bin
# sysconfdir is the system configuration directory (/etc)
sysconfdir=/etc
# Home directory used by LV-CAP
cmhome=/home/CM


install: all install-cert 
	install -D $(EXEC) $(DESTDIR)/$(bindir)/$(EXEC)

.PHONY: install

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


# Some useful MQTT targets to avoid having to remember command lines
#====================================================================
mqtt_host:=marketplace
mqtt_port:=8883
sub_opts=$(mqtt_opts) --tls-version tlsv1.2

.PHONY: sub-all sub-sensor sub-alg pub-sense sub-tcp sub-volts sub-amps-bar

sub-all: cert
	@echo "Subscribing to all MQTT broker messages, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v -t '#'

# subscribe to the Sensor Data API section 8.3
sub-sensor: cert
	@echo "Subscribing to MQTT broker sensor messages, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v -t 'sensor/data/#'

# subscribe to the Modbus TCP Sensor Data output
sub-tcp: cert
	@echo "Subscribing to MQTT broker TCP sensor output, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v -t 'sensor/data/eatl_modbustcp_00/#'

# subscribe to the GridKey voltage Sensor Data output
sub-volts: cert
	@echo "Subscribing to MQTT broker GridKey voltage output, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v -t 'sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/busbar/l1/voltage-mean' -t sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/busbar/l2/voltage-mean -t sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/busbar/l3/voltage-mean

# subscribe to the GridKey calculated busbar current Sensor Data output
sub-amps-bar: cert
	@echo "Subscribing to calculated busbar current, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v -t 'sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/busbar/l1/current-mean' -t sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/busbar/l2/current-mean -t sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/busbar/l3/current-mean

# subscribe to the GridKey measured feeder 1 current Sensor Data output
sub-amps-f1: cert
	@echo "Subscribing to measured feeder 1 current, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v -t 'sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/feeder/1/l1/current-mean' -t sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/feeder/1/l2/current-mean -t sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/feeder/1/l3/current-mean

# subscribe to the GridKey measured feeder N current Sensor Data output
sub-amps-f%: fnum=$(subst sub-amps-f,,$@)
sub-amps-f%: cert
	@echo "Subscribing to measured feeder $(fnum) current, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v -t 'sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/feeder/$(fnum)/l1/current-mean' -t sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/feeder/$(fnum)/l2/current-mean -t sensor/data/96d6f19b-7022-45f2-b753-cb5012626b4d/gridkey-mcu520/60/feeder/$(fnum)/l3/current-mean


# subscribe to the Algorithm Data API section 8.4
sub-alg: cert
	@echo "Subscribing to MQTT broker sensor messages, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v -t 'algorithm/data/#'

# subscribe to the Data Upload API section 8.5
sub-upload: cert
	@echo "Subscribing to MQTT broker data upload messages, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v -t 'storage/request/newdata/#' -t 'storage/response/newdata/#' -t 'storage/uploaded/#'

# subscribe to all storage traffic
sub-storage: cert
	@echo "Subscribing to MQTT broker data storage traffic, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v -t 'storage/#'

# subscribe to errors
sub-err: cert
	@echo "Subscribing to MQTT broker error traffic, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v -t 'storage/data/error/#'


# publish sensor data (API 8.3) for testing
pub-sense: cert
	mosquitto_pub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -t 'sensor/data/eatl_modbustcp_00/outside_temperature' -m '{"Timestamp":1501770898,"Value":2.5,"Valid":true}'

# publish algorithm data (API 8.4) for testing

# what algorithm to publish as
pub_IID:=96d6f19b-7022-45f2-b753-cb5012626b4d
# set whether data should be stored
tostore:=true
# timestamp to use for output
ts:=$(shell date -u "+%s")
pub-alg: cert
	mosquitto_pub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -t 'algorithm/data/$(pub_IID)/gridkey-mcu520/60/busbar/l1/voltage-mean' -m '{"Timestamp":$(ts),"Value":240.0,"Valid":true, "ToStore":$(tostore)}'
	mosquitto_pub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -t 'algorithm/data/$(pub_IID)/gridkey-mcu520/60/busbar/l2/voltage-mean' -m '{"Timestamp":$(ts),"Value":241.0,"Valid":true, "ToStore":$(tostore)}'
	mosquitto_pub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -t 'algorithm/data/$(pub_IID)/gridkey-mcu520/60/busbar/l3/voltage-mean' -m '{"Timestamp":$(ts),"Value":239.0,"Valid":true, "ToStore":$(tostore)}'


# Targets for testing Load Profile Application (2662)

# publish outdoor temperature sensor data
#pub-test-outdoor: cert
pubscript=play_csv.py
pub-test-csv: cert
	./$(pubscript) --host $(mqtt_host) --port $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -i transformer2_2017-08-04.csv


# Targets for testing Modbus RTU Sensor Application (2404) ALVIN support
# See 2404-TSTDC-S001
# 10 second data
sub-alvin-load: cert
	@echo "Subscribing to ALVIN load data, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/busbar_voltage' \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/cable_voltage' \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/load_current' \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/reactive_power' \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/active_power'

# 60 second data
sub-alvin-status: cert
	@echo "Subscribing to ALVIN status data, press CTRL+C to disconnect"
	-mosquitto_sub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -v \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/open_operations' \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/close_operations' \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/watchdog_count' \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/cpu_temperature' \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/uptime' \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/switch_temperature' \
		-t 'sensor/data/eatl_sensorcontainer_00/feeder1/+/fault_flags'

# publish open and close commands, pretend to be LoadSense
# control topic base
mesh_topic:=algorithm/data/openlv_meshctl_00/control
pub-mesh-open-l1: cert
	mosquitto_pub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -t '$(mesh_topic)/l1' -m '{"Timestamp":$(ts),"Value":false,"Valid":true, "ToStore":$(tostore)}'

pub-mesh-open-l2: cert
	mosquitto_pub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -t '$(mesh_topic)/l2' -m '{"Timestamp":$(ts),"Value":false,"Valid":true, "ToStore":$(tostore)}'

pub-mesh-open-l3: cert
	mosquitto_pub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -t '$(mesh_topic)/l3' -m '{"Timestamp":$(ts),"Value":false,"Valid":true, "ToStore":$(tostore)}'

pub-mesh-close-l1: cert
	mosquitto_pub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -t '$(mesh_topic)/l1' -m '{"Timestamp":$(ts),"Value":true,"Valid":true, "ToStore":$(tostore)}'

pub-mesh-close-l2: cert
	mosquitto_pub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -t '$(mesh_topic)/l2' -m '{"Timestamp":$(ts),"Value":true,"Valid":true, "ToStore":$(tostore)}'

pub-mesh-close-l3: cert
	mosquitto_pub $(sub_opts) -h $(mqtt_host) -p $(mqtt_port) --cafile $(ROOT_CA) --cert $(APID).crt --key $(APID).key -t '$(mesh_topic)/l3' -m '{"Timestamp":$(ts),"Value":true,"Valid":true, "ToStore":$(tostore)}'


