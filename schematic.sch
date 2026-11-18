# File saved with Nlview 7.7.1 2023-07-26 3bc4126617 VDI=43 GEI=38 GUI=JA:21.0 TLS
# 
# non-default properties - (restore without -noprops)
property -colorscheme classic
property attrcolor #000000
property attrfontsize 8
property autobundle 1
property backgroundcolor #ffffff
property boxcolor0 #000000
property boxcolor1 #000000
property boxcolor2 #000000
property boxinstcolor #000000
property boxpincolor #000000
property buscolor #008000
property closeenough 5
property createnetattrdsp 2048
property decorate 1
property elidetext 40
property fillcolor1 #ffffcc
property fillcolor2 #dfebf8
property fillcolor3 #f0f0f0
property gatecellname 2
property instattrmax 30
property instdrag 15
property instorder 1
property marksize 12
property maxfontsize 12
property maxzoom 5
property netcolor #19b400
property objecthighlight0 #ff00ff
property objecthighlight1 #ffff00
property objecthighlight2 #00ff00
property objecthighlight3 #0095ff
property objecthighlight4 #8000ff
property objecthighlight5 #ffc800
property objecthighlight7 #00ffff
property objecthighlight8 #ff00ff
property objecthighlight9 #ccccff
property objecthighlight10 #0ead00
property objecthighlight11 #cefc00
property objecthighlight12 #9e2dbe
property objecthighlight13 #ba6a29
property objecthighlight14 #fc0188
property objecthighlight15 #02f990
property objecthighlight16 #f1b0fb
property objecthighlight17 #fec004
property objecthighlight18 #149bff
property objecthighlight19 #eb591b
property overlaycolor #19b400
property pbuscolor #000000
property pbusnamecolor #000000
property pinattrmax 20
property pinorder 2
property pinpermute 0
property portcolor #000000
property portnamecolor #000000
property ripindexfontsize 4
property rippercolor #000000
property rubberbandcolor #000000
property rubberbandfontsize 12
property selectattr 0
property selectionappearance 2
property selectioncolor #0000ff
property sheetheight 44
property sheetwidth 68
property showmarks 1
property shownetname 0
property showpagenumbers 1
property showripindex 1
property timelimit 1
#
module new ethernet_frame_buffer work:ethernet_frame_buffer:NOFILE -nosplit
load symbol BUFG hdi_primitives BUF pin O output pin I input fillcolor 1
load symbol IBUF hdi_primitives BUF pin O output pin I input fillcolor 1
load symbol OBUF hdi_primitives BUF pin O output pin I input fillcolor 1
load symbol LUT2 hdi_primitives BOX pin O output.right pin I0 input.left pin I1 input.left fillcolor 1
load symbol LUT4 hdi_primitives BOX pin O output.right pin I0 input.left pin I1 input.left pin I2 input.left pin I3 input.left fillcolor 1
load symbol FDRE hdi_primitives GEN pin Q output.right pin C input.clk.left pin CE input.left pin D input.left pin R input.left fillcolor 1
load symbol RAMB18E1 hdi_primitives BOX pin CLKARDCLK input.left pin CLKBWRCLK input.left pin ENARDEN input.left pin ENBWREN input.left pin REGCEAREGCE input.left pin REGCEB input.left pin RSTRAMARSTRAM input.left pin RSTRAMB input.left pin RSTREGARSTREG input.left pin RSTREGB input.left pinBus DOADO output.right [15:0] pinBus DOBDO output.right [15:0] pinBus DOPADOP output.right [1:0] pinBus DOPBDOP output.right [1:0] pinBus ADDRARDADDR input.left [13:0] pinBus ADDRBWRADDR input.left [13:0] pinBus DIADI input.left [15:0] pinBus DIBDI input.left [15:0] pinBus DIPADIP input.left [1:0] pinBus DIPBDIP input.left [1:0] pinBus WEA input.left [1:0] pinBus WEBWE input.left [3:0] fillcolor 1
load symbol LUT3 hdi_primitives BOX pin O output.right pin I0 input.left pin I1 input.left pin I2 input.left fillcolor 1
load symbol LUT6 hdi_primitives BOX pin O output.right pin I0 input.left pin I1 input.left pin I2 input.left pin I3 input.left pin I4 input.left pin I5 input.left fillcolor 1
load symbol LUT5 hdi_primitives BOX pin O output.right pin I0 input.left pin I1 input.left pin I2 input.left pin I3 input.left pin I4 input.left fillcolor 1
load symbol CARRY4 hdi_primitives BOX pin CI input.left pin CYINIT input.left pinBus CO output.right [3:0] pinBus O output.right [3:0] pinBus DI input.left [3:0] pinBus S input.left [3:0] fillcolor 1
load port clk input -pg 1 -lvl 0 -x 0 -y 610
load port data_last input -pg 1 -lvl 0 -x 0 -y 470
load port data_valid input -pg 1 -lvl 0 -x 0 -y 700
load port frame_ack input -pg 1 -lvl 0 -x 0 -y 90
load port frame_ready output -pg 1 -lvl 17 -x 4760 -y 1300
load port overflow output -pg 1 -lvl 17 -x 4760 -y 1140
load port rst input -pg 1 -lvl 0 -x 0 -y 540
load portBus data_in input [7:0] -attr @name data_in[7:0] -pg 1 -lvl 0 -x 0 -y 2620
load portBus frame_size output [11:0] -attr @name frame_size[11:0] -pg 1 -lvl 17 -x 4760 -y 300
load portBus read_addr input [10:0] -attr @name read_addr[10:0] -pg 1 -lvl 0 -x 0 -y 3180
load portBus read_data output [7:0] -attr @name read_data[7:0] -pg 1 -lvl 17 -x 4760 -y 1880
load inst clk_IBUF_BUFG_inst BUFG hdi_primitives -attr @cell(#000000) BUFG -pg 1 -lvl 2 -x 310 -y 610
load inst clk_IBUF_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 1 -x 40 -y 610
load inst data_in_IBUF[0]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 2620
load inst data_in_IBUF[1]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 2690
load inst data_in_IBUF[2]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 2760
load inst data_in_IBUF[3]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 2830
load inst data_in_IBUF[4]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 2900
load inst data_in_IBUF[5]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 2970
load inst data_in_IBUF[6]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3040
load inst data_in_IBUF[7]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3110
load inst data_last_IBUF_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 1 -x 40 -y 470
load inst data_valid_IBUF_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 3 -x 580 -y 700
load inst frame_ack_IBUF_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 10 -x 2660 -y 160
load inst frame_ready_OBUF_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 1300
load inst frame_ready_OBUF_inst_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 15 -x 4190 -y 1290
load inst frame_size_OBUF[0]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 300
load inst frame_size_OBUF[10]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 1000
load inst frame_size_OBUF[11]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 1070
load inst frame_size_OBUF[1]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 370
load inst frame_size_OBUF[2]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 440
load inst frame_size_OBUF[3]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 510
load inst frame_size_OBUF[4]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 580
load inst frame_size_OBUF[5]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 650
load inst frame_size_OBUF[6]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 720
load inst frame_size_OBUF[7]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 790
load inst frame_size_OBUF[8]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 860
load inst frame_size_OBUF[9]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 930
load inst overflow_OBUF_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 1140
load inst overflow_reg_i_1 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 790
load inst overflow_reg_i_2 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 14 -x 3660 -y 920
load inst overflow_reg_reg FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 15 -x 4190 -y 910
load inst ram_reg RAMB18E1 hdi_primitives -attr @cell(#000000) RAMB18E1 -pinBusAttr DOADO @name DOADO[15:0] -pinBusAttr DOADO @attr n/c -pinBusAttr DOBDO @name DOBDO[15:0] -pinBusAttr DOPADOP @name DOPADOP[1:0] -pinBusAttr DOPADOP @attr n/c -pinBusAttr DOPBDOP @name DOPBDOP[1:0] -pinBusAttr DOPBDOP @attr n/c -pinBusAttr ADDRARDADDR @name ADDRARDADDR[13:0] -pinBusAttr ADDRBWRADDR @name ADDRBWRADDR[13:0] -pinBusAttr DIADI @name DIADI[15:0] -pinBusAttr DIBDI @name DIBDI[15:0] -pinBusAttr DIBDI @attr V=B\"0000000011111111\" -pinBusAttr DIPADIP @name DIPADIP[1:0] -pinBusAttr DIPBDIP @name DIPBDIP[1:0] -pinBusAttr WEA @name WEA[1:0] -pinBusAttr WEBWE @name WEBWE[3:0] -pg 1 -lvl 15 -x 4190 -y 2200
load inst ram_reg_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 14 -x 3660 -y 670
load inst ram_reg_i_10 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 2110
load inst ram_reg_i_11 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 2240
load inst ram_reg_i_12 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 2370
load inst ram_reg_i_13 LUT3 hdi_primitives -attr @cell(#000000) LUT3 -pg 1 -lvl 14 -x 3660 -y 2500
load inst ram_reg_i_2 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 1060
load inst ram_reg_i_3 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 1190
load inst ram_reg_i_4 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 1330
load inst ram_reg_i_5 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 1460
load inst ram_reg_i_6 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 1590
load inst ram_reg_i_7 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 1720
load inst ram_reg_i_8 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 1850
load inst ram_reg_i_9 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 14 -x 3660 -y 1980
load inst read_addr_IBUF[0]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3180
load inst read_addr_IBUF[10]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3880
load inst read_addr_IBUF[1]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3250
load inst read_addr_IBUF[2]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3320
load inst read_addr_IBUF[3]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3390
load inst read_addr_IBUF[4]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3460
load inst read_addr_IBUF[5]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3530
load inst read_addr_IBUF[6]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3600
load inst read_addr_IBUF[7]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3670
load inst read_addr_IBUF[8]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3740
load inst read_addr_IBUF[9]_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 14 -x 3660 -y 3810
load inst read_data_OBUF[0]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 1880
load inst read_data_OBUF[1]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 1950
load inst read_data_OBUF[2]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 2020
load inst read_data_OBUF[3]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 2090
load inst read_data_OBUF[4]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 2160
load inst read_data_OBUF[5]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 2230
load inst read_data_OBUF[6]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 2300
load inst read_data_OBUF[7]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 16 -x 4530 -y 2370
load inst rst_IBUF_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 1 -x 40 -y 540
load inst state[0]_i_1 LUT6 hdi_primitives -attr @cell(#000000) LUT6 -pg 1 -lvl 2 -x 310 -y 430
load inst state[1]_i_1 LUT5 hdi_primitives -attr @cell(#000000) LUT5 -pg 1 -lvl 12 -x 3180 -y 600
load inst state[1]_i_2 LUT6 hdi_primitives -attr @cell(#000000) LUT6 -pg 1 -lvl 11 -x 2980 -y 130
load inst state_reg[0] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 3 -x 580 -y 340
load inst state_reg[1] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 13 -x 3340 -y 640
load inst write_addr[0]_i_1 LUT3 hdi_primitives -attr @cell(#000000) LUT3 -pg 1 -lvl 4 -x 880 -y 140
load inst write_addr[10]_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 9 -x 2400 -y 510
load inst write_addr[11]_i_1 LUT4 hdi_primitives -attr @cell(#000000) LUT4 -pg 1 -lvl 4 -x 880 -y 670
load inst write_addr[11]_i_2 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 9 -x 2400 -y 660
load inst write_addr[1]_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 4 -x 880 -y 280
load inst write_addr[2]_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 4 -x 880 -y 370
load inst write_addr[3]_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 4 -x 880 -y 490
load inst write_addr[4]_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 4 -x 880 -y 580
load inst write_addr[5]_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 5 -x 1240 -y 1140
load inst write_addr[6]_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 5 -x 1240 -y 1290
load inst write_addr[7]_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 5 -x 1240 -y 1440
load inst write_addr[8]_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 5 -x 1240 -y 1530
load inst write_addr[9]_i_1 LUT2 hdi_primitives -attr @cell(#000000) LUT2 -pg 1 -lvl 9 -x 2400 -y 420
load inst write_addr_reg[0] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 5 -x 1240 -y 80
load inst write_addr_reg[10] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 10 -x 2660 -y 510
load inst write_addr_reg[11] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 10 -x 2660 -y 660
load inst write_addr_reg[11]_i_3 CARRY4 hdi_primitives -attr @cell(#000000) CARRY4 -pinBusAttr CO @name CO[3:0] -pinBusAttr O @name O[3:0] -pinBusAttr DI @name DI[3:0] -pinBusAttr S @name S[3:0] -pg 1 -lvl 8 -x 2130 -y 870
load inst write_addr_reg[1] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 5 -x 1240 -y 310
load inst write_addr_reg[2] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 5 -x 1240 -y 460
load inst write_addr_reg[3] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 5 -x 1240 -y 620
load inst write_addr_reg[4] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 5 -x 1240 -y 980
load inst write_addr_reg[4]_i_2 CARRY4 hdi_primitives -attr @cell(#000000) CARRY4 -pinBusAttr CO @name CO[3:0] -pinBusAttr O @name O[3:0] -pinBusAttr DI @name DI[3:0] -pinBusAttr S @name S[3:0] -pg 1 -lvl 6 -x 1540 -y 850
load inst write_addr_reg[5] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 6 -x 1540 -y 1140
load inst write_addr_reg[6] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 6 -x 1540 -y 1290
load inst write_addr_reg[7] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 6 -x 1540 -y 1440
load inst write_addr_reg[8] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 6 -x 1540 -y 1590
load inst write_addr_reg[8]_i_2 CARRY4 hdi_primitives -attr @cell(#000000) CARRY4 -pinBusAttr CO @name CO[3:0] -pinBusAttr O @name O[3:0] -pinBusAttr DI @name DI[3:0] -pinBusAttr S @name S[3:0] -pg 1 -lvl 7 -x 1840 -y 910
load inst write_addr_reg[9] FDRE hdi_primitives -attr @cell(#000000) FDRE -pg 1 -lvl 10 -x 2660 -y 360
load net <const0> -ground -pin ram_reg REGCEAREGCE -pin ram_reg REGCEB -pin ram_reg RSTRAMARSTRAM -pin ram_reg RSTRAMB -pin ram_reg RSTREGARSTREG -pin ram_reg RSTREGB -pin ram_reg DIADI[15] -pin ram_reg DIADI[14] -pin ram_reg DIADI[13] -pin ram_reg DIADI[12] -pin ram_reg DIADI[11] -pin ram_reg DIADI[10] -pin ram_reg DIADI[9] -pin ram_reg DIADI[8] -pin ram_reg DIBDI[15] -pin ram_reg DIBDI[14] -pin ram_reg DIBDI[13] -pin ram_reg DIBDI[12] -pin ram_reg DIBDI[11] -pin ram_reg DIBDI[10] -pin ram_reg DIBDI[9] -pin ram_reg DIBDI[8] -pin ram_reg DIPADIP[1] -pin ram_reg DIPADIP[0] -pin ram_reg DIPBDIP[1] -pin ram_reg DIPBDIP[0] -pin ram_reg WEBWE[3] -pin ram_reg WEBWE[2] -pin ram_reg WEBWE[1] -pin ram_reg WEBWE[0] -pin state_reg[0] R -pin state_reg[1] R -pin write_addr_reg[11]_i_3 CYINIT -pin write_addr_reg[11]_i_3 DI[3] -pin write_addr_reg[11]_i_3 DI[2] -pin write_addr_reg[11]_i_3 DI[1] -pin write_addr_reg[11]_i_3 DI[0] -pin write_addr_reg[11]_i_3 S[3] -pin write_addr_reg[4]_i_2 CI -pin write_addr_reg[4]_i_2 DI[3] -pin write_addr_reg[4]_i_2 DI[2] -pin write_addr_reg[4]_i_2 DI[1] -pin write_addr_reg[4]_i_2 DI[0] -pin write_addr_reg[8]_i_2 CYINIT -pin write_addr_reg[8]_i_2 DI[3] -pin write_addr_reg[8]_i_2 DI[2] -pin write_addr_reg[8]_i_2 DI[1] -pin write_addr_reg[8]_i_2 DI[0]
load net <const1> -power -pin ram_reg ENBWREN -pin ram_reg ADDRARDADDR[2] -pin ram_reg ADDRARDADDR[1] -pin ram_reg ADDRARDADDR[0] -pin ram_reg ADDRBWRADDR[2] -pin ram_reg ADDRBWRADDR[1] -pin ram_reg ADDRBWRADDR[0] -pin ram_reg DIBDI[7] -pin ram_reg DIBDI[6] -pin ram_reg DIBDI[5] -pin ram_reg DIBDI[4] -pin ram_reg DIBDI[3] -pin ram_reg DIBDI[2] -pin ram_reg DIBDI[1] -pin ram_reg DIBDI[0] -pin state_reg[0] CE -pin state_reg[1] CE
load net clk -port clk -pin clk_IBUF_inst I
netloc clk 1 0 1 NJ 610
load net clk_IBUF -pin clk_IBUF_BUFG_inst I -pin clk_IBUF_inst O
netloc clk_IBUF 1 1 1 NJ 610
load net clk_IBUF_BUFG -pin clk_IBUF_BUFG_inst O -pin overflow_reg_reg C -pin ram_reg CLKARDCLK -pin ram_reg CLKBWRCLK -pin state_reg[0] C -pin state_reg[1] C -pin write_addr_reg[0] C -pin write_addr_reg[10] C -pin write_addr_reg[11] C -pin write_addr_reg[1] C -pin write_addr_reg[2] C -pin write_addr_reg[3] C -pin write_addr_reg[4] C -pin write_addr_reg[5] C -pin write_addr_reg[6] C -pin write_addr_reg[7] C -pin write_addr_reg[8] C -pin write_addr_reg[9] C
netloc clk_IBUF_BUFG 1 2 13 500 460 NJ 460 1100 860 1400 980 1720J 840 NJ 840 NJ 840 2560 740 NJ 740 NJ 740 3280 760 3460J 640 3960
load net data_in[0] -attr @rip(#000000) data_in[0] -port data_in[0] -pin data_in_IBUF[0]_inst I
load net data_in[1] -attr @rip(#000000) data_in[1] -port data_in[1] -pin data_in_IBUF[1]_inst I
load net data_in[2] -attr @rip(#000000) data_in[2] -port data_in[2] -pin data_in_IBUF[2]_inst I
load net data_in[3] -attr @rip(#000000) data_in[3] -port data_in[3] -pin data_in_IBUF[3]_inst I
load net data_in[4] -attr @rip(#000000) data_in[4] -port data_in[4] -pin data_in_IBUF[4]_inst I
load net data_in[5] -attr @rip(#000000) data_in[5] -port data_in[5] -pin data_in_IBUF[5]_inst I
load net data_in[6] -attr @rip(#000000) data_in[6] -port data_in[6] -pin data_in_IBUF[6]_inst I
load net data_in[7] -attr @rip(#000000) data_in[7] -port data_in[7] -pin data_in_IBUF[7]_inst I
load net data_in_IBUF[0] -attr @rip(#000000) 0 -pin data_in_IBUF[0]_inst O -pin ram_reg DIADI[0]
load net data_in_IBUF[1] -attr @rip(#000000) 1 -pin data_in_IBUF[1]_inst O -pin ram_reg DIADI[1]
load net data_in_IBUF[2] -attr @rip(#000000) 2 -pin data_in_IBUF[2]_inst O -pin ram_reg DIADI[2]
load net data_in_IBUF[3] -attr @rip(#000000) 3 -pin data_in_IBUF[3]_inst O -pin ram_reg DIADI[3]
load net data_in_IBUF[4] -attr @rip(#000000) 4 -pin data_in_IBUF[4]_inst O -pin ram_reg DIADI[4]
load net data_in_IBUF[5] -attr @rip(#000000) 5 -pin data_in_IBUF[5]_inst O -pin ram_reg DIADI[5]
load net data_in_IBUF[6] -attr @rip(#000000) 6 -pin data_in_IBUF[6]_inst O -pin ram_reg DIADI[6]
load net data_in_IBUF[7] -attr @rip(#000000) 7 -pin data_in_IBUF[7]_inst O -pin ram_reg DIADI[7]
load net data_last -port data_last -pin data_last_IBUF_inst I
netloc data_last 1 0 1 NJ 470
load net data_last_IBUF -pin data_last_IBUF_inst O -pin state[0]_i_1 I2 -pin state[1]_i_1 I2 -pin state[1]_i_2 I4
netloc data_last_IBUF 1 1 11 210 110 NJ 110 NJ 110 1040J 180 1480J 210 NJ 210 NJ 210 NJ 210 NJ 210 2900 650 NJ
load net data_valid -port data_valid -pin data_valid_IBUF_inst I
netloc data_valid 1 0 3 NJ 700 NJ 700 NJ
load net data_valid_IBUF -pin data_valid_IBUF_inst O -pin overflow_reg_i_1 I1 -pin overflow_reg_i_2 I0 -pin ram_reg_i_1 I0 -pin state[1]_i_2 I5 -pin write_addr[0]_i_1 I1 -pin write_addr[11]_i_1 I1
netloc data_valid_IBUF 1 3 11 760 250 1160J 230 NJ 230 NJ 230 NJ 230 NJ 230 NJ 230 2880 350 NJ 350 NJ 350 3600
load net frame_ack -port frame_ack -pin frame_ack_IBUF_inst I
netloc frame_ack 1 0 10 NJ 90 NJ 90 NJ 90 NJ 90 1000J 160 NJ 160 NJ 160 NJ 160 NJ 160 NJ
load net frame_ack_IBUF -pin frame_ack_IBUF_inst O -pin state[1]_i_2 I1
netloc frame_ack_IBUF 1 10 1 NJ 160
load net frame_ready -port frame_ready -pin frame_ready_OBUF_inst O
netloc frame_ready 1 16 1 NJ 1300
load net frame_ready_OBUF -pin frame_ready_OBUF_inst I -pin frame_ready_OBUF_inst_i_1 O
netloc frame_ready_OBUF 1 15 1 NJ 1300
load net frame_size[0] -attr @rip(#000000) 0 -port frame_size[0] -pin frame_size_OBUF[0]_inst O
load net frame_size[10] -attr @rip(#000000) 10 -port frame_size[10] -pin frame_size_OBUF[10]_inst O
load net frame_size[11] -attr @rip(#000000) 11 -port frame_size[11] -pin frame_size_OBUF[11]_inst O
load net frame_size[1] -attr @rip(#000000) 1 -port frame_size[1] -pin frame_size_OBUF[1]_inst O
load net frame_size[2] -attr @rip(#000000) 2 -port frame_size[2] -pin frame_size_OBUF[2]_inst O
load net frame_size[3] -attr @rip(#000000) 3 -port frame_size[3] -pin frame_size_OBUF[3]_inst O
load net frame_size[4] -attr @rip(#000000) 4 -port frame_size[4] -pin frame_size_OBUF[4]_inst O
load net frame_size[5] -attr @rip(#000000) 5 -port frame_size[5] -pin frame_size_OBUF[5]_inst O
load net frame_size[6] -attr @rip(#000000) 6 -port frame_size[6] -pin frame_size_OBUF[6]_inst O
load net frame_size[7] -attr @rip(#000000) 7 -port frame_size[7] -pin frame_size_OBUF[7]_inst O
load net frame_size[8] -attr @rip(#000000) 8 -port frame_size[8] -pin frame_size_OBUF[8]_inst O
load net frame_size[9] -attr @rip(#000000) 9 -port frame_size[9] -pin frame_size_OBUF[9]_inst O
load net frame_size_OBUF[0] -pin frame_size_OBUF[0]_inst I -pin ram_reg_i_12 I1 -pin write_addr[0]_i_1 I0 -pin write_addr_reg[0] Q -pin write_addr_reg[4]_i_2 CYINIT
netloc frame_size_OBUF[0] 1 3 13 820 230 1000J 210 1460 820 NJ 820 NJ 820 NJ 820 NJ 820 2940J 800 3080J 760 3300J 740 3560 300 NJ 300 NJ
load net frame_size_OBUF[10] -attr @rip(#000000) 1 -pin frame_size_OBUF[10]_inst I -pin ram_reg_i_2 I1 -pin write_addr_reg[10] Q -pin write_addr_reg[11]_i_3 S[1]
load net frame_size_OBUF[11] -attr @rip(#000000) 2 -pin frame_size_OBUF[11]_inst I -pin overflow_reg_i_1 I2 -pin ram_reg_i_10 I0 -pin ram_reg_i_11 I0 -pin ram_reg_i_12 I0 -pin ram_reg_i_13 I0 -pin ram_reg_i_2 I0 -pin ram_reg_i_3 I0 -pin ram_reg_i_4 I0 -pin ram_reg_i_5 I0 -pin ram_reg_i_6 I0 -pin ram_reg_i_7 I0 -pin ram_reg_i_8 I0 -pin ram_reg_i_9 I0 -pin state[0]_i_1 I4 -pin state[1]_i_2 I0 -pin write_addr[11]_i_1 I2 -pin write_addr_reg[11] Q -pin write_addr_reg[11]_i_3 S[2]
load net frame_size_OBUF[1] -attr @rip(#000000) 0 -pin frame_size_OBUF[1]_inst I -pin ram_reg_i_11 I1 -pin write_addr_reg[1] Q -pin write_addr_reg[4]_i_2 S[0]
load net frame_size_OBUF[2] -attr @rip(#000000) 1 -pin frame_size_OBUF[2]_inst I -pin ram_reg_i_10 I1 -pin write_addr_reg[2] Q -pin write_addr_reg[4]_i_2 S[1]
load net frame_size_OBUF[3] -attr @rip(#000000) 2 -pin frame_size_OBUF[3]_inst I -pin ram_reg_i_9 I1 -pin write_addr_reg[3] Q -pin write_addr_reg[4]_i_2 S[2]
load net frame_size_OBUF[4] -attr @rip(#000000) 3 -pin frame_size_OBUF[4]_inst I -pin ram_reg_i_8 I1 -pin write_addr_reg[4] Q -pin write_addr_reg[4]_i_2 S[3]
load net frame_size_OBUF[5] -attr @rip(#000000) 0 -pin frame_size_OBUF[5]_inst I -pin ram_reg_i_7 I1 -pin write_addr_reg[5] Q -pin write_addr_reg[8]_i_2 S[0]
load net frame_size_OBUF[6] -attr @rip(#000000) 1 -pin frame_size_OBUF[6]_inst I -pin ram_reg_i_6 I1 -pin write_addr_reg[6] Q -pin write_addr_reg[8]_i_2 S[1]
load net frame_size_OBUF[7] -attr @rip(#000000) 2 -pin frame_size_OBUF[7]_inst I -pin ram_reg_i_5 I1 -pin write_addr_reg[7] Q -pin write_addr_reg[8]_i_2 S[2]
load net frame_size_OBUF[8] -attr @rip(#000000) 3 -pin frame_size_OBUF[8]_inst I -pin ram_reg_i_4 I1 -pin write_addr_reg[8] Q -pin write_addr_reg[8]_i_2 S[3]
load net frame_size_OBUF[9] -attr @rip(#000000) 0 -pin frame_size_OBUF[9]_inst I -pin ram_reg_i_3 I1 -pin write_addr_reg[11]_i_3 S[0] -pin write_addr_reg[9] Q
load net mem_waddr[0] -attr @rip(#000000) 3 -pin ram_reg ADDRARDADDR[3] -pin ram_reg_i_12 O
load net mem_waddr[10] -attr @rip(#000000) 13 -pin ram_reg ADDRARDADDR[13] -pin ram_reg_i_2 O
load net mem_waddr[1] -attr @rip(#000000) 4 -pin ram_reg ADDRARDADDR[4] -pin ram_reg_i_11 O
load net mem_waddr[2] -attr @rip(#000000) 5 -pin ram_reg ADDRARDADDR[5] -pin ram_reg_i_10 O
load net mem_waddr[3] -attr @rip(#000000) 6 -pin ram_reg ADDRARDADDR[6] -pin ram_reg_i_9 O
load net mem_waddr[4] -attr @rip(#000000) 7 -pin ram_reg ADDRARDADDR[7] -pin ram_reg_i_8 O
load net mem_waddr[5] -attr @rip(#000000) 8 -pin ram_reg ADDRARDADDR[8] -pin ram_reg_i_7 O
load net mem_waddr[6] -attr @rip(#000000) 9 -pin ram_reg ADDRARDADDR[9] -pin ram_reg_i_6 O
load net mem_waddr[7] -attr @rip(#000000) 10 -pin ram_reg ADDRARDADDR[10] -pin ram_reg_i_5 O
load net mem_waddr[8] -attr @rip(#000000) 11 -pin ram_reg ADDRARDADDR[11] -pin ram_reg_i_4 O
load net mem_waddr[9] -attr @rip(#000000) 12 -pin ram_reg ADDRARDADDR[12] -pin ram_reg_i_3 O
load net overflow -port overflow -pin overflow_OBUF_inst O
netloc overflow 1 16 1 NJ 1140
load net overflow_OBUF -pin overflow_OBUF_inst I -pin overflow_reg_reg Q
netloc overflow_OBUF 1 15 1 4450J 910n
load net overflow_reg_i_1_n_0 -pin overflow_reg_i_1 O -pin overflow_reg_reg CE
netloc overflow_reg_i_1_n_0 1 14 1 3920 820n
load net overflow_reg_i_2_n_0 -pin overflow_reg_i_2 O -pin overflow_reg_reg D
netloc overflow_reg_i_2_n_0 1 14 1 3860 920n
load net p_1_in[0] -pin write_addr[0]_i_1 O -pin write_addr_reg[0] D
netloc p_1_in[0] 1 4 1 1020 90n
load net p_6_in -pin ram_reg ENARDEN -pin ram_reg_i_1 O
netloc p_6_in 1 14 1 3900 680n
load net ram_reg_i_13_n_0 -pin ram_reg WEA[1] -pin ram_reg WEA[0] -pin ram_reg_i_13 O
netloc ram_reg_i_13_n_0 1 14 1 N 2530
load net read_addr[0] -attr @rip(#000000) read_addr[0] -port read_addr[0] -pin read_addr_IBUF[0]_inst I
load net read_addr[10] -attr @rip(#000000) read_addr[10] -port read_addr[10] -pin read_addr_IBUF[10]_inst I
load net read_addr[1] -attr @rip(#000000) read_addr[1] -port read_addr[1] -pin read_addr_IBUF[1]_inst I
load net read_addr[2] -attr @rip(#000000) read_addr[2] -port read_addr[2] -pin read_addr_IBUF[2]_inst I
load net read_addr[3] -attr @rip(#000000) read_addr[3] -port read_addr[3] -pin read_addr_IBUF[3]_inst I
load net read_addr[4] -attr @rip(#000000) read_addr[4] -port read_addr[4] -pin read_addr_IBUF[4]_inst I
load net read_addr[5] -attr @rip(#000000) read_addr[5] -port read_addr[5] -pin read_addr_IBUF[5]_inst I
load net read_addr[6] -attr @rip(#000000) read_addr[6] -port read_addr[6] -pin read_addr_IBUF[6]_inst I
load net read_addr[7] -attr @rip(#000000) read_addr[7] -port read_addr[7] -pin read_addr_IBUF[7]_inst I
load net read_addr[8] -attr @rip(#000000) read_addr[8] -port read_addr[8] -pin read_addr_IBUF[8]_inst I
load net read_addr[9] -attr @rip(#000000) read_addr[9] -port read_addr[9] -pin read_addr_IBUF[9]_inst I
load net read_addr_IBUF[0] -attr @rip(#000000) 3 -pin ram_reg ADDRBWRADDR[3] -pin read_addr_IBUF[0]_inst O
load net read_addr_IBUF[10] -attr @rip(#000000) 13 -pin ram_reg ADDRBWRADDR[13] -pin read_addr_IBUF[10]_inst O
load net read_addr_IBUF[1] -attr @rip(#000000) 4 -pin ram_reg ADDRBWRADDR[4] -pin read_addr_IBUF[1]_inst O
load net read_addr_IBUF[2] -attr @rip(#000000) 5 -pin ram_reg ADDRBWRADDR[5] -pin read_addr_IBUF[2]_inst O
load net read_addr_IBUF[3] -attr @rip(#000000) 6 -pin ram_reg ADDRBWRADDR[6] -pin read_addr_IBUF[3]_inst O
load net read_addr_IBUF[4] -attr @rip(#000000) 7 -pin ram_reg ADDRBWRADDR[7] -pin read_addr_IBUF[4]_inst O
load net read_addr_IBUF[5] -attr @rip(#000000) 8 -pin ram_reg ADDRBWRADDR[8] -pin read_addr_IBUF[5]_inst O
load net read_addr_IBUF[6] -attr @rip(#000000) 9 -pin ram_reg ADDRBWRADDR[9] -pin read_addr_IBUF[6]_inst O
load net read_addr_IBUF[7] -attr @rip(#000000) 10 -pin ram_reg ADDRBWRADDR[10] -pin read_addr_IBUF[7]_inst O
load net read_addr_IBUF[8] -attr @rip(#000000) 11 -pin ram_reg ADDRBWRADDR[11] -pin read_addr_IBUF[8]_inst O
load net read_addr_IBUF[9] -attr @rip(#000000) 12 -pin ram_reg ADDRBWRADDR[12] -pin read_addr_IBUF[9]_inst O
load net read_data[0] -attr @rip(#000000) 0 -port read_data[0] -pin read_data_OBUF[0]_inst O
load net read_data[1] -attr @rip(#000000) 1 -port read_data[1] -pin read_data_OBUF[1]_inst O
load net read_data[2] -attr @rip(#000000) 2 -port read_data[2] -pin read_data_OBUF[2]_inst O
load net read_data[3] -attr @rip(#000000) 3 -port read_data[3] -pin read_data_OBUF[3]_inst O
load net read_data[4] -attr @rip(#000000) 4 -port read_data[4] -pin read_data_OBUF[4]_inst O
load net read_data[5] -attr @rip(#000000) 5 -port read_data[5] -pin read_data_OBUF[5]_inst O
load net read_data[6] -attr @rip(#000000) 6 -port read_data[6] -pin read_data_OBUF[6]_inst O
load net read_data[7] -attr @rip(#000000) 7 -port read_data[7] -pin read_data_OBUF[7]_inst O
load net read_data_OBUF[0] -attr @rip(#000000) DOBDO[0] -pin ram_reg DOBDO[0] -pin read_data_OBUF[0]_inst I
load net read_data_OBUF[1] -attr @rip(#000000) DOBDO[1] -pin ram_reg DOBDO[1] -pin read_data_OBUF[1]_inst I
load net read_data_OBUF[2] -attr @rip(#000000) DOBDO[2] -pin ram_reg DOBDO[2] -pin read_data_OBUF[2]_inst I
load net read_data_OBUF[3] -attr @rip(#000000) DOBDO[3] -pin ram_reg DOBDO[3] -pin read_data_OBUF[3]_inst I
load net read_data_OBUF[4] -attr @rip(#000000) DOBDO[4] -pin ram_reg DOBDO[4] -pin read_data_OBUF[4]_inst I
load net read_data_OBUF[5] -attr @rip(#000000) DOBDO[5] -pin ram_reg DOBDO[5] -pin read_data_OBUF[5]_inst I
load net read_data_OBUF[6] -attr @rip(#000000) DOBDO[6] -pin ram_reg DOBDO[6] -pin read_data_OBUF[6]_inst I
load net read_data_OBUF[7] -attr @rip(#000000) DOBDO[7] -pin ram_reg DOBDO[7] -pin read_data_OBUF[7]_inst I
load net rst -port rst -pin rst_IBUF_inst I
netloc rst 1 0 1 NJ 540
load net rst_IBUF -pin overflow_reg_reg R -pin ram_reg_i_1 I1 -pin rst_IBUF_inst O -pin state[0]_i_1 I5 -pin state[1]_i_1 I4 -pin write_addr_reg[0] R -pin write_addr_reg[10] R -pin write_addr_reg[11] R -pin write_addr_reg[1] R -pin write_addr_reg[2] R -pin write_addr_reg[3] R -pin write_addr_reg[4] R -pin write_addr_reg[5] R -pin write_addr_reg[6] R -pin write_addr_reg[7] R -pin write_addr_reg[8] R -pin write_addr_reg[9] R
netloc rst_IBUF 1 1 14 210 860 NJ 860 NJ 860 1060 880 1420 740 NJ 740 NJ 740 NJ 740 2540 780 NJ 780 3140 780 NJ 780 3580 740 3940
load net state[0]_i_1_n_0 -pin state[0]_i_1 O -pin state_reg[0] D
netloc state[0]_i_1_n_0 1 2 1 520 350n
load net state[1]_i_1_n_0 -pin state[1]_i_1 O -pin state_reg[1] D
netloc state[1]_i_1_n_0 1 12 1 N 650
load net state[1]_i_2_n_0 -pin state[0]_i_1 I1 -pin state[1]_i_1 I1 -pin state[1]_i_2 O
netloc state[1]_i_2_n_0 1 1 11 270 400 480J 440 NJ 440 1040J 540 NJ 540 NJ 540 NJ 540 2300J 390 2520J 280 NJ 280 3100
load net state_reg_n_0_[0] -pin frame_ready_OBUF_inst_i_1 I1 -pin overflow_reg_i_1 I0 -pin overflow_reg_i_2 I1 -pin ram_reg_i_10 I3 -pin ram_reg_i_11 I3 -pin ram_reg_i_12 I3 -pin ram_reg_i_13 I2 -pin ram_reg_i_2 I3 -pin ram_reg_i_3 I3 -pin ram_reg_i_4 I3 -pin ram_reg_i_5 I3 -pin ram_reg_i_6 I3 -pin ram_reg_i_7 I3 -pin ram_reg_i_8 I3 -pin ram_reg_i_9 I3 -pin state[0]_i_1 I0 -pin state[1]_i_1 I3 -pin state[1]_i_2 I2 -pin state_reg[0] Q -pin write_addr[0]_i_1 I2 -pin write_addr[10]_i_1 I0 -pin write_addr[11]_i_1 I0 -pin write_addr[11]_i_2 I0 -pin write_addr[1]_i_1 I0 -pin write_addr[2]_i_1 I0 -pin write_addr[3]_i_1 I0 -pin write_addr[4]_i_1 I0 -pin write_addr[5]_i_1 I0 -pin write_addr[6]_i_1 I0 -pin write_addr[7]_i_1 I0 -pin write_addr[8]_i_1 I0 -pin write_addr[9]_i_1 I0
netloc state_reg_n_0_[0] 1 1 14 230 660 NJ 660 800 780 1160 720 NJ 720 NJ 720 NJ 720 2320 760 NJ 760 2860 670 3100 800 NJ 800 3520 1030 3880
load net state_reg_n_0_[1] -pin frame_ready_OBUF_inst_i_1 I0 -pin overflow_reg_i_1 I3 -pin ram_reg_i_10 I2 -pin ram_reg_i_11 I2 -pin ram_reg_i_12 I2 -pin ram_reg_i_13 I1 -pin ram_reg_i_2 I2 -pin ram_reg_i_3 I2 -pin ram_reg_i_4 I2 -pin ram_reg_i_5 I2 -pin ram_reg_i_6 I2 -pin ram_reg_i_7 I2 -pin ram_reg_i_8 I2 -pin ram_reg_i_9 I2 -pin state[0]_i_1 I3 -pin state[1]_i_1 I0 -pin state[1]_i_2 I3 -pin state_reg[1] Q -pin write_addr[11]_i_1 I3
netloc state_reg_n_0_[1] 1 1 14 250 770 NJ 770 780 820 NJ 820 1440J 800 NJ 800 NJ 800 NJ 800 NJ 800 2920 610 3120 860 NJ 860 3440 1300 N
load net write_addr0[10] -attr @rip(#000000) O[1] -pin write_addr[10]_i_1 I1 -pin write_addr_reg[11]_i_3 O[1]
load net write_addr0[11] -attr @rip(#000000) O[2] -pin write_addr[11]_i_2 I1 -pin write_addr_reg[11]_i_3 O[2]
load net write_addr0[1] -attr @rip(#000000) O[0] -pin write_addr[1]_i_1 I1 -pin write_addr_reg[4]_i_2 O[0]
load net write_addr0[2] -attr @rip(#000000) O[1] -pin write_addr[2]_i_1 I1 -pin write_addr_reg[4]_i_2 O[1]
load net write_addr0[3] -attr @rip(#000000) O[2] -pin write_addr[3]_i_1 I1 -pin write_addr_reg[4]_i_2 O[2]
load net write_addr0[4] -attr @rip(#000000) O[3] -pin write_addr[4]_i_1 I1 -pin write_addr_reg[4]_i_2 O[3]
load net write_addr0[5] -attr @rip(#000000) O[0] -pin write_addr[5]_i_1 I1 -pin write_addr_reg[8]_i_2 O[0]
load net write_addr0[6] -attr @rip(#000000) O[1] -pin write_addr[6]_i_1 I1 -pin write_addr_reg[8]_i_2 O[1]
load net write_addr0[7] -attr @rip(#000000) O[2] -pin write_addr[7]_i_1 I1 -pin write_addr_reg[8]_i_2 O[2]
load net write_addr0[8] -attr @rip(#000000) O[3] -pin write_addr[8]_i_1 I1 -pin write_addr_reg[8]_i_2 O[3]
load net write_addr0[9] -attr @rip(#000000) O[0] -pin write_addr[9]_i_1 I1 -pin write_addr_reg[11]_i_3 O[0]
load net write_addr[10]_i_1_n_0 -pin write_addr[10]_i_1 O -pin write_addr_reg[10] D
netloc write_addr[10]_i_1_n_0 1 9 1 N 520
load net write_addr[11]_i_1_n_0 -pin write_addr[11]_i_1 O -pin write_addr_reg[0] CE -pin write_addr_reg[10] CE -pin write_addr_reg[11] CE -pin write_addr_reg[1] CE -pin write_addr_reg[2] CE -pin write_addr_reg[3] CE -pin write_addr_reg[4] CE -pin write_addr_reg[5] CE -pin write_addr_reg[6] CE -pin write_addr_reg[7] CE -pin write_addr_reg[8] CE -pin write_addr_reg[9] CE
netloc write_addr[11]_i_1_n_0 1 4 6 1140 900 1380 1020 1760J 880 2020J 1020 NJ 1020 2600
load net write_addr[11]_i_2_n_0 -pin write_addr[11]_i_2 O -pin write_addr_reg[11] D
netloc write_addr[11]_i_2_n_0 1 9 1 N 670
load net write_addr[1]_i_1_n_0 -pin write_addr[1]_i_1 O -pin write_addr_reg[1] D
netloc write_addr[1]_i_1_n_0 1 4 1 1080 290n
load net write_addr[2]_i_1_n_0 -pin write_addr[2]_i_1 O -pin write_addr_reg[2] D
netloc write_addr[2]_i_1_n_0 1 4 1 1120 380n
load net write_addr[3]_i_1_n_0 -pin write_addr[3]_i_1 O -pin write_addr_reg[3] D
netloc write_addr[3]_i_1_n_0 1 4 1 1020 500n
load net write_addr[4]_i_1_n_0 -pin write_addr[4]_i_1 O -pin write_addr_reg[4] D
netloc write_addr[4]_i_1_n_0 1 4 1 1000 590n
load net write_addr[5]_i_1_n_0 -pin write_addr[5]_i_1 O -pin write_addr_reg[5] D
netloc write_addr[5]_i_1_n_0 1 5 1 N 1150
load net write_addr[6]_i_1_n_0 -pin write_addr[6]_i_1 O -pin write_addr_reg[6] D
netloc write_addr[6]_i_1_n_0 1 5 1 N 1300
load net write_addr[7]_i_1_n_0 -pin write_addr[7]_i_1 O -pin write_addr_reg[7] D
netloc write_addr[7]_i_1_n_0 1 5 1 N 1450
load net write_addr[8]_i_1_n_0 -pin write_addr[8]_i_1 O -pin write_addr_reg[8] D
netloc write_addr[8]_i_1_n_0 1 5 1 1360 1540n
load net write_addr[9]_i_1_n_0 -pin write_addr[9]_i_1 O -pin write_addr_reg[9] D
netloc write_addr[9]_i_1_n_0 1 9 1 2580 370n
load net write_addr_reg[11]_i_3_n_2 -attr @rip(#000000) CO[1] -pin write_addr_reg[11]_i_3 CO[1]
load net write_addr_reg[11]_i_3_n_3 -attr @rip(#000000) CO[0] -pin write_addr_reg[11]_i_3 CO[0]
load net write_addr_reg[4]_i_2_n_0 -attr @rip(#000000) CO[3] -pin write_addr_reg[4]_i_2 CO[3] -pin write_addr_reg[8]_i_2 CI
load net write_addr_reg[4]_i_2_n_1 -attr @rip(#000000) CO[2] -pin write_addr_reg[4]_i_2 CO[2]
load net write_addr_reg[4]_i_2_n_2 -attr @rip(#000000) CO[1] -pin write_addr_reg[4]_i_2 CO[1]
load net write_addr_reg[4]_i_2_n_3 -attr @rip(#000000) CO[0] -pin write_addr_reg[4]_i_2 CO[0]
load net write_addr_reg[8]_i_2_n_0 -attr @rip(#000000) CO[3] -pin write_addr_reg[11]_i_3 CI -pin write_addr_reg[8]_i_2 CO[3]
load net write_addr_reg[8]_i_2_n_1 -attr @rip(#000000) CO[2] -pin write_addr_reg[8]_i_2 CO[2]
load net write_addr_reg[8]_i_2_n_2 -attr @rip(#000000) CO[1] -pin write_addr_reg[8]_i_2 CO[1]
load net write_addr_reg[8]_i_2_n_3 -attr @rip(#000000) CO[0] -pin write_addr_reg[8]_i_2 CO[0]
load netBundle @data_in 8 data_in[7] data_in[6] data_in[5] data_in[4] data_in[3] data_in[2] data_in[1] data_in[0] -autobundled
netbloc @data_in 1 0 14 NJ 2620 NJ 2620 NJ 2620 NJ 2620 NJ 2620 NJ 2620 NJ 2620 NJ 2620 NJ 2620 NJ 2620 NJ 2620 NJ 2620 NJ 2620 3600
load netBundle @read_addr 11 read_addr[10] read_addr[9] read_addr[8] read_addr[7] read_addr[6] read_addr[5] read_addr[4] read_addr[3] read_addr[2] read_addr[1] read_addr[0] -autobundled
netbloc @read_addr 1 0 14 NJ 3180 NJ 3180 NJ 3180 NJ 3180 NJ 3180 NJ 3180 NJ 3180 NJ 3180 NJ 3180 NJ 3180 NJ 3180 NJ 3180 NJ 3180 3440
load netBundle @frame_size 12 frame_size[11] frame_size[10] frame_size[9] frame_size[8] frame_size[7] frame_size[6] frame_size[5] frame_size[4] frame_size[3] frame_size[2] frame_size[1] frame_size[0] -autobundled
netbloc @frame_size 1 16 1 4740 300n
load netBundle @read_data 8 read_data[7] read_data[6] read_data[5] read_data[4] read_data[3] read_data[2] read_data[1] read_data[0] -autobundled
netbloc @read_data 1 16 1 4740 1880n
load netBundle @read_data_OBUF 8 read_data_OBUF[7] read_data_OBUF[6] read_data_OBUF[5] read_data_OBUF[4] read_data_OBUF[3] read_data_OBUF[2] read_data_OBUF[1] read_data_OBUF[0] -autobundled
netbloc @read_data_OBUF 1 15 1 4450 1880n
load netBundle @write_addr_reg 2 write_addr_reg[11]_i_3_n_2 write_addr_reg[11]_i_3_n_3 -autobundled
netbloc @write_addr_reg 1 8 1 N 900
load netBundle @write_addr0 3 write_addr0[11] write_addr0[10] write_addr0[9] -autobundled
netbloc @write_addr0 1 8 1 2340 450n
load netBundle @write_addr_reg_1 4 write_addr_reg[4]_i_2_n_0 write_addr_reg[4]_i_2_n_1 write_addr_reg[4]_i_2_n_2 write_addr_reg[4]_i_2_n_3 -autobundled
netbloc @write_addr_reg_1 1 6 1 1740 880n
load netBundle @write_addr0_1 4 write_addr0[4] write_addr0[3] write_addr0[2] write_addr0[1] -autobundled
netbloc @write_addr0_1 1 3 4 820 840 NJ 840 1440J 1000 1700
load netBundle @write_addr_reg_2 4 write_addr_reg[8]_i_2_n_0 write_addr_reg[8]_i_2_n_1 write_addr_reg[8]_i_2_n_2 write_addr_reg[8]_i_2_n_3 -autobundled
netbloc @write_addr_reg_2 1 7 1 2040 880n
load netBundle @write_addr0_2 4 write_addr0[8] write_addr0[7] write_addr0[6] write_addr0[5] -autobundled
netbloc @write_addr0_2 1 4 4 1180 1060 NJ 1060 NJ 1060 2000
load netBundle @mem_waddr 11 mem_waddr[10] mem_waddr[9] mem_waddr[8] mem_waddr[7] mem_waddr[6] mem_waddr[5] mem_waddr[4] mem_waddr[3] mem_waddr[2] mem_waddr[1] mem_waddr[0] -autobundled
netbloc @mem_waddr 1 14 1 3860 1090n
load netBundle @read_addr_IBUF 11 read_addr_IBUF[10] read_addr_IBUF[9] read_addr_IBUF[8] read_addr_IBUF[7] read_addr_IBUF[6] read_addr_IBUF[5] read_addr_IBUF[4] read_addr_IBUF[3] read_addr_IBUF[2] read_addr_IBUF[1] read_addr_IBUF[0] -autobundled
netbloc @read_addr_IBUF 1 14 1 3980 2230n
load netBundle @data_in_IBUF 8 data_in_IBUF[7] data_in_IBUF[6] data_in_IBUF[5] data_in_IBUF[4] data_in_IBUF[3] data_in_IBUF[2] data_in_IBUF[1] data_in_IBUF[0] -autobundled
netbloc @data_in_IBUF 1 14 1 4000 2290n
load netBundle @frame_size_OBUF 3 frame_size_OBUF[11] frame_size_OBUF[10] frame_size_OBUF[9] -autobundled
netbloc @frame_size_OBUF 1 1 15 270 750 NJ 750 760 800 NJ 800 1400J 780 NJ 780 2060 1000 NJ 1000 NJ 1000 2840 840 NJ 840 NJ 840 3540 1010 NJ 1010 4490
load netBundle @frame_size_OBUF_1 4 frame_size_OBUF[4] frame_size_OBUF[3] frame_size_OBUF[2] frame_size_OBUF[1] -autobundled
netbloc @frame_size_OBUF_1 1 5 11 1360 1040 NJ 1040 NJ 1040 NJ 1040 NJ 1040 NJ 1040 NJ 1040 NJ 1040 3480 760 NJ 760 4450
load netBundle @frame_size_OBUF_2 4 frame_size_OBUF[8] frame_size_OBUF[7] frame_size_OBUF[6] frame_size_OBUF[5] -autobundled
netbloc @frame_size_OBUF_2 1 6 10 1780 1080 NJ 1080 NJ 1080 NJ 1080 NJ 1080 NJ 1080 NJ 1080 3500 990 NJ 990 4470
levelinfo -pg 1 0 40 310 580 880 1240 1540 1840 2130 2400 2660 2980 3180 3340 3660 4190 4530 4760
pagesize -pg 1 -db -bbox -sgen -160 0 4920 3920
show
fullfit
#
# initialize ictrl to current module ethernet_frame_buffer work:ethernet_frame_buffer:NOFILE
ictrl init topinfo |
