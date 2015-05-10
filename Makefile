
# We use the special PIPESTATUS which is bash only below.
SHELL := /bin/bash

COLORMAKETOOL = "../tools/colormake.pl"

INTSTYLE = ise
# INTSTYLE = silent

# Top Level
all: info syn tran map par trce bit

DEVICE ?= Digilent/Atlys
include boards/$(DEVICE)/Makefile
BOARD_SPEC=$(BOARD_MAKER)-$(BOARD_MODEL)-$(BOARD_REVISION)

# Directory we'll put the output files in
BUILD_DIR=build
$(BUILD_DIR):
	mkdir $@

info:
	@echo ""
	@echo "========================================================="
	@echo " Board Details"
	@echo "---------------------------------------------------------"
	@echo "       Maker: $(BOARD_MAKER)"
	@echo "       Model: $(BOARD_MODEL)"
	@echo "         Rev: $(BOARD_REVISION)"
	@echo ""
	@echo " Board's FPGA Details"
	@echo "---------------------------------------------------------"
	@echo "        Type: $(FPGA_TYPE)"
	@echo " Speed Grade: $(FPGA_SPEED)"
	@echo "        Part: $(FPGA_PART)"
	@echo "========================================================="
	@echo ""

syn:
	@echo "========================================================="
	@echo "                       Synthesizing                      "
	@echo "========================================================="
	@mkdir -p $(BUILD_DIR)
	@cd $(BUILD_DIR); \
	xst \
	-intstyle $(INTSTYLE) \
	-filter "../ise/iseconfig/filter.filter" \
	-ifn "../ise/hdmi2usb.xst" \
	-ofn "hdmi2usb.syr" \
        | $(COLORMAKETOOL); (exit $${PIPESTATUS[0]})
	
tran:
	@echo "========================================================="
	@echo "                        Translate                        "
	@echo "========================================================="	
	@cd $(BUILD_DIR); \
	ngdbuild \
	-filter "../ise/iseconfig/filter.filter" \
	-intstyle $(INTSTYLE) \
	-dd _ngo \
	-sd ../ipcore_dir \
	-nt timestamp \
	-uc ../ucf/$(BOARD_SPEC).ucf \
	-p $(FPGA_PART) \
        hdmi2usb.ngc hdmi2usb.ngd \
        | $(COLORMAKETOOL); (exit $${PIPESTATUS[0]})

map:
	@echo "========================================================="
	@echo "                          Map                            "
	@echo "========================================================="
	@cd $(BUILD_DIR); \
	map \
	-filter "../ise/iseconfig/filter.filter" \
	-intstyle $(INTSTYLE) \
	-p $(FPGA_PART) \
	-w -logic_opt off \
	-ol high \
	-xe n \
	-t 1 \
	-xt 0 \
	-register_duplication off \
	-r 4 \
	-global_opt off \
	-mt off -ir off \
	-pr b -lc off \
	-power off \
	-detail \
	-o hdmi2usb_map.ncd hdmi2usb.ngd hdmi2usb.pcf \
        | $(COLORMAKETOOL); (exit $${PIPESTATUS[0]})

par:
	@echo "========================================================="
	@echo "                     Place & Route                       "
	@echo "========================================================="
	@cd $(BUILD_DIR); \
	par \
	-filter "../ise/iseconfig/filter.filter" -w \
	-intstyle $(INTSTYLE) \
	-ol high \
	-xe n \
	-mt off hdmi2usb_map.ncd hdmi2usb.ncd hdmi2usb.pcf \
        | $(COLORMAKETOOL); (exit $${PIPESTATUS[0]})

trce:
	@echo "========================================================="
	@echo "                        Trace                            "
	@echo "========================================================="
	@cd $(BUILD_DIR); \
	trce \
	-filter "../ise/iseconfig/filter.filter" \
	-intstyle $(INTSTYLE) \
	-s $(FPGA_SPEED) \
	-v 10 \
	-n 10 \
	-fastpaths \
	-xml hdmi2usb.twx hdmi2usb.ncd \
	-o hdmi2usb.twr hdmi2usb.pcf \
        | $(COLORMAKETOOL); (exit $${PIPESTATUS[0]})

# -v / -n are limits on detailed output

bit:
	@echo "========================================================="
	@echo "                        Bitgen                           "
	@echo "========================================================="
	@cd $(BUILD_DIR); \
	bitgen \
	-filter "../ise/iseconfig/filter.filter" \
	-intstyle $(INTSTYLE) \
	-f ../ise/hdmi2usb.ut hdmi2usb.ncd \
        | $(COLORMAKETOOL); (exit $${PIPESTATUS[0]})

xsvf:
	@echo "========================================================="
	@echo "                        xsvf file                        "
	@echo "========================================================="
	@cd $(BUILD_DIR); \
	impact -batch ../ucf/hdmi2usb.batch \
        | $(COLORMAKETOOL); (exit $${PIPESTATUS[0]})

clean:
	rm -R $(BUILD_DIR) || true

